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
  return new Request("http://stub/translate-menu", {
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

// Minimal happy-path stub used by both 200 and 402/429 tests with overrides.
type StubOpts = {
  tier?: string;
  monthlyCount?: number;
  availableLocales?: string[];
  recordCalls?: { translationsUpserts: number; aiRunsInserts: number };
};

function happyStub(opts: StubOpts = {}): FetchResponder {
  const counts = opts.recordCalls ?? { translationsUpserts: 0, aiRunsInserts: 0 };
  return (url, init) => {
    const method = init?.method ?? "GET";

    // anon RLS check on menus
    if (url.includes("/rest/v1/menus") && method === "GET") {
      return new Response(JSON.stringify([{
        id: SAMPLE_MENU_ID,
        store_id: SAMPLE_STORE_ID,
        source_locale: "zh-CN",
        available_locales: opts.availableLocales ?? ["zh-CN"],
      }]), { status: 200 });
    }
    // tier read
    if (url.includes("/rest/v1/stores") && method === "GET") {
      return new Response(JSON.stringify([{ tier: opts.tier ?? "pro" }]), {
        status: 200,
      });
    }
    // ai_runs count
    if (url.includes("/rest/v1/ai_runs") && method === "HEAD") {
      return new Response(null, {
        status: 200,
        headers: { "Content-Range": `0-0/${opts.monthlyCount ?? 0}` },
      });
    }
    // ai_runs insert
    if (url.includes("/rest/v1/ai_runs") && method === "POST") {
      counts.aiRunsInserts++;
      return new Response(null, { status: 201 });
    }
    // categories list
    if (url.includes("/rest/v1/categories") && method === "GET") {
      return new Response(JSON.stringify([
        { id: "c1", source_name: "凉菜" },
      ]), { status: 200 });
    }
    // dishes list
    if (url.includes("/rest/v1/dishes") && method === "GET") {
      return new Response(JSON.stringify([
        { id: "d1", category_id: "c1", source_name: "口水鸡", source_description: "麻辣口水鸡" },
      ]), { status: 200 });
    }
    // upserts
    if (url.includes("/rest/v1/category_translations") && method === "POST") {
      counts.translationsUpserts++;
      return new Response(null, { status: 201 });
    }
    if (url.includes("/rest/v1/dish_translations") && method === "POST") {
      counts.translationsUpserts++;
      return new Response(null, { status: 201 });
    }
    // menus update (available_locales bump)
    if (url.includes("/rest/v1/menus") && method === "PATCH") {
      return new Response(null, { status: 204 });
    }
    return new Response("[]", { status: 200 });
  };
}

Deno.test("401 when Authorization header missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/translate-menu", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ menu_id: SAMPLE_MENU_ID, target_locale: "ja" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally {
    restore();
  }
});

Deno.test("400 when menu_id or target_locale missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ menu_id: SAMPLE_MENU_ID }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "menu_id_and_target_locale_required");
  } finally {
    restore();
  }
});

Deno.test("402 when locale cap would be exceeded", async () => {
  // Free tier cap = 2; menu already has [zh-CN, en]; adding ja would push to 3.
  const restore = withStubbedFetch(happyStub({
    tier: "free",
    availableLocales: ["zh-CN", "en"],
  }));
  try {
    const res = await handleRequest(
      makeReq({ menu_id: SAMPLE_MENU_ID, target_locale: "ja" }),
    );
    assertEquals(res.status, 402);
    const body = await res.json();
    assertEquals(body.error, "locale_cap_exceeded");
    assertEquals(body.tier, "free");
    assertEquals(body.cap, 2);
  } finally {
    restore();
  }
});

Deno.test("429 when monthly batch quota exceeded", async () => {
  // Pro tier quota = 10; monthlyCount=10 hits the cap.
  const restore = withStubbedFetch(happyStub({
    tier: "pro",
    monthlyCount: 10,
  }));
  try {
    const res = await handleRequest(
      makeReq({ menu_id: SAMPLE_MENU_ID, target_locale: "ja" }),
    );
    assertEquals(res.status, 429);
    const body = await res.json();
    assertEquals(body.error, "ai_quota_exceeded");
    assertEquals(body.tier, "pro");
  } finally {
    restore();
  }
});

Deno.test("200 happy path: upserts translations and logs ai_runs", async () => {
  const counts = { translationsUpserts: 0, aiRunsInserts: 0 };
  const restore = withStubbedFetch(happyStub({
    tier: "pro",
    monthlyCount: 0,
    recordCalls: counts,
  }));
  try {
    const res = await handleRequest(
      makeReq({ menu_id: SAMPLE_MENU_ID, target_locale: "ja" }),
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.translatedDishCount, 1);
    assertEquals(body.translatedCategoryCount, 1);
    assertEquals(body.availableLocales.includes("ja"), true);
    // One categories upsert + one dishes upsert.
    assertEquals(counts.translationsUpserts, 2);
    // One ai_runs insert (success row).
    assertEquals(counts.aiRunsInserts, 1);
  } finally {
    restore();
  }
});
