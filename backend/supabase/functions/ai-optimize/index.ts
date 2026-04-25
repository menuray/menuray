import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
import { AI_BATCH_QUOTA, type Tier } from "../_shared/quotas.ts";
import { runOptimize } from "./orchestrator.ts";

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
  if (!auth || !auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }
  const jwt = auth.slice("Bearer ".length);

  let body: { menu_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const menuId = body.menu_id?.trim();
  if (!menuId) return jsonResponse({ error: "menu_id_required" }, 400);

  const anonDb = createAnonClientWithJwt(jwt);
  const { data: menuOk, error: rlsErr } = await anonDb
    .from("menus").select("id, store_id")
    .eq("id", menuId).maybeSingle();
  if (rlsErr) {
    console.error("menus rls lookup failed", rlsErr);
    return jsonResponse({ error: "lookup_failed" }, 500);
  }
  if (!menuOk) return jsonResponse({ error: "menu_not_found_or_forbidden" }, 404);
  const storeId = (menuOk as { store_id: string }).store_id;

  const adminDb = createServiceRoleClient();
  const { data: storeRow } = await adminDb
    .from("stores").select("tier")
    .eq("id", storeId).maybeSingle();
  const tier = ((storeRow?.tier ?? "free") as Tier);

  const monthStart = new Date();
  monthStart.setUTCDate(1);
  monthStart.setUTCHours(0, 0, 0, 0);
  const { count: monthlyCount } = await adminDb
    .from("ai_runs").select("id", { count: "exact", head: true })
    .eq("store_id", storeId).gte("created_at", monthStart.toISOString());
  if ((monthlyCount ?? 0) >= AI_BATCH_QUOTA[tier]) {
    return jsonResponse({
      error: "ai_quota_exceeded",
      tier,
      cap: AI_BATCH_QUOTA[tier],
    }, 429);
  }

  const startedAt = Date.now();
  try {
    const result = await runOptimize(menuId);
    await adminDb.from("ai_runs").insert({
      store_id: storeId,
      kind: "optimize",
      dish_count: result.rewrittenDishCount,
      ms: Date.now() - startedAt,
      ok: true,
    });
    return jsonResponse(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-optimize failed", message);
    await adminDb.from("ai_runs").insert({
      store_id: storeId,
      kind: "optimize",
      ms: Date.now() - startedAt,
      ok: false,
      error: message.slice(0, 500),
    });
    return jsonResponse({ error: "optimize_failed", detail: message }, 500);
  }
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
