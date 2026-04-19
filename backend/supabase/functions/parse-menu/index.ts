import { createAnonClientWithJwt } from "../_shared/db.ts";
import { runParse } from "./orchestrator.ts";

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }
  const jwt = auth.slice("Bearer ".length);

  let body: { run_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const runId = body.run_id;
  if (!runId) {
    return jsonResponse({ error: "run_id_required" }, 400);
  }

  // Check user owns this run via their JWT (RLS kicks in on the anon client).
  const anonDb = createAnonClientWithJwt(jwt);
  const { data: row, error } = await anonDb
    .from("parse_runs")
    .select("id")
    .eq("id", runId)
    .maybeSingle();
  if (error) {
    console.error("parse_runs lookup failed", error);
    return jsonResponse({ error: "lookup_failed" }, 500);
  }
  if (!row) return jsonResponse({ error: "run_not_found_or_forbidden" }, 404);

  // Proceed with service_role client for the actual work.
  const finalStatus = await runParse(runId);
  return jsonResponse({ run_id: runId, status: finalStatus });
});
