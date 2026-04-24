import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient, priceIdFor } from "../_shared/stripe.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const jwt = auth.slice("Bearer ".length);

  let body: { tier?: string; currency?: string; period?: string };
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json_body" }, 400); }
  const tier = body.tier;
  const currency = body.currency;
  const period = body.period;
  if (tier !== "pro" && tier !== "growth") return jsonResponse({ error: "invalid_tier" }, 400);
  if (currency !== "USD" && currency !== "CNY") return jsonResponse({ error: "invalid_currency" }, 400);
  if (period !== "monthly" && period !== "annual") return jsonResponse({ error: "invalid_period" }, 400);

  const priceId = priceIdFor(tier, currency, period);
  if (!priceId) return jsonResponse({ error: "unsupported_combo" }, 400);

  // Resolve user.id from the JWT.
  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const userId = userResp.user.id;

  // Fetch existing customer_id (or null).
  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("stripe_customer_id")
    .eq("owner_user_id", userId).maybeSingle();
  let customerId = subRow?.stripe_customer_id ?? null;

  const stripe = stripeClient();
  if (!customerId) {
    const customer = await stripe.customers.create({ metadata: { owner_user_id: userId } });
    customerId = customer.id;
    await adminDb.from("subscriptions")
      .update({ stripe_customer_id: customerId })
      .eq("owner_user_id", userId);
  }

  const appUrl = Deno.env.get("PUBLIC_APP_URL") ?? "http://localhost:5173";
  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer: customerId,
    line_items: [{ price: priceId, quantity: 1 }],
    payment_method_types: currency === "CNY"
      ? ["card", "wechat_pay", "alipay"]
      : ["card"],
    success_url: `${appUrl}/upgrade?status=success`,
    cancel_url: `${appUrl}/upgrade?status=cancel`,
    metadata: { owner_user_id: userId, tier, currency, period },
  });

  return jsonResponse({ url: session.url });
}

Deno.serve(handleRequest);
