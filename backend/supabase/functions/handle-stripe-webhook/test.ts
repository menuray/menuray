import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("STRIPE_WEBHOOK_SECRET", "whsec_dummy");
Deno.env.set("STRIPE_PRICE_PRO_USD_MONTHLY", "price_pro_usd_monthly");

const { handleRequest } = await import("./index.ts");
const { stripeClient } = await import("../_shared/stripe.ts");

// Force the lazy stripe singleton + override webhooks.
const stripe = stripeClient();
type ConstructedEvent = {
  id: string; type: string; data: { object: unknown };
};
let stubbedEvent: ConstructedEvent | null = null;
let signatureValid = true;
// deno-lint-ignore no-explicit-any
(stripe.webhooks as any).constructEventAsync = async (
  _body: string, _sig: string, _secret: string,
) => {
  if (!signatureValid) throw new Error("bad sig");
  return stubbedEvent;
};
// deno-lint-ignore no-explicit-any
(stripe.subscriptions as any).retrieve = async (_id: string) => ({
  id: _id, current_period_end: 1900000000,
});

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
function makeReq(body = "{}"): Request {
  return new Request("http://stub/handle-stripe-webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json", "stripe-signature": "t=0,v1=stub" },
    body,
  });
}

Deno.test("400 when signature header missing", async () => {
  const req = new Request("http://stub/handle-stripe-webhook", {
    method: "POST", body: "{}",
  });
  const res = await handleRequest(req);
  assertEquals(res.status, 400);
});

Deno.test("400 on bad signature", async () => {
  signatureValid = false;
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "signature_failed");
  } finally { restore(); signatureValid = true; }
});

Deno.test("checkout.session.completed flips tier + writes stores", async () => {
  stubbedEvent = {
    id: "evt_1", type: "checkout.session.completed",
    data: { object: {
      metadata: { owner_user_id: "u-1", tier: "pro", currency: "USD", period: "monthly" },
      customer: "cus_1", subscription: "sub_1",
    } },
  };
  const writes: Array<{ url: string; method?: string; body?: string }> = [];
  const restore = withStubbedFetch((url, init) => {
    writes.push({ url, method: init?.method, body: init?.body as string | undefined });
    if (url.includes("stripe_events_seen")) {
      return new Response(JSON.stringify([{ event_id: "evt_1" }]), { status: 201 });
    }
    if (url.includes("subscriptions") && init?.method === "PATCH") {
      return new Response("[]", { status: 200 });
    }
    if (url.includes("store_members") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ store_id: "s-1" }, { store_id: "s-2" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && init?.method === "PATCH") {
      return new Response("[]", { status: 200 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).ok, true);
    // We expect at least one PATCH to subscriptions and one PATCH to stores.
    const subPatches = writes.filter((w) => w.url.includes("subscriptions") && w.method === "PATCH");
    const storePatches = writes.filter((w) => w.url.includes("/rest/v1/stores") && w.method === "PATCH");
    assertEquals(subPatches.length >= 1, true);
    assertEquals(storePatches.length >= 1, true);
  } finally { restore(); }
});

Deno.test("replay is no-op", async () => {
  stubbedEvent = {
    id: "evt_replay", type: "checkout.session.completed",
    data: { object: { metadata: {}, customer: "c", subscription: "s" } },
  };
  const restore = withStubbedFetch((url) => {
    if (url.includes("stripe_events_seen")) {
      return new Response(JSON.stringify({ code: "23505", message: "duplicate" }), { status: 409 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).replay, true);
  } finally { restore(); }
});

Deno.test("unknown event type returns 200 ack", async () => {
  stubbedEvent = { id: "evt_unknown", type: "ping.pong", data: { object: {} } };
  const restore = withStubbedFetch(() => new Response("[]", { status: 201 }));
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
  } finally { restore(); }
});
