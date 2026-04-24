import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Set env BEFORE importing index (which inits Stripe lazily but priceIdFor
// reads env on every call so order isn't strict, but be safe).
Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("STRIPE_PRICE_PRO_USD_MONTHLY", "price_pro_usd_monthly");
Deno.env.set("STRIPE_PRICE_PRO_CNY_MONTHLY", "price_pro_cny_monthly");
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

function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/create-checkout-session", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("400 on invalid tier", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ tier: "diamond", currency: "USD", period: "monthly" }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "invalid_tier");
  } finally { restore(); }
});

Deno.test("400 on CNY+annual", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ tier: "pro", currency: "CNY", period: "annual" }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "unsupported_combo");
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-checkout-session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tier: "pro", currency: "USD", period: "monthly" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});

Deno.test("200 happy path returns session URL", async () => {
  const calls: Array<{ url: string; method: string }> = [];
  const restore = withStubbedFetch((url, init) => {
    calls.push({ url, method: init?.method ?? "GET" });
    // 1) Auth user lookup
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "user-1", email: "u@x" }), {
        status: 200, headers: { "Content-Type": "application/json" },
      });
    }
    // 2) PostgREST select on subscriptions (returns existing customer)
    if (url.includes("/rest/v1/subscriptions") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ stripe_customer_id: "cus_existing" }]), {
        status: 200, headers: { "Content-Type": "application/json" },
      });
    }
    // 3) Stripe Checkout sessions create
    if (url.includes("checkout/sessions")) {
      return new Response(JSON.stringify({
        id: "cs_test_1", url: "https://checkout.stripe.com/c/cs_test_1",
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ tier: "pro", currency: "USD", period: "monthly" }));
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.url, "https://checkout.stripe.com/c/cs_test_1");
  } finally { restore(); }
});
