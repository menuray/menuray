import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("PUBLIC_APP_URL", "http://app");

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

function makeReq(): Request {
  return new Request("http://stub/create-portal-session", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer user-jwt" },
    body: "{}",
  });
}

Deno.test("404 when user has no customer_id", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ stripe_customer_id: null }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 404);
    assertEquals((await res.json()).error, "no_customer");
  } finally { restore(); }
});

Deno.test("200 happy path returns portal URL", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ stripe_customer_id: "cus_1" }]), { status: 200 });
    }
    if (url.includes("billing_portal/sessions")) {
      return new Response(JSON.stringify({ url: "https://billing.stripe.com/p/session_1" }), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).url, "https://billing.stripe.com/p/session_1");
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-portal-session", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: "{}",
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});
