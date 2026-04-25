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

function csvRow(cells: Array<string | number>): string {
  return cells.map((c) => {
    const s = String(c);
    if (s.includes(",") || s.includes('"') || s.includes("\n")) {
      return '"' + s.replaceAll('"', '""') + '"';
    }
    return s;
  }).join(",");
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const jwt = auth.slice("Bearer ".length);

  let body: { store_id?: string; from?: string; to?: string };
  try { body = await req.json(); } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const { store_id: storeId, from, to } = body;
  if (!storeId || !from || !to) return jsonResponse({ error: "missing_params" }, 400);

  // Resolve user + check tier.
  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const userId = userResp.user.id;

  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("tier").eq("owner_user_id", userId).maybeSingle();
  if (subRow?.tier !== "growth") return jsonResponse({ error: "csv_requires_growth" }, 402);

  // Run 4 aggregation RPCs via the user's JWT so the SECURITY DEFINER
  // functions get auth.uid() = userId (and validate membership).
  const [overview, byDay, topDishes, byLocale] = await Promise.all([
    anonDb.rpc("get_visits_overview",    { p_store_id: storeId, p_from: from, p_to: to }),
    anonDb.rpc("get_visits_by_day",      { p_store_id: storeId, p_from: from, p_to: to }),
    anonDb.rpc("get_top_dishes",         { p_store_id: storeId, p_from: from, p_to: to, p_limit: 100 }),
    anonDb.rpc("get_traffic_by_locale",  { p_store_id: storeId, p_from: from, p_to: to }),
  ]);
  for (const r of [overview, byDay, topDishes, byLocale]) {
    if (r.error) {
      if ((r.error.message || "").includes("not_a_member")) {
        return jsonResponse({ error: "not_a_member" }, 403);
      }
      console.error("aggregation rpc failed", r.error);
      return jsonResponse({ error: "internal_error" }, 500);
    }
  }

  // Build CSV.
  const lines: string[] = [];
  lines.push(`# Visits overview (${from} → ${to})`);
  lines.push(csvRow(["total_views", "unique_sessions"]));
  const over = overview.data as { total_views: number; unique_sessions: number };
  lines.push(csvRow([over?.total_views ?? 0, over?.unique_sessions ?? 0]));
  lines.push("");
  lines.push("# Visits by day");
  lines.push(csvRow(["day", "count"]));
  for (const row of (byDay.data as Array<{ day: string; count: number }>) ?? []) {
    lines.push(csvRow([row.day, row.count]));
  }
  lines.push("");
  lines.push("# Top dishes");
  lines.push(csvRow(["dish_id", "dish_name", "count"]));
  for (const row of (topDishes.data as Array<{ dish_id: string; dish_name: string; count: number }>) ?? []) {
    lines.push(csvRow([row.dish_id, row.dish_name, row.count]));
  }
  lines.push("");
  lines.push("# Traffic by locale");
  lines.push(csvRow(["locale", "count"]));
  for (const row of (byLocale.data as Array<{ locale: string; count: number }>) ?? []) {
    lines.push(csvRow([row.locale, row.count]));
  }
  lines.push("");

  const filename = `menuray-statistics-${from.slice(0,10)}-${to.slice(0,10)}.csv`;
  return new Response(lines.join("\n"), {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      ...CORS_HEADERS,
    },
  });
}

Deno.serve(handleRequest);
