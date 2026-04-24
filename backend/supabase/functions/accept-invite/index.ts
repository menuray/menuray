import { createAnonClientWithJwt } from "../_shared/db.ts";

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "must_be_signed_in" }, 401);
  }
  const jwt = auth.slice("Bearer ".length);

  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const token = body.token;
  if (!token || typeof token !== "string") {
    return jsonResponse({ error: "token_required" }, 400);
  }

  const db = createAnonClientWithJwt(jwt);
  const { data, error } = await db.rpc("accept_invite", { p_token: token });

  if (error) {
    const code = (error.message || "").toLowerCase();
    if (code.includes("invalid_or_expired_invite")) return jsonResponse({ error: "invalid_or_expired_invite" }, 404);
    if (code.includes("invite_expired"))           return jsonResponse({ error: "invite_expired" }, 410);
    if (code.includes("must_be_signed_in"))        return jsonResponse({ error: "must_be_signed_in" }, 401);
    console.error("accept_invite rpc failed", error);
    return jsonResponse({ error: "internal_error" }, 500);
  }
  return jsonResponse({ storeId: data });
}

Deno.serve(handleRequest);
