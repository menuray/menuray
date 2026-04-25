import { createServiceRoleClient } from "../_shared/db.ts";

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

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: { menu_id?: string; dish_id?: string; session_id?: string; qr_variant?: string };
  try { body = await req.json(); } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const menuId = body.menu_id;
  const dishId = body.dish_id;
  const sessionId = body.session_id;
  if (!menuId || !UUID_RE.test(menuId)) return jsonResponse({ error: "invalid_menu_id" }, 400);
  if (!dishId || !UUID_RE.test(dishId)) return jsonResponse({ error: "invalid_dish_id" }, 400);
  if (!sessionId || !UUID_RE.test(sessionId)) return jsonResponse({ error: "invalid_session_id" }, 400);

  const adminDb = createServiceRoleClient();

  // 1. Menu must exist + be published.
  const { data: menuRow } = await adminDb
    .from("menus").select("id, store_id, status")
    .eq("id", menuId).maybeSingle();
  if (!menuRow || menuRow.status !== "published") {
    return jsonResponse({ error: "menu_not_published" }, 404);
  }
  const storeId = menuRow.store_id as string;

  // 2. Dish must belong to that menu.
  const { data: dishRow } = await adminDb
    .from("dishes").select("id").eq("id", dishId).eq("menu_id", menuId).maybeSingle();
  if (!dishRow) return jsonResponse({ error: "dish_not_in_menu" }, 404);

  // 3. Check opt-in.
  const { data: storeRow } = await adminDb
    .from("stores").select("dish_tracking_enabled")
    .eq("id", storeId).single();
  if (!storeRow?.dish_tracking_enabled) {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  // 4. Insert.
  const { error } = await adminDb.from("dish_view_logs").insert({
    menu_id: menuId, store_id: storeId, dish_id: dishId, session_id: sessionId,
  });
  if (error) {
    console.error("dish_view_logs insert failed", error);
    return jsonResponse({ error: "internal_error" }, 500);
  }
  return jsonResponse({ ok: true });
}

Deno.serve(handleRequest);
