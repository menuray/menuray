import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { OpenAIStructureProvider } from "./openai_structure.ts";
import type { OcrResult } from "./types.ts";

type MockFetchHandler = (input: Request) => Promise<Response> | Response;

function withMockFetch(handler: MockFetchHandler, fn: () => Promise<void>) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input: RequestInfo | URL, init?: RequestInit) => {
    const req = input instanceof Request ? input : new Request(input, init);
    return Promise.resolve(handler(req));
  }) as typeof globalThis.fetch;
  return fn().finally(() => {
    globalThis.fetch = original;
  });
}

const SAMPLE_OCR: OcrResult = {
  fullText: "Lunch\nMa Po Tofu 38\nKung Pao 48",
  blocks: [],
  sourceLocale: "en",
};

const SAMPLE_DRAFT = {
  name: "Lunch",
  sourceLocale: "en",
  currency: "USD",
  categories: [{
    sourceName: "Mains",
    position: 0,
    dishes: [
      {
        sourceName: "Ma Po Tofu",
        sourceDescription: null,
        price: 38,
        position: 0,
        spiceLevel: "medium",
        confidence: "high",
        isSignature: false,
        isRecommended: false,
        isVegetarian: false,
        allergens: [],
      },
      {
        sourceName: "Kung Pao",
        sourceDescription: "Peanuts and chili",
        price: 48,
        position: 1,
        spiceLevel: "medium",
        confidence: "high",
        isSignature: true,
        isRecommended: false,
        isVegetarian: false,
        allergens: ["peanut"],
      },
    ],
  }],
};

Deno.test("OpenAIStructureProvider — happy path returns typed MenuDraft", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  await withMockFetch(
    () =>
      new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify(SAMPLE_DRAFT) } }] }),
        { status: 200 },
      ),
    async () => {
      const provider = new OpenAIStructureProvider();
      const result = await provider.structure(SAMPLE_OCR, { sourceLocale: "en", currency: "USD" });
      assertEquals(result.name, "Lunch");
      assertEquals(result.currency, "USD");
      assertEquals(result.categories.length, 1);
      assertEquals(result.categories[0].dishes.length, 2);
      assertEquals(result.categories[0].dishes[1].allergens, ["peanut"]);
    },
  );
});

Deno.test("OpenAIStructureProvider — null sourceDescription is elided", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  await withMockFetch(
    () =>
      new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify(SAMPLE_DRAFT) } }] }),
        { status: 200 },
      ),
    async () => {
      const provider = new OpenAIStructureProvider();
      const result = await provider.structure(SAMPLE_OCR, {});
      // First dish had sourceDescription:null in SAMPLE_DRAFT — should be elided.
      assertEquals(
        "sourceDescription" in result.categories[0].dishes[0],
        false,
      );
      // Second dish had a real description — preserved.
      assertEquals(
        result.categories[0].dishes[1].sourceDescription,
        "Peanuts and chili",
      );
    },
  );
});

Deno.test("OpenAIStructureProvider — sends OCR text + hints in user message", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let capturedBody: unknown = null;
  await withMockFetch(
    async (req) => {
      capturedBody = await req.json();
      return new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify(SAMPLE_DRAFT) } }] }),
        { status: 200 },
      );
    },
    async () => {
      const provider = new OpenAIStructureProvider();
      await provider.structure(
        { fullText: "Menu", blocks: [], sourceLocale: "zh" },
        { sourceLocale: "zh", currency: "CNY" },
      );
      const body = capturedBody as { messages: { content: string }[] };
      const userMsg = body.messages[1].content;
      const hasText = userMsg.includes("Menu");
      const hasLocale = userMsg.includes("zh");
      const hasCurrency = userMsg.includes("CNY");
      assertEquals(hasText && hasLocale && hasCurrency, true);
    },
  );
});

Deno.test("OpenAIStructureProvider — onRawResponse hook invoked", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  const envelope = { choices: [{ message: { content: JSON.stringify(SAMPLE_DRAFT) } }] };
  await withMockFetch(
    () => new Response(JSON.stringify(envelope), { status: 200 }),
    async () => {
      const provider = new OpenAIStructureProvider();
      let capturedRaw: unknown = null;
      provider.onRawResponse = (raw: unknown) => {
        capturedRaw = raw;
      };
      await provider.structure(SAMPLE_OCR, {});
      assertEquals(capturedRaw, envelope);
    },
  );
});
