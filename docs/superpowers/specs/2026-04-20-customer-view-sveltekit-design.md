# Customer View (SvelteKit) — Design

Date: 2026-04-20
Scope: Build the first four customer-facing screens (B1 menu home / B2 dish detail / B3 search-filter / B4 language switcher) as a brand-new SvelteKit 2 app under `frontend/customer/`, reading published menus from Supabase via anon key. Served at `menu.menuray.com/<slug>` (SSR). First paint <500 ms on 4G.
Audience: whoever implements the follow-up plan. Scoped to this sub-batch only — launch templates (sub-batch 2) and merchant polish (sub-batch 3) are separate specs.

## 1. Goal & Scope

Customer flow after scanning a QR / opening a shared link:

```
GET /<slug>                 → B1 menu home (SSR)
                              header (store name, logo, langs, MenuRay badge)
                              sticky category nav
                              list/grid of dish cards (tap card → B2)
                              search input + filter drawer (B3, all client-side)
                              lang dropdown (B4)
                                │
                                ▼
GET /<slug>/<dishId>        → B2 dish detail (SSR)
                              cover image, name, desc, price, allergens, spice,
                              signature/recommended/veg badges, back to B1
```

**In scope**

- Brand-new SvelteKit 2 app at `frontend/customer/` (single package, not a workspace).
- Svelte 5 runes (`$state`, `$derived`, `$effect`), Tailwind v4 for styling, pnpm as package manager.
- Supabase JS client (`@supabase/supabase-js`) using the same anon key as merchant.
- Route `+page.server.ts` for both `/<slug>` and `/<slug>/<dishId>`: SSR-fetches the menu + all nested data, writes a `view_logs` row before returning.
- B1 menu home: header with store name/logo, sticky category nav, dish card list (minimal list layout for this sub-batch — template-specific rendering arrives in sub-batch 2), client-side search input, client-side filter drawer (spice/vegetarian/signature/recommended), language dropdown.
- B2 dish detail: full-screen slide-up-feeling page with cover image, name, translated description, price, allergens pills, spice level indicator, badges, back button to B1 preserving scroll.
- B3 search + filter: implemented entirely as part of B1's state — no separate route, but its behaviour is spec'd independently.
- B4 language switcher: dropdown in B1 header; reads `?lang=<locale>` query param first, falls back to `localStorage['menuray.lang']`, then to menu `source_locale`. Switching updates URL + localStorage + re-derives visible strings client-side from the already-SSR'd translations payload.
- SEO: per-page `<title>`, `<meta name="description">`, `og:image` (cover), JSON-LD schema.org `Restaurant` + `Menu` + `MenuItem`.
- MenuRay "由 MenuRay 提供 →" badge: fixed-position bottom bar on every customer page, small, utm-tagged link to `menuray.com`. Removable via a `store.custom_branding_off` flag (schema unchanged; we read but never write it — toggle lands in sub-batch 2's pricing work).
- Error pages: 404 for missing slug, 410 for draft/archived menu, SSR-friendly `+error.svelte` with the brand palette.
- Smoke Playwright tests for B1 happy path + 410 state.
- **New backend migration** `backend/supabase/migrations/<timestamp>_anon_stores_read.sql`: add `stores_anon_read_of_published` policy so anon can SELECT the `stores` row of any store that owns at least one published menu. Existing RLS blocks anon SELECT on `stores` entirely, which would leave B1 without the store name, logo, or `source_locale`.

**Out of scope (deferred)**

- **Template-specific rendering** (Minimal / Grid visual variants) — sub-batch 2. B1 renders with a single minimal default; template switching is a layer we plug in later.
- **Merchant polish** (logout, register wire, form validation, loading/error/empty audit) — sub-batch 3.
- **QR generation** — lives in merchant Flutter via `qr_flutter`; customer view doesn't generate QR.
- Customer auth / favorites / order-ahead / cart — not in product scope.
- Push notifications / service worker / offline cache — future.
- View-log bot filtering / rate-limiting — Session 2 edge function.
- Production domain wiring (`menu.menuray.com`) — dev first; deployment deferred to infra session.
- Analytics dashboard for merchant — Session 5.
- `view_logs` session-dedup: we log every SSR hit for now; dedup logic added when analytics pipeline is built.
- Custom-branding toggle UI (lives in merchant app, sub-batch 2 / Session 4 pricing).

## 2. Context

- Supabase schema (`backend/supabase/migrations/20260420000001_init_schema.sql`): 9 tables. Customer view reads from `menus`, `stores`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, and writes to `view_logs`.
- RLS (`20260420000002_rls_policies.sql`): anon SELECT on `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations` is gated by `menu.status = 'published'`. Anon INSERT allowed on `view_logs`. **Gap:** anon has NO SELECT on `stores` today (line 95 of the policy file calls this out explicitly). Sub-batch 1 adds a new policy to close it — see §3.11.
- "Published" menu = `status = 'published'` AND `slug IS NOT NULL` (DB constraint `published_requires_slug`).
- Brand tokens (`docs/DESIGN.md`): `primary #2F5D50`, `accent #E0A969`, `surface #FBF7F0`, `ink #1F1F1F`, `secondary #6B7B6F`, `error #C2553F`, `divider #ECE7DC`. Fonts: Inter + 思源黑体 (Noto Sans SC); 8 px baseline grid; card radius 16 px; button radius 12 px.
- Supabase anon key + URL: same as merchant, declared in `frontend/merchant/lib/config/supabase_config.dart`. Customer reads them from `$env/static/public` (prefixed `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY`), with local-dev defaults baked into the code.
- Product decisions (`docs/product-decisions.md` §2 pricing, §5 templates): Free tier shows MenuRay badge and caps at 2 locales; Pro+ removes badge and unlocks 5 locales. Badge is always rendered by default in Session 1 — pricing enforcement comes later. Locale cap is enforced by merchant (dish_translations rows simply don't exist beyond the cap); customer just renders what's there.
- ADR-017 pattern (Flutter repository + provider + mapper) inspires the SvelteKit data layer but doesn't map 1:1. SvelteKit equivalents: `+page.server.ts` (repository + mapper collapsed), Svelte store (Riverpod provider), `lib/types/menu.ts` (model).

## 3. Decisions

### 3.1 Toolchain

- **SvelteKit 2.x latest + Svelte 5 with runes**. No Svelte 4 syntax.
- **Tailwind v4** (`@tailwindcss/vite`). Brand colors exposed as CSS variables in `app.css` under `--color-primary`, `--color-accent`, etc., mapped through Tailwind v4's `@theme` directive so classes like `bg-primary` just work.
- **pnpm** as package manager. `pnpm-lock.yaml` committed.
- **Node 22 LTS** (declared in `.nvmrc` + `engines` in `package.json`).
- **Adapter**: `@sveltejs/adapter-node` for dev/prod parity. (Vercel/Cloudflare swap is a deploy-time concern, not a design one.)

### 3.2 Repo layout

Single package, no monorepo tooling, no workspace file:

```
frontend/customer/
├── .nvmrc
├── package.json
├── pnpm-lock.yaml
├── svelte.config.js
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.js            # Tailwind v4 config (minimal)
├── src/
│   ├── app.css                   # brand CSS variables + Tailwind base
│   ├── app.html                  # root template with <html lang="{lang}">
│   ├── app.d.ts
│   ├── hooks.server.ts           # Supabase anon client per-request
│   ├── lib/
│   │   ├── supabase.ts           # createClient() helper (SSR + browser)
│   │   ├── types/
│   │   │   └── menu.ts           # Menu / Category / Dish / Translation types
│   │   ├── data/
│   │   │   ├── fetchPublishedMenu.ts   # by slug → full tree
│   │   │   └── logView.ts              # insert into view_logs
│   │   ├── i18n/
│   │   │   ├── resolveLocale.ts        # URL param → localStorage → source_locale
│   │   │   └── strings.ts              # static UI strings (en/zh) for header/buttons
│   │   ├── components/
│   │   │   ├── MenuHeader.svelte
│   │   │   ├── CategoryNav.svelte
│   │   │   ├── DishCard.svelte
│   │   │   ├── SearchBar.svelte
│   │   │   ├── FilterDrawer.svelte
│   │   │   ├── LangDropdown.svelte
│   │   │   ├── AllergensPills.svelte
│   │   │   ├── SpiceIndicator.svelte
│   │   │   └── MenurayBadge.svelte
│   │   └── seo/
│   │       └── jsonLd.ts               # schema.org builder
│   └── routes/
│       ├── +layout.svelte              # shell: <MenurayBadge/>, fonts, html lang
│       ├── +error.svelte               # 404 / 410 brand page
│       ├── [slug]/
│       │   ├── +page.server.ts         # SSR fetch + view_logs + JSON-LD
│       │   ├── +page.svelte            # B1 home (hosts B3 search/filter, B4 lang)
│       │   └── [dishId]/
│       │       ├── +page.server.ts     # SSR fetch dish + translations
│       │       └── +page.svelte        # B2 dish detail
│       └── +page.svelte                # root `/` placeholder → "Visit menu.menuray.com/<slug>"
├── static/
│   └── menuray-logo.svg                # brand mark for badge
└── tests/
    └── e2e/
        ├── b1-happy.spec.ts            # Playwright
        └── b1-410.spec.ts
```

### 3.3 Data fetching

Both SSR routes use one Supabase query that joins everything the page needs, ordered by `categories.position` then `dishes.position`. Two patterns:

```ts
// src/lib/data/fetchPublishedMenu.ts
export async function fetchPublishedMenu(
  supabase: SupabaseClient,
  slug: string,
  locale: string
): Promise<PublishedMenu | null> {
  const { data, error } = await supabase
    .from('menus')
    .select(`
      id, name, status, slug, cover_image_url, currency, source_locale,
      time_slot, time_slot_description, published_at,
      store:stores ( id, name, logo_url, address, source_locale,
        store_translations ( locale, name, address )
      ),
      categories ( id, source_name, position,
        category_translations ( locale, name ),
        dishes ( id, source_name, source_description, price, image_url,
                 position, spice_level, is_signature, is_recommended,
                 is_vegetarian, sold_out, allergens,
                 dish_translations ( locale, name, description ) )
      )
    `)
    .eq('slug', slug)
    .eq('status', 'published')
    .maybeSingle();

  if (error || !data) return null;
  return toPublishedMenu(data, locale);  // sort, apply translations
}
```

- `maybeSingle()` returns `null` on zero rows → route throws `error(404, ...)`.
- If row exists but `status !== 'published'` (can't happen under RLS, but belt-and-braces on any future policy change), throw `error(410, ...)`.
- `toPublishedMenu` sorts categories by `position`, dishes within each by `position`, and resolves translations: returns both `source_name` and `translations: Record<locale, {name, description}>` so the client can switch language without refetching.

### 3.4 SSR view logging

In `[slug]/+page.server.ts` after the menu loads successfully, `await logView(supabase, menu.id, menu.store.id, locale, request.headers)`. Non-blocking failures: wrap in `try/catch`, never surface to the user.

`view_logs` row: `{menu_id, store_id, locale, session_id: null (future), referrer_domain: extracted from Referer header if not our own domain}`.

### 3.5 B3 search & filter

Client-only state held in `+page.svelte`:

```ts
let query = $state('');
let filters = $state({
  spice: new Set<SpiceLevel>(),    // 'mild'|'medium'|'hot'
  vegetarian: false,
  signature: false,
  recommended: false,
});
let visible = $derived(applyFilters(menu, query, filters, locale));
```

Scope of search: matches `name + description` in currently-selected locale, falling back to `source_name + source_description` when translations are missing. Case-insensitive, diacritic-insensitive (normalize via `.normalize('NFKD')`).

Filter drawer opens as bottom sheet on mobile, side panel ≥768 px. Filter chip bar at top shows active filters and a "Clear" pill.

Category nav updates based on what's still visible — empty categories hidden from the sticky nav while filters are active.

### 3.6 B4 language resolution

Precedence when resolving active locale:

1. `url.searchParams.get('lang')` if it's in the menu's `availableLocales`.
2. `localStorage['menuray.lang']` (only on client — SSR skips this).
3. Browser `Accept-Language` (SSR only, parsed from request headers).
4. `menu.source_locale` fallback.

`availableLocales = [source_locale, ...all distinct locales across dish_translations and category_translations]`.

Switching:
- Update URL via `goto(\`?lang=${next}\`, { noScroll: true, replaceState: true })`.
- Write `localStorage['menuray.lang'] = next` in an `$effect`.
- All visible strings re-derive from `$derived` without refetching.

`<html lang>`: set to source_locale during SSR; updated on the client when user switches (via `$effect` → `document.documentElement.lang = next`).

### 3.7 SEO + JSON-LD

`+page.server.ts` returns page metadata in the load function; `+page.svelte` uses `<svelte:head>` to render:

- `<title>{store.name} — {menu.name} | MenuRay</title>`
- `<meta name="description" content={first 155 chars of menu description / dish summary}>`
- `<meta property="og:image" content={menu.cover_image_url}>`
- `<meta property="og:locale" content={locale}>`
- JSON-LD `<script type="application/ld+json">` with schema.org `Restaurant` (store) + `Menu` (menu) + nested `MenuSection` (categories) + `MenuItem` (dishes). One script tag per page, built by `src/lib/seo/jsonLd.ts`.

### 3.8 MenurayBadge

Fixed `bottom-0 left-0 right-0`, height 32 px, background `surface` with top border `divider`, text `由 MenuRay 提供 →` (English: `Powered by MenuRay →`) in `secondary` color, tapping opens `https://menuray.com/?utm_source=menu&utm_medium=customer_view&utm_campaign=powered_by`. Rendered inside `+layout.svelte`. Hidden when `menu.store.custom_branding_off === true` (column doesn't yet exist — treated as always `false` this sub-batch; column lands in sub-batch 2's template/branding schema work).

### 3.9 Error states

- **404**: slug doesn't exist in DB. Render `+error.svelte` with "Menu not found" + link to menuray.com.
- **410**: slug exists but menu is draft/archived (can only happen if RLS changes later). Same brand shell, text "This menu is no longer available."
- **Store without published menu**: treated as 404 — we only fetch by slug.
- Network / Supabase error during SSR: 500 via SvelteKit default; we log server-side but don't surface details.

### 3.10 Testing

- **Playwright e2e** (local Supabase, seeded): `tests/e2e/b1-happy.spec.ts` asserts the happy path — slug renders, dish cards present, tap card navigates to B2, lang switch updates visible strings. `tests/e2e/b1-410.spec.ts` sets a menu to `archived` and verifies 410 page.
- **Component unit tests**: deferred. Smoke + e2e only this sub-batch.
- **`pnpm check` (svelte-check) must be clean** before commit — non-negotiable, mirrors merchant's `flutter analyze` bar.
- **CI hook**: add `pnpm check` + `pnpm test` to the top-level repo test script so merchant + customer run together.

### 3.11 RLS addition — anon SELECT on stores of published menus

New migration file (next available timestamp after `20260420000003_storage_buckets.sql`):

```sql
CREATE POLICY stores_anon_read_of_published ON stores FOR SELECT TO anon
  USING (EXISTS (
    SELECT 1 FROM menus
    WHERE menus.store_id = stores.id
      AND menus.status = 'published'
  ));
```

Rationale: mirrors Pattern 2 (anon SELECT on child rows gated by a published menu) but applied to the parent `stores` table. Without this, the customer-view SSR join returns `store = null` and we lose store name, logo, and `source_locale`. Owner RLS on `stores` (Pattern 1) is unchanged.

After this change, anon can read *any* row in `stores` that has at least one published menu. The only `stores` columns exposed are the ones a customer view legitimately shows (`name`, `logo_url`, `address`, `source_locale`) plus `id`, `owner_id`, `created_at`, `updated_at`. `owner_id` leaking via the table is a minor concern: it's a uuid, not PII, and no other table exposes auth.users. We keep all `stores` columns visible (rather than picking a view) because (a) no column here is sensitive and (b) adding a view or column-level grants is complexity we don't need yet.

### 3.12 Local dev

- `frontend/customer/` is runnable with `pnpm install && pnpm dev` → `http://localhost:5173`.
- Supabase URL defaults to `http://127.0.0.1:54321`; anon key baked as a default in `src/lib/supabase.ts` (same pattern as merchant).
- Seeding: merchant must first publish a menu via the Flutter app (or via `backend/supabase/seed.sql` which we extend to insert one sample published menu with a known slug like `demo-cafe`).

## 4. Data model (TypeScript types)

```ts
// src/lib/types/menu.ts
export type Locale = string;  // 'en', 'zh-CN', 'ja', …
export type SpiceLevel = 'none'|'mild'|'medium'|'hot';
export type TimeSlot = 'all_day'|'lunch'|'dinner'|'seasonal';

export interface PublishedMenu {
  id: string;
  slug: string;
  name: string;
  currency: string;
  source_locale: Locale;
  availableLocales: Locale[];
  time_slot: TimeSlot;
  time_slot_description: string | null;
  cover_image_url: string | null;
  published_at: string;
  store: Store;
  categories: Category[];
}

export interface Store {
  id: string;
  logo_url: string | null;
  source_name: string;
  source_address: string | null;
  translations: Record<Locale, { name: string; address: string | null }>;
  custom_branding_off: boolean;  // always false this sub-batch
}

export interface Category {
  id: string;
  source_name: string;
  position: number;
  translations: Record<Locale, { name: string }>;
  dishes: Dish[];
}

export interface Dish {
  id: string;
  source_name: string;
  source_description: string | null;
  price: number;
  image_url: string | null;
  position: number;
  spice_level: SpiceLevel;
  is_signature: boolean;
  is_recommended: boolean;
  is_vegetarian: boolean;
  sold_out: boolean;
  allergens: string[];
  translations: Record<Locale, { name: string; description: string | null }>;
}
```

## 5. Dependencies (new)

```jsonc
// package.json (customer)
{
  "dependencies": {
    "@supabase/supabase-js": "^2.x"
  },
  "devDependencies": {
    "@sveltejs/adapter-node": "^5.x",
    "@sveltejs/kit": "^2.x",
    "@sveltejs/vite-plugin-svelte": "^4.x",
    "svelte": "^5.x",
    "svelte-check": "^4.x",
    "typescript": "^5.x",
    "vite": "^6.x",
    "tailwindcss": "^4.x",
    "@tailwindcss/vite": "^4.x",
    "@playwright/test": "^1.x"
  }
}
```

No other dependencies this sub-batch. Schema.org JSON-LD is hand-built (tiny), not via a library.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Tailwind v4 still has rough edges in some `@theme` usages with CSS variables | Keep CSS variables + classes simple; fall back to inline `style="--x:..."` on isolated spots if the token indirection misbehaves |
| Supabase join query returns > 2 MB for large menus | Fine for launch (menus < 200 dishes); monitor. If exceeded, split into `menus + nested categories` query + separate dishes query, both still SSR |
| Running `pnpm` in a repo that already uses Flutter workflows — no global lockfile conflict | `frontend/customer/` has its own lockfile, independent. Root `package.json` stays untouched |
| Playwright MCP vs. plain `@playwright/test` confusion | Tests live as `@playwright/test` files (`.spec.ts`) runnable via `pnpm test`. Playwright MCP is the interactive driver for brainstorming sessions, not for CI |
| Adapter-node vs. static — want SEO | Adapter-node is SSR capable. Static adapter would ship HTML + hydration but wouldn't support the `?lang=` query in JSON-LD / `<html lang>`. Sticking with node |
| Anon key leakage | Already public by design (RLS is the gate); baking it into the client bundle is intended |

## 7. Open questions

None for this sub-batch — all the meaningful choices are pinned in §3.

## 8. Success criteria

- Running `cd frontend/customer && pnpm install && pnpm dev` serves B1 at `http://localhost:5173/<slug>` for any published menu in local Supabase.
- Tapping a dish card navigates to `/<slug>/<dishId>` and renders B2.
- Search + filter drawer work purely client-side with no network traffic after initial SSR.
- Language dropdown switches visible strings instantly; URL + localStorage persist.
- Lighthouse SEO ≥ 95; JSON-LD validates against schema.org tester.
- First contentful paint < 500 ms locally with 4G throttling.
- `pnpm check` + `pnpm test` pass with no warnings.
- One sample published menu (`demo-cafe`) exists in `backend/supabase/seed.sql` for development and tests.
