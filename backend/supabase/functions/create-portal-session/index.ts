import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient } from "../_shared/stripe.ts";

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

  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);

  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("stripe_customer_id")
    .eq("owner_user_id", userResp.user.id).maybeSingle();
  if (!subRow?.stripe_customer_id) return jsonResponse({ error: "no_customer" }, 404);

  const appUrl = Deno.env.get("PUBLIC_APP_URL") ?? "http://localhost:5173";
  const session = await stripeClient().billingPortal.sessions.create({
    customer: subRow.stripe_customer_id,
    return_url: `${appUrl}/upgrade`,
  });
  return jsonResponse({ url: session.url });
}

Deno.serve(handleRequest);
