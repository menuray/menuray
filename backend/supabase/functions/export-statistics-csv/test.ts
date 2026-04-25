import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");

const { handleRequest } = await import("./index.ts");

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}
function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/export-statistics-csv", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/export-statistics-csv", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ store_id: "s", from: "a", to: "b" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});

Deno.test("400 missing params", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ store_id: "s" }));
    assertEquals(res.status, 400);
  } finally { restore(); }
});

Deno.test("402 on free tier", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "free" }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      store_id: "s", from: "2026-04-01T00:00:00Z", to: "2026-04-25T00:00:00Z",
    }));
    assertEquals(res.status, 402);
    assertEquals((await res.json()).error, "csv_requires_growth");
  } finally { restore(); }
});

Deno.test("402 on pro tier (Growth-only)", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "pro" }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      store_id: "s", from: "2026-04-01T00:00:00Z", to: "2026-04-25T00:00:00Z",
    }));
    assertEquals(res.status, 402);
  } finally { restore(); }
});

Deno.test("200 growth happy path returns text/csv", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "growth" }]), { status: 200 });
    }
    if (url.includes("/rpc/get_visits_overview")) {
      return new Response(JSON.stringify({ total_views: 42, unique_sessions: 17 }), { status: 200 });
    }
    if (url.includes("/rpc/get_visits_by_day")) {
      return new Response(JSON.stringify([{ day: "2026-04-01", count: 10 }, { day: "2026-04-02", count: 32 }]), { status: 200 });
    }
    if (url.includes("/rpc/get_top_dishes")) {
      return new Response(JSON.stringify([{ dish_id: "d1", dish_name: "Kung Pao", count: 20 }]), { status: 200 });
    }
    if (url.includes("/rpc/get_traffic_by_locale")) {
      return new Response(JSON.stringify([{ locale: "zh-CN", count: 30 }, { locale: "en", count: 12 }]), { status: 200 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      store_id: "s", from: "2026-04-01T00:00:00Z", to: "2026-04-25T00:00:00Z",
    }));
    assertEquals(res.status, 200);
    const contentType = res.headers.get("content-type");
    assertStringIncludes(contentType ?? "", "text/csv");
    const body = await res.text();
    assertStringIncludes(body, "# Visits overview");
    assertStringIncludes(body, "42,17");
    assertStringIncludes(body, "# Top dishes");
    assertStringIncludes(body, "Kung Pao");
  } finally { restore(); }
});
