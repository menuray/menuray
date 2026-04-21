import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { chatCompletion } from "./openai_client.ts";

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

Deno.test("chatCompletion — throws when OPENAI_API_KEY missing", async () => {
  const prev = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  try {
    await assertRejects(
      () => chatCompletion({ model: "gpt-4o-mini", messages: [] }),
      Error,
      "OPENAI_API_KEY not set",
    );
  } finally {
    if (prev) Deno.env.set("OPENAI_API_KEY", prev);
  }
});

Deno.test("chatCompletion — success returns parsed JSON", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  await withMockFetch(
    () =>
      new Response(JSON.stringify({ choices: [{ message: { content: "{}" } }] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    async () => {
      const r = await chatCompletion({ model: "gpt-4o-mini", messages: [] }) as {
        choices: { message: { content: string } }[];
      };
      assertEquals(r.choices[0].message.content, "{}");
    },
  );
});

Deno.test("chatCompletion — 5xx retries once, then succeeds", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let calls = 0;
  await withMockFetch(
    () => {
      calls++;
      if (calls === 1) return new Response("upstream err", { status: 502 });
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    },
    async () => {
      const r = await chatCompletion({ model: "gpt-4o-mini", messages: [] }) as {
        ok: boolean;
      };
      assertEquals(r.ok, true);
      assertEquals(calls, 2);
    },
  );
});

Deno.test("chatCompletion — 429 throws immediately (no retry)", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let calls = 0;
  await withMockFetch(
    () => {
      calls++;
      return new Response("rate limited", { status: 429 });
    },
    async () => {
      await assertRejects(
        () => chatCompletion({ model: "gpt-4o-mini", messages: [] }),
        Error,
        "OpenAI 429",
      );
      assertEquals(calls, 1);
    },
  );
});

Deno.test("chatCompletion — 4xx throws immediately (no retry)", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let calls = 0;
  await withMockFetch(
    () => {
      calls++;
      return new Response("bad req", { status: 400 });
    },
    async () => {
      await assertRejects(
        () => chatCompletion({ model: "gpt-4o-mini", messages: [] }),
        Error,
        "OpenAI 400",
      );
      assertEquals(calls, 1);
    },
  );
});

Deno.test("chatCompletion — two 5xx throws", async () => {
  Deno.env.set("OPENAI_API_KEY", "sk-test");
  let calls = 0;
  await withMockFetch(
    () => {
      calls++;
      return new Response("upstream err", { status: 500 });
    },
    async () => {
      await assertRejects(
        () => chatCompletion({ model: "gpt-4o-mini", messages: [] }),
        Error,
        "OpenAI 5xx",
      );
      assertEquals(calls, 2);
    },
  );
});
