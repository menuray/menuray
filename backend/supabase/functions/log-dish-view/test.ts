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
function makeReq(body: unknown): Request {
  return new Request("http://stub/log-dish-view", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

const V = {
  menu:    "11111111-1111-1111-1111-111111111111",
  dish:    "22222222-2222-2222-2222-222222222222",
  session: "33333333-3333-3333-3333-333333333333",
  store:   "44444444-4444-4444-4444-444444444444",
};

Deno.test("400 on invalid session_id", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({
      menu_id: V.menu, dish_id: V.dish, session_id: "not-a-uuid",
    }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "invalid_session_id");
  } finally { restore(); }
});

Deno.test("404 when menu is not published", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/rest/v1/menus")) {
      return new Response(JSON.stringify([{ id: V.menu, store_id: V.store, status: "draft" }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      menu_id: V.menu, dish_id: V.dish, session_id: V.session,
    }));
    assertEquals(res.status, 404);
    assertEquals((await res.json()).error, "menu_not_published");
  } finally { restore(); }
});

Deno.test("204 when opt-in is off", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/rest/v1/menus")) {
      return new Response(JSON.stringify([{ id: V.menu, store_id: V.store, status: "published" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/dishes")) {
      return new Response(JSON.stringify([{ id: V.dish }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores")) {
      return new Response(JSON.stringify({ dish_tracking_enabled: false }), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      menu_id: V.menu, dish_id: V.dish, session_id: V.session,
    }));
    assertEquals(res.status, 204);
  } finally { restore(); }
});

Deno.test("200 happy path", async () => {
  let inserted = false;
  const restore = withStubbedFetch((url, init) => {
    if (url.includes("/rest/v1/menus")) {
      return new Response(JSON.stringify([{ id: V.menu, store_id: V.store, status: "published" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/dishes")) {
      return new Response(JSON.stringify([{ id: V.dish }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores")) {
      return new Response(JSON.stringify({ dish_tracking_enabled: true }), { status: 200 });
    }
    if (url.includes("/rest/v1/dish_view_logs") && init?.method === "POST") {
      inserted = true;
      return new Response("[]", { status: 201 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      menu_id: V.menu, dish_id: V.dish, session_id: V.session,
    }));
    assertEquals(res.status, 200);
    assertEquals((await res.json()).ok, true);
    assertEquals(inserted, true);
  } finally { restore(); }
});

Deno.test("404 when dish does not belong to menu", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/rest/v1/menus")) {
      return new Response(JSON.stringify([{ id: V.menu, store_id: V.store, status: "published" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/dishes")) {
      return new Response(JSON.stringify([]), { status: 200 });  // not found
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({
      menu_id: V.menu, dish_id: V.dish, session_id: V.session,
    }));
    assertEquals(res.status, 404);
    assertEquals((await res.json()).error, "dish_not_in_menu");
  } finally { restore(); }
});
