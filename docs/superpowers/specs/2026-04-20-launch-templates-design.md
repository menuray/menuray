# Launch Templates (Minimal + Grid) — Design

Date: 2026-04-20
Scope: Add per-menu template selection + primary-color + cover-image + logo customization. Two launch templates (Minimal, Grid) plus three placeholders (Bistro, Izakaya, Street) hidden behind a "Coming soon" tag until the designer delivers them. Customer view renders the chosen template; merchant app picks it via a new screen plus a logo-upload affordance on the existing store-management screen.
Audience: whoever implements the follow-up plan. Scoped to this sub-batch only — sub-batch 1 (customer view B1–B4) is already shipped; sub-batch 3 (merchant polish) is a separate spec.

## 1. Goal & Scope

After this sub-batch, a merchant can:

1. Tap "Appearance" on a menu → pick Minimal or Grid → pick 1 of 12 primary-color swatches → save.
2. Tap the logo slot on the store-management screen → choose an image → it uploads to Supabase Storage and the `stores.logo_url` updates.
3. Visit the customer view at `menu.menuray.com/<slug>` and see the chosen template rendered with the chosen primary color and logo.

**In scope**

- **Backend migration** `20260420000006_templates_and_theme.sql`:
  - `templates (id text PK, name text, description text, preview_image_url text, is_launch boolean DEFAULT false)` seeded with 5 rows.
  - `menus.template_id text NOT NULL DEFAULT 'minimal' REFERENCES templates(id)`.
  - `menus.theme_overrides jsonb NOT NULL DEFAULT '{}'`.
  - RLS: `templates` is anon-readable (no gating — it's a static reference table); `menus` RLS unchanged (updating template_id is part of owner RW).
- **Customer view (`frontend/customer/`)**:
  - New dir `src/lib/templates/minimal/` with `MenuPage.svelte` (+ any per-template sub-components).
  - New dir `src/lib/templates/grid/` with `MenuPage.svelte` (+ per-template sub-components).
  - `[slug]/+page.svelte` becomes a thin dispatcher: `{#if template_id === 'grid'} <GridLayout/> {:else} <MinimalLayout/> {/if}`.
  - `[slug]/+page.server.ts` load function additionally returns `template_id` and `theme_overrides` from the fetched menu.
  - `fetchPublishedMenu` mapper adds `templateId: string` and `themeOverrides: ThemeOverrides` to `PublishedMenu`.
  - Primary-color override: `+layout.svelte` reads `data?.themeOverrides?.primaryColor` and, if present, injects a `<style>:root{--color-primary: X}</style>` block in `<svelte:head>`. Zero Tailwind rebuild needed — the `@theme` variable takes a runtime value.
  - Static preview images at `static/templates/minimal.png` + `static/templates/grid.png` (placeholders; designer replaces later).
- **Customer view template components**:
  - **MinimalLayout**: single-column, generous whitespace, no cover image. Reuses `MenuHeader` / `CategoryNav` / `DishCard` / `SearchBar` / `FilterDrawer` / `LangDropdown` — essentially the current B1 with a whitespace-first variant of `DishCard` (image shrunk to thumbnail or suppressed; more breathing room). MinimalLayout does not render `menu.cover_image_url`.
  - **GridLayout**: hero cover image at top (from `menu.cover_image_url`); dish grid 2 cols on mobile, 3 cols on `md`+. Reuses MenuHeader / SearchBar / FilterDrawer / LangDropdown. New `GridDishCard.svelte` (photo-card: image dominant, name + price + badges below). Category sections still sticky nav. Grid falls back to a placeholder cover block (brand-primary bg with store initial) when `cover_image_url` is null.
- **Merchant app (`frontend/merchant/`)**:
  - Extend `store_management_screen.dart`: the logo slot becomes tappable → opens `image_picker` → uploads to `store-logos/{storeId}/logo.{ext}` → updates `stores.logo_url` via the existing `StoreRepository.updateStore`. Size cap 2 MB (bucket-enforced). MIME allow list: `image/png`, `image/svg+xml` (bucket-enforced).
  - New repository `TemplateRepository` (`features/templates/data/template_repository.dart`) + `templateListProvider` returning all rows from `templates` ordered by (is_launch DESC, id).
  - New screen `select_template_screen.dart` at route `/edit/select-template/:menuId` (add to `app_router.dart`):
    - Fetches current menu (`menuByIdProvider` reuse if it exists, else a new single-fetch).
    - Top section: template cards in 2 columns. Each card shows `preview_image_url`, `name`, `description`. Launch templates (Minimal, Grid) tappable; non-launch templates disabled with "Coming soon" chip.
    - Middle section: 12-swatch primary-color picker (square 44×44 tiles in a 4×3 or 6×2 grid). Tapping a tile selects it; selection shown with a 2 px `primary` border + checkmark.
    - Save button writes `menus.template_id` + `menus.theme_overrides = {"primary_color": "#XXXXXX"}` via `MenuRepository`. "Reset to default" link clears `theme_overrides` to `{}`.
    - Localized en/zh.
  - Menu-manage screen entry point: add an "Appearance" row in menu settings (wherever the existing menu-level actions live, e.g. right after "Publish") that navigates to `/edit/select-template/<menuId>`.
- **Tests**:
  - Backend: after `supabase db reset` the 5 templates and the default `template_id='minimal'` on the seeded menu are verifiable via `psql`.
  - Customer: two new Playwright e2e tests under `tests/e2e/templates.spec.ts`: `flip template to grid, assert grid layout renders`, and `set primary_color override, assert CSS variable is injected`. Use service role admin client to flip the DB, always restore in `finally`.
  - Merchant: smoke tests for `select_template_screen.dart` (asserts 2 launch templates render, 3 placeholders render disabled) and logo-upload tap path renders picker mock. No integration tests against live Supabase storage — tested manually.
- **Documentation**: `docs/architecture.md` + `docs/decisions.md` (new ADR-019: "Template selection persisted on menus, customization via JSONB overrides"). CLAUDE.md "Active work" row updated.

**Out of scope (deferred)**

- **Bistro, Izakaya, Street template components** — awaiting designer. Rows seeded in `templates` with `is_launch = false`; merchant UI shows them as "Coming soon"; customer view falls back to MinimalLayout if `template_id` is one of these (defensive — should never happen because merchant can't select them).
- **Accent color / font / spacing / radius overrides** — `theme_overrides` JSONB allows future extension; only `primary_color` is read this sub-batch.
- **Logo cropping / resizing** — the raw file the user picks is uploaded as-is. If oversized or wrong MIME the storage bucket rejects it; merchant surfaces the error text. No in-app editor.
- **Template preview before save** — merchant sees the static preview image only; no live preview of their actual menu in the chosen template.
- **Template versioning / migrations** — if a template changes component structure, existing menus re-render against the new structure on the next request. No snapshot/lock-in.
- **Customer-side caching / CDN revalidation of template changes** — template switches are live-read on each SSR. No cache headers tuned this sub-batch.
- **Merchant analytics** — "how many merchants picked Grid vs. Minimal" not recorded this sub-batch.
- **Localized template names/descriptions in the `templates` table** — stored in English; the merchant UI overlays localized strings via the existing `.arb` files (new keys added).
- **Rate limiting on logo uploads** — relies on bucket size/MIME enforcement and normal auth/RLS.

## 2. Context

- Existing schema (`backend/supabase/migrations/20260420000001_init_schema.sql`): `stores.logo_url text NULL` and `menus.cover_image_url text NULL` already exist. No schema change required for those.
- Storage (`20260420000003_storage_buckets.sql`): `store-logos` bucket is public-read, 2 MB cap, MIME allow list `image/png,image/svg+xml`. `dish-images` bucket is public-read, 5 MB, `image/jpeg,image/png,image/webp` — unused this sub-batch but acceptable for the Grid cover image (see §3.8 for the decision to reuse `dish-images` for menu covers or add a new bucket).
- `stores` RLS Pattern 1 (owner R/W) lets merchants update `logo_url`. Anon reads `stores` via `stores_anon_read_of_published` (sub-batch 1) — covers customer-view logo access too.
- `menus` RLS Pattern 1 (owner R/W) lets merchants write `template_id` + `theme_overrides`. Pattern 2 (anon read) lets customer view fetch them.
- `fetchPublishedMenu` in `frontend/customer/src/lib/data/fetchPublishedMenu.ts` is the single SSR query point. We add `template_id`, `theme_overrides` to the select list and to the mapped `PublishedMenu` shape.
- `frontend/merchant/lib/features/store/presentation/store_management_screen.dart` already displays `stores.logoUrl` and edits `stores.name` + `stores.address`. We extend it to make the logo tappable.
- `frontend/merchant/lib/router/app_router.dart` holds go_router routes. We add `/edit/select-template/:menuId`.
- Merchant already uses `image_picker` (wired in capture flow, sub-batch 2 of the earlier merchant plan). Reuse it.
- ADR-017 pattern: Riverpod `FutureProvider` + repository + mapper. Templates follow it.
- Product decisions §5: 5 templates, Minimal + Grid launch, 12 primary colors, logo, cover (Grid only). Free tier does not unlock custom theme — the `theme_overrides.primary_color` is a Pro feature gate in the roadmap. We intentionally do NOT enforce the pro-gate this sub-batch (Session 4 adds billing); the merchant UI lets anyone set a color, matching the "pricing enforcement lands later" position from §2 of product decisions. Document this as a known gap.

## 3. Decisions

### 3.1 Schema (`20260420000006_templates_and_theme.sql`)

```sql
-- ---------- templates -----------------------------------------------------
CREATE TABLE templates (
  id                 text PRIMARY KEY,       -- slug-style: 'minimal','grid',…
  name               text NOT NULL,
  description        text,
  preview_image_url  text,                   -- relative URL under /templates/
  is_launch          boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- Seed the 5 presets. Description is English-only (merchant UI overlays i18n).
INSERT INTO templates (id, name, description, preview_image_url, is_launch) VALUES
  ('minimal', 'Minimal', 'Clean single column; whitespace-first for cafes, ramen, fast-casual.',
   '/templates/minimal.png', true),
  ('grid',    'Grid',    '2–3 column photo cards for menus with strong imagery (bubble tea, pizza).',
   '/templates/grid.png', true),
  ('bistro',  'Bistro',  'Editorial magazine feel. Coming soon.',
   '/templates/bistro.png', false),
  ('izakaya', 'Izakaya', 'Dense multi-section nightlife layout. Coming soon.',
   '/templates/izakaya.png', false),
  ('street',  'Street',  'Bold, high-contrast poster feel. Coming soon.',
   '/templates/street.png', false);

-- ---------- menus additions -----------------------------------------------
ALTER TABLE menus
  ADD COLUMN template_id      text NOT NULL DEFAULT 'minimal'
                              REFERENCES templates(id),
  ADD COLUMN theme_overrides  jsonb NOT NULL DEFAULT '{}'::jsonb;

-- ---------- RLS on templates ----------------------------------------------
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

-- Static reference table: everyone (anon + authenticated) can read.
CREATE POLICY templates_public_read ON templates FOR SELECT
  USING (true);

-- No INSERT/UPDATE/DELETE policies → only service_role can mutate, which is
-- exactly what we want for a curated reference table.

-- ---------- trigger to keep updated_at fresh on templates -----------------
CREATE TRIGGER templates_touch_updated_at BEFORE UPDATE ON templates
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

Notes:
- `template_id` is `NOT NULL DEFAULT 'minimal'` so existing rows (including the seed menu) backfill to Minimal automatically. Idempotent migration.
- `theme_overrides` default `{}` means "use brand defaults"; customer view treats an empty object and a missing `primary_color` key identically.

### 3.2 `PublishedMenu` model additions (`frontend/customer/src/lib/types/menu.ts`)

```ts
export type TemplateId = 'minimal' | 'grid' | 'bistro' | 'izakaya' | 'street';
export interface ThemeOverrides { primaryColor?: string; }

export interface PublishedMenu {
  // …existing fields…
  templateId: TemplateId;
  themeOverrides: ThemeOverrides;
}
```

Mapper (`fetchPublishedMenu.ts`) reads `template_id` and `theme_overrides` columns from the join, with defensive fallbacks (`'minimal'`, `{}`). Because the column has a `NOT NULL DEFAULT`, the null-branch is only a safety net.

### 3.3 Customer route dispatch

`[slug]/+page.svelte` replaces its direct body with:

```svelte
<script lang="ts">
  import MinimalLayout from '$lib/templates/minimal/MenuPage.svelte';
  import GridLayout from '$lib/templates/grid/MenuPage.svelte';
  let { data } = $props();
</script>

{#if data.menu.templateId === 'grid'}
  <GridLayout {data} />
{:else}
  <MinimalLayout {data} />
{/if}
```

Each `MenuPage.svelte` owns the full layout (header / search / filter / nav / dish list / lang dropdown) composed from the shared components. Most of the existing B1 body moves into `MinimalLayout` as-is (it IS the current Minimal rendering). `GridLayout` is the new one.

Why `if/else` over dynamic import: we have 2 launch templates. `if/else` is 7 lines and compiles to direct imports — faster first paint. When we add Bistro/Izakaya/Street, revisit (ADR-020 placeholder).

Bistro/Izakaya/Street defensive fallback: any unknown `templateId` renders MinimalLayout (the `{:else}` branch catches everything that isn't 'grid'). Merchant UI prevents selecting them, but data tampering is handled gracefully.

### 3.4 Primary-color CSS variable injection

Inject the override at page level (not layout). `[slug]/+page.svelte` and `[slug]/[dishId]/+page.svelte` both already have a `<svelte:head>` block with meta tags + JSON-LD. Each one adds one conditional `<style>` tag:

```svelte
<svelte:head>
  <!-- existing title, meta, og, json-ld -->
  {#if menu.themeOverrides.primaryColor}
    {@html `<style>:root{--color-primary:${menu.themeOverrides.primaryColor};}</style>`}
  {/if}
</svelte:head>
```

This avoids adding a layout-level load and keeps the override scoped to the two slug-aware routes. The layout itself stays unaware of `themeOverrides`.

The injected style targets `:root`. Tailwind v4's `@theme` declares `--color-primary` at `:root`; the runtime inline style has the same specificity and comes later in the cascade → overrides. `bg-primary` / `text-primary` / etc. utility classes everywhere else Just Work.

Color validation: the merchant UI only lets the user pick from 12 known-good hex strings, so no sanitization is needed server-side. Defensive regex in the customer mapper rejects anything that doesn't match `/^#[0-9A-Fa-f]{6}$/` and falls back to the default (skip injection) — prevents XSS via JSONB injection in case the admin ever mutates the column directly with malformed data.

### 3.5 The 12-color primary swatch

Source of truth lives in one file `frontend/merchant/lib/features/templates/primary_swatches.dart` and `frontend/customer/src/lib/templates/primarySwatches.ts` — we maintain BOTH since neither codebase imports from the other. Values must match exactly.

```ts
export const PRIMARY_SWATCHES: readonly string[] = [
  '#2F5D50',  // brand green (default)
  '#C2553F',  // brick red
  '#E0A969',  // amber
  '#1F4068',  // navy
  '#3E6B89',  // slate blue
  '#567D46',  // olive
  '#8B4B66',  // mulberry
  '#B56E2D',  // burnt orange
  '#3E3E4E',  // charcoal
  '#6B4E9E',  // purple
  '#2E8B82',  // teal
  '#6B1E2E',  // wine
];
```

Swatches chosen to (a) include the default brand primary as the first option, (b) span warm/cool/neutral, (c) maintain sufficient contrast on the brand `surface` (#FBF7F0) — validated visually during design, not algorithmically this sub-batch.

### 3.6 GridLayout specifics

- Hero cover: full-bleed on mobile, contained at `max-w-5xl mx-auto` on ≥768 px. Aspect-ratio `3:2`. Object-cover. Gradient overlay at the bottom (linear gradient from transparent to `surface`) to smooth into the page.
- When `menu.coverImageUrl` is null: render a solid block `bg-primary` at the same dimensions with the store name in big white serif type (Inter 700, `text-4xl`) centered.
- Dish grid: `grid grid-cols-2 md:grid-cols-3 gap-3` inside category sections. Each `GridDishCard`:
  - Image: full-width, aspect `1:1`, rounded `2xl`, object-cover. Placeholder when no image: brand `surface-container` (inline #E6E2DB) with a food-icon SVG.
  - Name: `text-sm font-medium text-ink`, 2-line clamp.
  - Price: small font below name.
  - Badges: inline below price, smaller (text-[10px]), single row with overflow hidden.
- Category heading: bigger than Minimal's (`text-xl font-semibold`), mb-3.
- Sticky nav + search + filter drawer unchanged across templates (reused components).

### 3.7 MinimalLayout specifics

Essentially the current B1 body. The distinction from "just use `+page.svelte`'s old code" is one tiny tweak to `DishCard` for more whitespace:

- `MinimalDishCard.svelte` (new): identical to `DishCard` but `p-4` instead of `p-3`, image only rendered when present (already), image rendered at `w-16 h-16` (smaller). Keeps a list layout.
- Category heading `text-lg font-semibold` (unchanged).

### 3.8 Menu cover image — bucket choice

`menus.cover_image_url` is already a column, but no bucket has been "blessed" for it. Option A: reuse `dish-images` (public, 5 MB, broad MIME). Option B: new `menu-covers` bucket.

**Decision: reuse `dish-images`.** Rationale: identical constraints (5 MB, JPEG/PNG/WebP, public-read, owner-scoped path) and avoiding migration sprawl. Merchant uploads cover to `dish-images/{storeId}/menu-{menuId}-cover.{ext}`. The path prefix is still `{storeId}/`, so RLS rules pass unchanged.

### 3.9 Merchant: `select_template_screen.dart`

Route: `/edit/select-template/:menuId`. Entry: a new row in the menu-manage screen's settings list (right after Publish), label `外观` / `Appearance`, icon `Icons.palette_outlined`.

State (Riverpod):
- `menuByIdProvider(menuId)` (new or existing — check `menu_manage` screen's providers; if absent, write one).
- `templateListProvider` (new).
- Local UI state: selected `templateId` + selected `primaryColor` hex (initialized from the loaded menu).

UI:
- AppBar with "外观 / Appearance" + back chevron.
- `ListView` body:
  1. Section "模板 / Template":
     - `GridView.count(crossAxisCount: 2, childAspectRatio: 3/4)` of `TemplateCard` widgets.
     - `TemplateCard`: Image (`Image.asset('assets/templates/${id}.png')` falling back to bucket URL if asset missing), name, short description, selected indicator (border + filled check). Tappable only if `is_launch`. Non-launch cards are opacity 0.4 with "Coming soon" chip.
  2. Section "主色 / Primary color":
     - Horizontal wrap of 12 `SwatchTile` widgets (44×44 rounded 12, inline box shadow). Selected tile shows a 2 px `primary` border + centered white check.
     - A "重置为默认 / Reset to default" text button clears the selection (nulls the color, showing the brand primary).
  3. Padding.
  4. Fixed-bottom bar with "保存 / Save" `FilledButton` that calls `menuRepository.updateMenu(menuId, templateId: …, themeOverrides: {'primary_color': '#…'})` (or `{}` if reset). Show `CircularProgressIndicator` inside the button during the request. On success pop. On error snackbar.

`MenuRepository.updateMenu` already exists; extend its param list with `templateId` and `themeOverrides`. The existing `menuByIdProvider` is invalidated after write so the merchant sees the updated values if they return to the screen.

### 3.10 Merchant: logo upload on `store_management_screen.dart`

The logo slot is currently a `CircleAvatar` showing `stores.logoUrl` or a default icon. Make it tappable:

```dart
GestureDetector(
  onTap: () => _pickAndUploadLogo(ref, store),
  child: CircleAvatar(…),
)
```

Flow:
1. `image_picker.pickImage(source: gallery, maxWidth: 1024, imageQuality: 90, preferredCameraDevice: …)`.
2. Upload to `Supabase.instance.client.storage.from('store-logos').upload('$storeId/logo.${file.extension}', file)` with `upsert: true`.
3. Get public URL: `publicUrl = supabase.storage.from('store-logos').getPublicUrl(path)`.
4. `storeRepository.updateStore(logoUrl: publicUrl)`.
5. Riverpod invalidates `storeProvider` → avatar refreshes.

Error handling: if the bucket rejects (too big / wrong MIME / oversized), catch and show a `SnackBar` with localized "图片太大，请选小一点的" / "Image too large, please pick a smaller one". Don't attempt image compression this sub-batch.

### 3.11 RLS summary

- `templates`: `public_read` → anon + authenticated SELECT. No writes (service_role only).
- `menus.template_id` + `menus.theme_overrides`: existing owner RW policy covers writes; existing anon-read policy covers reads. No new policies needed.
- `stores.logo_url`: existing owner RW policy covers writes; existing `stores_anon_read_of_published` policy (sub-batch 1) covers anon reads. No new policies needed.

### 3.12 Testing

**Backend:**
- After `supabase db reset`, manually verify: `SELECT COUNT(*) FROM templates` → 5; `SELECT template_id FROM menus WHERE slug='yun-jian-xiao-chu-lunch-2025'` → `'minimal'`.

**Customer (Playwright e2e):**
- New file `tests/e2e/templates.spec.ts`:
  1. `grid template renders photo-card layout` — admin flips `menus.template_id='grid'` via service_role, page.goto, assert `main` has `[class*="grid-cols"]` selector, restore in finally.
  2. `primary_color override injects CSS variable` — admin sets `theme_overrides='{"primary_color":"#C2553F"}'`, page.goto, assert computed style of `body` has `--color-primary: #C2553F` via `page.evaluate(() => getComputedStyle(document.body).getPropertyValue('--color-primary'))`, restore in finally.
- Existing `b1-happy.spec.ts` stays; it assumes Minimal (seed default), which still holds.

**Merchant (Flutter smoke):**
- `test/smoke/select_template_screen_test.dart`:
  1. Renders without throwing with a mocked `templateListProvider` returning 5 rows.
  2. Asserts Minimal + Grid are tappable (no `IgnorePointer`).
  3. Asserts Bistro/Izakaya/Street show "Coming soon" chip.
  4. Tapping a swatch updates a selected-color indicator.
- `test/smoke/store_management_screen_test.dart`: extend the existing smoke test (if any) to assert the avatar GestureDetector is wired. Do NOT test actual image picker flow — it requires platform channels.

### 3.13 `logo` / `cover` size / MIME / rejection UX

- `store-logos`: 2 MB cap, `image/png`+`image/svg+xml` only — Supabase rejects with HTTP 400 if violated. Merchant catches and shows a localized error.
- `dish-images` (reused for menu covers): 5 MB, `image/jpeg`+`image/png`+`image/webp`.
- The merchant's cover-upload UI is OUT of scope this sub-batch. The `menus.cover_image_url` column can be set via the existing parse-menu flow or via direct DB manipulation for now. Grid template renders the fallback block when null. Full cover-upload UX lands in P1 merchant polish (sub-batch 3 possibly) if the designer confirms layout — called out as a limitation.

## 4. File tree (additions only)

```
backend/supabase/migrations/20260420000006_templates_and_theme.sql          (new)

frontend/customer/
├── src/lib/templates/
│   ├── primarySwatches.ts                                                  (new)
│   ├── minimal/
│   │   ├── MenuPage.svelte                                                 (new)
│   │   └── MinimalDishCard.svelte                                          (new)
│   └── grid/
│       ├── MenuPage.svelte                                                 (new)
│       ├── GridDishCard.svelte                                             (new)
│       └── CoverHero.svelte                                                (new)
├── src/lib/types/menu.ts                                                   (modified — add TemplateId / ThemeOverrides)
├── src/lib/data/fetchPublishedMenu.ts                                      (modified — select + map new columns)
├── src/routes/[slug]/+page.svelte                                          (modified — dispatch if/else)
├── static/templates/
│   ├── minimal.png                                                         (new, placeholder)
│   └── grid.png                                                            (new, placeholder)
└── tests/e2e/templates.spec.ts                                             (new)

frontend/merchant/
├── lib/features/templates/
│   ├── data/
│   │   └── template_repository.dart                                        (new)
│   └── presentation/
│       ├── select_template_screen.dart                                     (new)
│       └── widgets/
│           ├── template_card.dart                                          (new)
│           └── swatch_tile.dart                                            (new)
├── lib/features/templates/primary_swatches.dart                            (new)
├── lib/features/store/presentation/store_management_screen.dart            (modified — tappable logo)
├── lib/features/menu/data/menu_repository.dart                             (modified — updateMenu params)
├── lib/router/app_router.dart                                              (modified — route)
├── assets/templates/                                                       (new — png placeholders)
│   ├── minimal.png
│   └── grid.png
├── pubspec.yaml                                                            (modified — register assets/templates/)
├── lib/l10n/app_en.arb                                                     (modified — new keys)
├── lib/l10n/app_zh.arb                                                     (modified — new keys)
└── test/smoke/
    └── select_template_screen_test.dart                                    (new)
```

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| The current seeded menu's `template_id` defaults to `'minimal'`, so sub-batch 1 e2e tests (`b1-happy.spec.ts`) keep passing. But if any sub-batch 1 test implicitly assumed the old B1 `+page.svelte` structure, extracting into `MinimalLayout` may shift selectors | Run full e2e suite immediately after extracting `MinimalLayout` and before adding GridLayout; fix any selector drift before moving on |
| 12 swatches are picked based on aesthetic judgment without a designer — colors may look muddy on some menus | Swatches are data; designer can replace without schema change. Document as "pending designer pass" in ADR-019 |
| `@theme` CSS variable override via runtime `<style>` tag could collide with Tailwind's generated preflight | Test: if `bg-primary` after override resolves to the new color, we're fine. If not, move the override style tag after Tailwind's `<link>` in `+layout.svelte` to raise specificity via cascade order |
| Grid template needs per-dish square images but the seed doesn't include `image_url` for most dishes | Grid fallback placeholder handles the case; visually verified during smoke; designer should use a real menu for reviewing Grid |
| Merchant logo-upload happy-path is testable but error paths (oversized, wrong MIME) depend on Supabase storage response format | Build a small `SupabaseStorageError` mapper that produces the localized message; unit-test the mapper |
| Preview image placeholders look amateur on the picker screen | Label "Designer to replace" as a code comment in `template_repository.dart`; also mention in ADR |
| `theme_overrides` might get set by direct SQL with malformed data | Customer-side `primaryColor` regex validation (§3.4) — invalid values fall back silently |
| Bistro/Izakaya/Street remain blank routes if someone sets `template_id='bistro'` via SQL | Dispatcher's `{:else}` branch catches them → renders MinimalLayout. Merchant UI can't pick them. |

## 6. Success criteria

- `cd backend/supabase && npx supabase db reset` → no errors; `SELECT COUNT(*) FROM templates` = 5; every existing menu has `template_id='minimal'`.
- `cd frontend/customer && pnpm check && pnpm test && pnpm test:e2e` → all clean including 2 new template e2e tests.
- `cd frontend/merchant && flutter analyze && flutter test` → clean including new screens.
- Manual check: merchant picks Grid + a non-default swatch + saves → customer view of the same slug shows Grid layout with the new primary color within one page refresh.
- Manual check: merchant taps logo on store-management → picks a png → uploads → the CircleAvatar re-renders with the new image; customer view header also shows the new logo.
- Bistro/Izakaya/Street show "Coming soon" in the merchant picker and are un-tappable.
- Docs: new ADR-019, `architecture.md` updated, CLAUDE.md "Active work" refreshed.
