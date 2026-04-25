import { assertEquals } from "std/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("MENURAY_LLM_PROVIDER", "mock");

const { handleRequest } = await import("./index.ts");

type FetchResponder = (
  url: string,
  init?: RequestInit,
) => Response | Promise<Response>;

function withStubbedFetch(responder: FetchResponder) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : (input as URL).toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/ai-optimize", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${bearer}`,
    },
    body: JSON.stringify(body),
  });
}

const SAMPLE_MENU_ID = "11111111-1111-1111-1111-111111111111";
const SAMPLE_STORE_ID = "22222222-2222-2222-2222-222222222222";

type StubOpts = {
  tier?: string;
  monthlyCount?: number;
  recordCalls?: { dishUpdates: number; aiRunsInserts: number };
};

function happyStub(opts: StubOpts = {}): FetchResponder {
  const counts = opts.recordCalls ?? { dishUpdates: 0, aiRunsInserts: 0 };
  return (url, init) => {
    const method = init?.method ?? "GET";

    if (url.includes("/rest/v1/menus") && method === "GET") {
      return new Response(JSON.stringify([{
        id: SAMPLE_MENU_ID,
        store_id: SAMPLE_STORE_ID,
        source_locale: "zh-CN",
      }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && method === "GET") {
      return new Response(JSON.stringify([{ tier: opts.tier ?? "pro" }]), {
        status: 200,
      });
    }
    if (url.includes("/rest/v1/ai_runs") && method === "HEAD") {
      return new Response(null, {
        status: 200,
        headers: { "Content-Range": `0-0/${opts.monthlyCount ?? 0}` },
      });
    }
    if (url.includes("/rest/v1/ai_runs") && method === "POST") {
      counts.aiRunsInserts++;
      return new Response(null, { status: 201 });
    }
    if (url.includes("/rest/v1/dishes") && method === "GET") {
      return new Response(JSON.stringify([
        { id: "d1", source_name: "口水鸡", source_description: "麻辣口水鸡" },
        { id: "d2", source_name: "蛋炒饭", source_description: null },
      ]), { status: 200 });
    }
    if (url.includes("/rest/v1/dishes") && method === "PATCH") {
      counts.dishUpdates++;
      return new Response(null, { status: 204 });
    }
    return new Response("[]", { status: 200 });
  };
}

Deno.test("401 when Authorization header missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/ai-optimize", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ menu_id: SAMPLE_MENU_ID }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally {
    restore();
  }
});

Deno.test("400 when menu_id missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({}));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "menu_id_required");
  } finally {
    restore();
  }
});

Deno.test("429 when monthly batch quota exceeded", async () => {
  const restore = withStubbedFetch(happyStub({
    tier: "free",
    monthlyCount: 1, // Free cap is 1; one call already made.
  }));
  try {
    const res = await handleRequest(makeReq({ menu_id: SAMPLE_MENU_ID }));
    assertEquals(res.status, 429);
    const body = await res.json();
    assertEquals(body.error, "ai_quota_exceeded");
    assertEquals(body.tier, "free");
    assertEquals(body.cap, 1);
  } finally {
    restore();
  }
});

Deno.test("200 happy path: rewrites dishes and logs ai_runs", async () => {
  const counts = { dishUpdates: 0, aiRunsInserts: 0 };
  const restore = withStubbedFetch(happyStub({
    tier: "pro",
    monthlyCount: 0,
    recordCalls: counts,
  }));
  try {
    const res = await handleRequest(makeReq({ menu_id: SAMPLE_MENU_ID }));
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.rewrittenDishCount, 2);
    // One PATCH per dish (mock returns 2).
    assertEquals(counts.dishUpdates, 2);
    // One ai_runs insert (success row).
    assertEquals(counts.aiRunsInserts, 1);
  } finally {
    restore();
  }
});
