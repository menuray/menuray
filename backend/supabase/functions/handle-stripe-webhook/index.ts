import { createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient, tierFromPriceId } from "../_shared/stripe.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "stripe-signature, content-type",
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

  const sig = req.headers.get("stripe-signature");
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!sig || !secret) return jsonResponse({ error: "missing_signature" }, 400);

  const rawBody = await req.text();
  const stripe = stripeClient();
  let event;
  try {
    // Use the async variant — Deno's WebCrypto-compatible signature verifier.
    event = await stripe.webhooks.constructEventAsync(rawBody, sig, secret);
  } catch (e) {
    console.error("webhook signature failed", (e as Error).message);
    return jsonResponse({ error: "signature_failed" }, 400);
  }

  const adminDb = createServiceRoleClient();

  // Idempotency: try to record the event_id; if it already exists, no-op.
  const { error: insertErr } = await adminDb.from("stripe_events_seen")
    .insert({ event_id: event.id, event_type: event.type });
  if (insertErr) {
    // Postgres unique_violation = 23505. Treat as already-processed.
    if ((insertErr as { code?: string }).code === "23505") {
      return jsonResponse({ ok: true, replay: true });
    }
    console.error("stripe_events_seen insert failed", insertErr);
    return jsonResponse({ error: "internal_error" }, 500);
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as {
        metadata?: { owner_user_id?: string; tier?: string; currency?: string; period?: string };
        customer: string;
        subscription: string;
      };
      const ownerUserId = session.metadata?.owner_user_id;
      const tier = session.metadata?.tier as "pro" | "growth" | undefined;
      const currency = session.metadata?.currency as "USD" | "CNY" | undefined;
      const period = session.metadata?.period as "monthly" | "annual" | undefined;
      if (!ownerUserId || !tier) {
        console.warn("checkout.session.completed missing metadata", session);
        break;
      }
      const sub = await stripe.subscriptions.retrieve(session.subscription);
      await adminDb.from("subscriptions").update({
        tier,
        stripe_customer_id: session.customer,
        stripe_subscription_id: sub.id,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        billing_currency: currency,
        period,
      }).eq("owner_user_id", ownerUserId);

      // Fan out tier to every store this user owns.
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier }).in("id", storeIds);
      }

      // Auto-create organization on Growth upgrade if absent.
      if (tier === "growth" && storeIds.length > 0) {
        const { data: storeRows } = await adminDb
          .from("stores").select("id, org_id").in("id", storeIds);
        const existingOrgIds = (storeRows ?? [])
          .map((s) => s.org_id as string | null).filter(Boolean) as string[];
        let orgId: string;
        if (existingOrgIds.length > 0) {
          orgId = existingOrgIds[0];
        } else {
          const { data: newOrg } = await adminDb.from("organizations")
            .insert({ name: "Default organization", created_by: ownerUserId })
            .select("id").single();
          orgId = newOrg!.id as string;
        }
        await adminDb.from("stores").update({ org_id: orgId }).in("id", storeIds);
      }
      break;
    }
    case "customer.subscription.updated": {
      const sub = event.data.object as {
        id: string; customer: string;
        current_period_end: number;
        items: { data: Array<{ price: { id: string } }> };
      };
      const newTier = tierFromPriceId(sub.items.data[0].price.id);
      const { data: subRow } = await adminDb
        .from("subscriptions").select("owner_user_id")
        .eq("stripe_subscription_id", sub.id).maybeSingle();
      if (!subRow) break;
      const ownerUserId = subRow.owner_user_id as string;
      await adminDb.from("subscriptions").update({
        tier: newTier,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      }).eq("owner_user_id", ownerUserId);
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier: newTier }).in("id", storeIds);
      }
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as { id: string };
      const { data: subRow } = await adminDb
        .from("subscriptions").select("owner_user_id")
        .eq("stripe_subscription_id", sub.id).maybeSingle();
      if (!subRow) break;
      const ownerUserId = subRow.owner_user_id as string;
      await adminDb.from("subscriptions").update({
        tier: "free",
        stripe_subscription_id: null,
        current_period_end: null,
        billing_currency: null,
        period: null,
      }).eq("owner_user_id", ownerUserId);
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier: "free" }).in("id", storeIds);
      }
      break;
    }
    case "invoice.payment_failed":
      // Stripe retries automatically. Don't downgrade on first failure.
      console.log("invoice.payment_failed observed", event.id);
      break;
    default:
      // Other event types: no-op acknowledge.
      break;
  }

  return jsonResponse({ ok: true });
}

Deno.serve(handleRequest);
