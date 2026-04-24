import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";

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

  let body: { name?: string; currency?: string; source_locale?: string };
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json_body" }, 400); }
  const name = (body.name ?? "").trim();
  if (!name) return jsonResponse({ error: "name_required" }, 400);

  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const userId = userResp.user.id;

  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("tier")
    .eq("owner_user_id", userId).maybeSingle();
  if (subRow?.tier !== "growth") {
    return jsonResponse({ error: "multi_store_requires_growth" }, 403);
  }

  // Find an existing organization for this user (an owned store with a non-null org_id).
  const { data: ownedRows } = await adminDb
    .from("store_members").select("store_id")
    .eq("user_id", userId).eq("role", "owner")
    .not("accepted_at", "is", null);
  const ownedIds = (ownedRows ?? []).map((r) => r.store_id as string);
  let orgId: string | null = null;
  if (ownedIds.length > 0) {
    const { data: storeRows } = await adminDb
      .from("stores").select("org_id").in("id", ownedIds);
    orgId = (storeRows ?? []).map((s) => s.org_id as string | null).find(Boolean) ?? null;
  }
  if (!orgId) {
    const { data: newOrg } = await adminDb.from("organizations")
      .insert({ name: "Default organization", created_by: userId })
      .select("id").single();
    orgId = newOrg!.id as string;
    if (ownedIds.length > 0) {
      await adminDb.from("stores").update({ org_id: orgId }).in("id", ownedIds);
    }
  }

  const { data: created, error: createErr } = await adminDb.from("stores").insert({
    name,
    currency: body.currency ?? "USD",
    source_locale: body.source_locale ?? "en",
    tier: "growth",
    org_id: orgId,
  }).select("id").single();
  if (createErr || !created) {
    console.error("store create failed", createErr);
    return jsonResponse({ error: "internal_error" }, 500);
  }
  const storeId = created.id as string;

  await adminDb.from("store_members").insert({
    store_id: storeId, user_id: userId, role: "owner", accepted_at: new Date().toISOString(),
  });

  return jsonResponse({ storeId });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
