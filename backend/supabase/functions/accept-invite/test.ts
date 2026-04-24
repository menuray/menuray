import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./index.ts";

// Stub fetch used by the supabase-js client's PostgREST + RPC calls.
function withStubbedFetch(
  responder: (input: string | URL | Request, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => Promise.resolve(responder(input as any, init))) as typeof fetch;
  return () => { globalThis.fetch = original; };
}

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/accept-invite", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("400 when token missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({}));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "token_required");
  } finally { restore(); }
});

Deno.test("401 when no Authorization header", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/accept-invite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: "abc" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});

Deno.test("200 happy path returns storeId", async () => {
  const restore = withStubbedFetch(() =>
    new Response(JSON.stringify("11111111-2222-2222-2222-222222222222"), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  );
  try {
    const res = await handleRequest(makeReq({ token: "good-token" }));
    assertEquals(res.status, 200);
    assertEquals((await res.json()).storeId, "11111111-2222-2222-2222-222222222222");
  } finally { restore(); }
});

Deno.test("404 when invite invalid/expired code from PG", async () => {
  const restore = withStubbedFetch(() =>
    new Response(JSON.stringify({ code: "P0001", message: "invalid_or_expired_invite", details: null }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  );
  try {
    const res = await handleRequest(makeReq({ token: "bad" }));
    assertEquals(res.status, 404);
    assertEquals((await res.json()).error, "invalid_or_expired_invite");
  } finally { restore(); }
});

Deno.test("410 when PG raises invite_expired", async () => {
  const restore = withStubbedFetch(() =>
    new Response(JSON.stringify({ code: "P0001", message: "invite_expired" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  );
  try {
    const res = await handleRequest(makeReq({ token: "old" }));
    assertEquals(res.status, 410);
    assertEquals((await res.json()).error, "invite_expired");
  } finally { restore(); }
});
