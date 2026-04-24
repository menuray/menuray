import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");

const { handleRequest } = await import("./index.ts");

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}
function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/create-store", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("400 when name missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({}));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "name_required");
  } finally { restore(); }
});

Deno.test("403 when user is not on growth tier", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ user: { id: "u1" } }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "pro" }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ name: "New shop" }));
    assertEquals(res.status, 403);
    assertEquals((await res.json()).error, "multi_store_requires_growth");
  } finally { restore(); }
});

Deno.test("200 happy path returns storeId", async () => {
  let storeCreateCalled = 0;
  const restore = withStubbedFetch((url, init) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ user: { id: "u1" } }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "growth" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/store_members") && init?.method === "POST") {
      return new Response(JSON.stringify({}), { status: 201 });
    }
    if (url.includes("/rest/v1/store_members")) {
      return new Response(JSON.stringify([{ store_id: "existing-1" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && init?.method === "POST") {
      storeCreateCalled++;
      return new Response(JSON.stringify({ id: "new-store-1" }), {
        status: 201, headers: { "Content-Type": "application/json" },
      });
    }
    if (url.includes("/rest/v1/stores")) {
      return new Response(JSON.stringify([{ org_id: "org-1" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/organizations")) {
      return new Response(JSON.stringify({ id: "org-1" }), { status: 201 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ name: "Second shop" }));
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.storeId, "new-store-1");
    assertEquals(storeCreateCalled, 1);
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-store", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "x" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});
