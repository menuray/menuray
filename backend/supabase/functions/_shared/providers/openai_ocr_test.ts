import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { OpenAIOcrProvider } from "./openai_ocr.ts";

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

function fakeSupabase(bytesByPath: Record<string, Uint8Array>) {
  return {
    storage: {
      from(_bucket: string) {
        return {
          async download(path: string) {
            const bytes = bytesByPath[path];
            if (!bytes) return { data: null, error: new Error(`not found: ${path}`) };
            const blob = new Blob([bytes.buffer as ArrayBuffer]);
            return { data: blob, error: null };
          },
        };
      },
    },
  };
}

Deno.test("OpenAIOcrProvider — happy path returns parsed OcrResult", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]); // JPEG magic
  const canned = {
    fullText: "Some Menu",
    blocks: [{ text: "Some Menu", bbox: [0, 0, 1, 0.1] }],
    sourceLocale: "en",
  };
  let capturedBody: unknown = null;
  await withMockFetch(
    async (req) => {
      capturedBody = await req.json();
      return new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify(canned) } }] }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    },
    async () => {
      const supa = fakeSupabase({ "store1/run1/0.jpg": bytes });
      const provider = new OpenAIOcrProvider(supa as never);
      const result = await provider.extract(["store1/run1/0.jpg"]);

      assertEquals(result.fullText, "Some Menu");
      assertEquals(result.sourceLocale, "en");
      assertEquals(result.blocks.length, 1);
      assertEquals(result.blocks[0].text, "Some Menu");
      assertEquals(result.blocks[0].bbox, [0, 0, 1, 0.1]);

      // Body should contain a base64 data URL with the JPEG magic bytes.
      const body = capturedBody as { messages: { content: unknown }[] };
      const userContent = body.messages[1].content as Array<{ type: string; image_url?: { url: string } }>;
      const imgPart = userContent.find((p) => p.type === "image_url");
      assert(imgPart?.image_url?.url.startsWith("data:image/jpeg;base64,"));
    },
  );
});

Deno.test("OpenAIOcrProvider — null sourceLocale coerced to undefined", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  const canned = { fullText: "X", blocks: [], sourceLocale: null };
  await withMockFetch(
    () =>
      new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify(canned) } }] }),
        { status: 200 },
      ),
    async () => {
      const supa = fakeSupabase({ "s/r/0.jpg": new Uint8Array([1, 2]) });
      const provider = new OpenAIOcrProvider(supa as never);
      const result = await provider.extract(["s/r/0.jpg"]);
      assertEquals(result.sourceLocale, undefined);
    },
  );
});

Deno.test("OpenAIOcrProvider — multiple photos become multiple image parts", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let capturedBody: unknown = null;
  await withMockFetch(
    async (req) => {
      capturedBody = await req.json();
      return new Response(
        JSON.stringify({
          choices: [{
            message: {
              content: JSON.stringify({ fullText: "", blocks: [], sourceLocale: null }),
            },
          }],
        }),
        { status: 200 },
      );
    },
    async () => {
      const supa = fakeSupabase({
        "s/r/0.jpg": new Uint8Array([1]),
        "s/r/1.jpg": new Uint8Array([2]),
      });
      const provider = new OpenAIOcrProvider(supa as never);
      await provider.extract(["s/r/0.jpg", "s/r/1.jpg"]);

      const body = capturedBody as { messages: { content: unknown }[] };
      const parts = body.messages[1].content as Array<{ type: string }>;
      const imgParts = parts.filter((p) => p.type === "image_url");
      assertEquals(imgParts.length, 2);
    },
  );
});

Deno.test("OpenAIOcrProvider — onRawResponse callback invoked", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  const canned = { fullText: "X", blocks: [], sourceLocale: null };
  const rawEnvelope = { choices: [{ message: { content: JSON.stringify(canned) } }] };
  await withMockFetch(
    () => new Response(JSON.stringify(rawEnvelope), { status: 200 }),
    async () => {
      const supa = fakeSupabase({ "s/r/0.jpg": new Uint8Array([1]) });
      const provider = new OpenAIOcrProvider(supa as never);
      let capturedRaw: unknown = null;
      provider.onRawResponse = (raw: unknown) => {
        capturedRaw = raw;
      };
      await provider.extract(["s/r/0.jpg"]);
      assertEquals(capturedRaw, rawEnvelope);
    },
  );
});
