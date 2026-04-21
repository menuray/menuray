# Launch Templates (Minimal + Grid) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship MenuRay's two launch templates (Minimal + Grid) end-to-end: new `templates` table + `menus.template_id` + `menus.theme_overrides` JSONB; customer SvelteKit renders per-template layouts with runtime primary-color override; merchant Flutter gets a new template/color picker screen plus tappable logo upload. Spec: `docs/superpowers/specs/2026-04-20-launch-templates-design.md`.

**Architecture:** Single backend migration adds the `templates` reference table and two columns to `menus`. Customer view dispatches `{#if menu.templateId === 'grid'} <GridLayout/> {:else} <MinimalLayout/> {/if}` — MinimalLayout is the existing B1 body refactored, GridLayout is new (photo-grid with hero cover). Primary-color override is a 1-line `<style>:root{--color-primary:X}</style>` injected into `<svelte:head>`, which Tailwind v4's `@theme` happily inherits at runtime. Merchant adds a `TemplateRepository`, extends `MenuRepository` with an `updateMenu` method, creates a new `select_template_screen`, and makes the store-management logo avatar tappable (first real Supabase Storage upload from Flutter).

**Tech Stack:** PostgreSQL (Supabase), SvelteKit 2 + Svelte 5 runes + Tailwind v4, Flutter 3 + Riverpod + go_router + `image_picker` + `supabase_flutter` storage.

---

## File structure

**Backend migration (1 new file):**
```
backend/supabase/migrations/20260420000006_templates_and_theme.sql
```

**Customer view (`frontend/customer/`):**
```
src/lib/templates/
├── primarySwatches.ts                          (new)
├── minimal/
│   ├── MenuPage.svelte                         (new)
│   └── MinimalDishCard.svelte                  (new)
└── grid/
    ├── MenuPage.svelte                         (new)
    ├── GridDishCard.svelte                     (new)
    └── CoverHero.svelte                        (new)

src/lib/types/menu.ts                           (modify: TemplateId, ThemeOverrides, fields)
src/lib/data/fetchPublishedMenu.ts              (modify: select + map new columns + validate hex)
src/routes/[slug]/+page.svelte                  (modify: replace body with dispatcher + style injection)
src/routes/[slug]/[dishId]/+page.svelte         (modify: add same style injection)

static/templates/
├── minimal.png                                 (new, placeholder)
└── grid.png                                    (new, placeholder)

tests/e2e/templates.spec.ts                     (new)
```

**Merchant (`frontend/merchant/`):**
```
lib/features/templates/
├── primary_swatches.dart                       (new — shared across screens)
├── data/
│   └── template_repository.dart                (new)
└── presentation/
    ├── select_template_screen.dart             (new)
    └── widgets/
        ├── template_card.dart                  (new)
        └── swatch_tile.dart                    (new)

lib/features/home/menu_repository.dart          (modify: add updateMenu method)
lib/features/home/store_repository.dart         (unchanged — updateStore already exists)
lib/features/store/presentation/store_management_screen.dart  (modify: tappable logo upload)
lib/features/manage/presentation/menu_management_screen.dart  (modify: add "Appearance" entry)
lib/router/app_router.dart                      (modify: selectTemplate route → parameterized)
lib/l10n/app_en.arb                             (modify: 15 new keys)
lib/l10n/app_zh.arb                             (modify: 15 new keys)
pubspec.yaml                                    (modify: register assets/templates/)

assets/templates/
├── minimal.png                                 (new, placeholder — copy from customer)
└── grid.png                                    (new, placeholder — copy from customer)

test/smoke/select_template_screen_smoke_test.dart                (new)
test/smoke/store_management_screen_smoke_test.dart               (modify — assert tappable logo)
```

**Docs:**
```
docs/decisions.md                               (modify — add ADR-019)
docs/architecture.md                            (modify — templates section)
CLAUDE.md                                       (modify — Active work)
README.md                                       (unchanged this sub-batch; mentioned via CLAUDE.md)
```

---

## Task 1: Backend migration — templates table + menus columns + RLS

**Files:**
- Create: `backend/supabase/migrations/20260420000006_templates_and_theme.sql`

- [ ] **Step 1: Write the migration**

```sql
-- ============================================================================
-- Templates: curated reference table selected per menu. Customization via a
-- JSONB override column on menus lets us add new dimensions (accent, font, …)
-- without another migration. See spec:
-- docs/superpowers/specs/2026-04-20-launch-templates-design.md §3.1
-- ============================================================================

-- ---------- templates ------------------------------------------------------
CREATE TABLE templates (
  id                 text PRIMARY KEY,       -- slug-style: 'minimal','grid',…
  name               text NOT NULL,
  description        text,
  preview_image_url  text,                   -- relative path under customer static/
  is_launch          boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

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
-- No INSERT/UPDATE/DELETE policies → only service_role can mutate,
-- which is exactly what we want for a curated reference table.

-- ---------- trigger to keep updated_at fresh on templates -----------------
CREATE TRIGGER templates_touch_updated_at BEFORE UPDATE ON templates
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

- [ ] **Step 2: Reset local Supabase and verify**

Run: `cd backend/supabase && npx supabase db reset`
Expected: all migrations (including `20260420000006`) + seed re-applied without error.

Verification via `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres`:

```sql
-- Expect 5 templates, 2 flagged as launch.
SELECT id, is_launch FROM templates ORDER BY id;
-- Expect: bistro f, grid t, izakaya f, minimal t, street f

-- Expect existing seeded menu defaults to minimal and empty overrides.
SELECT template_id, theme_overrides
  FROM menus WHERE slug='yun-jian-xiao-chu-lunch-2025';
-- Expect: minimal  {}

-- Expect anon can SELECT templates (RLS test).
SET ROLE anon;
SELECT COUNT(*) FROM templates;
-- Expect: 5
RESET ROLE;
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260420000006_templates_and_theme.sql
git commit -m "feat(rls): templates reference table + menus.template_id + theme_overrides

Adds a curated 5-row templates table (2 launch: minimal, grid), a
template_id FK on menus (default 'minimal'), and a JSONB
theme_overrides column for per-menu primary-color / future
dimensions. Anon SELECT on templates via public_read policy.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Customer types + swatches + `fetchPublishedMenu` mapping

**Files:**
- Modify: `frontend/customer/src/lib/types/menu.ts` (add TemplateId, ThemeOverrides, fields)
- Create: `frontend/customer/src/lib/templates/primarySwatches.ts`
- Modify: `frontend/customer/src/lib/data/fetchPublishedMenu.ts` (select + map + validate)

- [ ] **Step 1: Extend `src/lib/types/menu.ts`**

Open the existing file. BEFORE the `PublishedMenu` interface, add:

```ts
export type TemplateId = 'minimal' | 'grid' | 'bistro' | 'izakaya' | 'street';

export interface ThemeOverrides {
  primaryColor?: string;  // validated hex like '#2F5D50' (or absent)
}
```

Then INSIDE `PublishedMenu`, AFTER the `publishedAt: string;` line, add:

```ts
  templateId: TemplateId;
  themeOverrides: ThemeOverrides;
```

No other changes to the file.

- [ ] **Step 2: Create `src/lib/templates/primarySwatches.ts`**

```ts
// 12 curated primary-color swatches offered in the merchant picker.
// Values must match frontend/merchant/lib/features/templates/primary_swatches.dart
// exactly — neither codebase imports from the other.
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

const HEX_RE = /^#[0-9A-Fa-f]{6}$/;

/** Returns true iff s is a 6-digit hex color (case-insensitive, # required). */
export function isValidHex(s: unknown): s is string {
  return typeof s === 'string' && HEX_RE.test(s);
}
```

- [ ] **Step 3: Update `src/lib/data/fetchPublishedMenu.ts`**

The file currently selects menu columns and maps them. Make three edits:

**Edit A**: add imports at top (after the existing imports):

```ts
import { isValidHex } from '$lib/templates/primarySwatches';
```

**Edit B**: extend the `JoinedMenuRow` type. Find the block that lists scalar menu columns (currently ends with `cover_image_url: string | null; published_at: string;`). Add two fields at the end of that scalar block:

```ts
  template_id: string;
  theme_overrides: { primary_color?: unknown } | null;
```

**Edit C**: in `mapRow`, find the final `return { ... }` statement. Add two fields right before the closing brace (after `coverImageUrl`, `publishedAt`, `store`, `categories` — just append them):

```ts
    templateId: (row.template_id ?? 'minimal') as PublishedMenu['templateId'],
    themeOverrides: mapThemeOverrides(row.theme_overrides),
```

Then add the helper ABOVE `mapRow` (or at the bottom of the file):

```ts
function mapThemeOverrides(raw: { primary_color?: unknown } | null): PublishedMenu['themeOverrides'] {
  if (!raw || typeof raw !== 'object') return {};
  const pc = (raw as { primary_color?: unknown }).primary_color;
  if (isValidHex(pc)) return { primaryColor: pc };
  return {};
}
```

**Edit D**: in the `.select(\`…\`)` call, add `template_id, theme_overrides,` to the comma-separated menu-column list (right after `cover_image_url, published_at,` is fine).

- [ ] **Step 4: Type check**

Run: `cd /home/coder/workspaces/menuray/frontend/customer && pnpm check`
Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Run all tests — existing ones must still pass**

Run: `pnpm test`
Expected: 18/18 still green. The integration test for `fetchPublishedMenu` will still pass because the seeded menu gets `template_id='minimal'` + `theme_overrides='{}'` from the migration defaults.

- [ ] **Step 6: Commit**

```bash
git add frontend/customer/src/lib/types/menu.ts frontend/customer/src/lib/templates/primarySwatches.ts frontend/customer/src/lib/data/fetchPublishedMenu.ts
git commit -m "feat(customer): types + swatches + map template_id + theme_overrides

PublishedMenu gains templateId + themeOverrides. Mapper reads the
two new columns and validates primary_color with a hex regex
(silently drops malformed values). 12-swatch palette exposed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Extract MinimalLayout (preserving existing e2e)

**Files:**
- Create: `frontend/customer/src/lib/templates/minimal/MenuPage.svelte`
- Create: `frontend/customer/src/lib/templates/minimal/MinimalDishCard.svelte`

- [ ] **Step 1: `MinimalDishCard.svelte`** — copy of `DishCard.svelte` with padding bumped

```svelte
<script lang="ts">
  import type { Dish, Locale } from '$lib/types/menu';
  import { dishName, dishDescription } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { dish, locale, currency, href }:
    { dish: Dish; locale: Locale; currency: string; href: string } = $props();
  const name = $derived(dishName(dish, locale));
  const desc = $derived(dishDescription(dish, locale));
  const priceDisplay = $derived(formatPrice(dish.price, currency));

  function formatPrice(p: number, curr: string): string {
    try {
      return new Intl.NumberFormat(locale, { style: 'currency', currency: curr }).format(p);
    } catch {
      return `${curr} ${p.toFixed(2)}`;
    }
  }
</script>

<a
  {href}
  class="flex gap-4 p-4 rounded-2xl hover:bg-divider/30 transition-colors
         {dish.soldOut ? 'opacity-50' : ''}"
  aria-label={name}
>
  {#if dish.imageUrl}
    <img src={dish.imageUrl} alt="" class="w-16 h-16 rounded-xl object-cover bg-divider shrink-0" />
  {/if}
  <div class="flex-1 min-w-0">
    <div class="flex items-start justify-between gap-2">
      <h3 class="font-medium text-ink truncate">{name}</h3>
      <span class="font-semibold text-primary whitespace-nowrap">{priceDisplay}</span>
    </div>
    {#if desc}
      <p class="text-sm text-secondary line-clamp-2 mt-1">{desc}</p>
    {/if}
    <div class="flex flex-wrap gap-1 mt-2">
      {#if dish.isSignature}
        <span class="text-xs px-1.5 py-0.5 rounded bg-accent/20 text-accent font-medium">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-xs px-1.5 py-0.5 rounded bg-primary/10 text-primary font-medium">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-xs px-1.5 py-0.5 rounded bg-primary/10 text-primary">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-xs px-1.5 py-0.5 rounded bg-error/10 text-error">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>
  </div>
</a>
```

- [ ] **Step 2: `MinimalLayout` — `src/lib/templates/minimal/MenuPage.svelte`**

```svelte
<script lang="ts">
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import MinimalDishCard from './MinimalDishCard.svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { categoryName } from '$lib/types/menu';
  import { applyFilters, type FilterState } from '$lib/search/applyFilters';

  let { data }: { data: { menu: import('$lib/types/menu').PublishedMenu; lang: string } } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  let filters = $state<FilterState>({
    query: '',
    spice: new Set(),
    vegetarian: false,
    signature: false,
    recommended: false,
  });
  let filterOpen = $state(false);
  let activeCategoryId = $state<string | null>(null);

  const visibleCategories = $derived(applyFilters(menu.categories, filters, locale));
  const activeFilterCount = $derived(
    (filters.spice.size > 0 ? 1 : 0)
    + (filters.vegetarian ? 1 : 0)
    + (filters.signature ? 1 : 0)
    + (filters.recommended ? 1 : 0),
  );

  function scrollToCategory(id: string) {
    activeCategoryId = id;
    document.getElementById(`category-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  $effect(() => {
    if (typeof localStorage === 'undefined') return;
    const stored = localStorage.getItem('menuray.lang');
    const urlLang = page.url.searchParams.get('lang');
    if (!urlLang && stored && menu.availableLocales.includes(stored) && stored !== data.lang) {
      const url = new URL(page.url);
      url.searchParams.set('lang', stored);
      goto(url.pathname + '?' + url.searchParams.toString(), { noScroll: true, replaceState: true });
    }
  });

  $effect(() => {
    if (typeof document !== 'undefined') document.documentElement.lang = locale;
  });
</script>

<MenuHeader {menu} {locale} />

<SearchBar
  bind:value={filters.query}
  {locale}
  onFilterClick={() => (filterOpen = true)}
  {activeFilterCount}
/>

<CategoryNav
  categories={visibleCategories}
  {locale}
  activeId={activeCategoryId}
  onSelect={scrollToCategory}
/>

<main class="max-w-3xl mx-auto px-2 py-4">
  {#each visibleCategories as cat (cat.id)}
    <section id="category-{cat.id}" class="mb-8">
      <h2 class="px-2 mb-2 text-lg font-semibold text-ink">
        {categoryName(cat, locale)}
      </h2>
      <div class="flex flex-col gap-1">
        {#each cat.dishes as dish (dish.id)}
          <MinimalDishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" />
        {/each}
      </div>
    </section>
  {/each}

  {#if visibleCategories.length === 0}
    <div class="text-center py-16 text-secondary">
      <p>—</p>
    </div>
  {/if}
</main>

<FilterDrawer bind:open={filterOpen} bind:filters {locale} />
```

- [ ] **Step 3: Check**

Run: `cd /home/coder/workspaces/menuray/frontend/customer && pnpm check`
Expected: 0 errors / 0 warnings.

Do NOT run e2e yet — `[slug]/+page.svelte` is still the old single-layout version; Task 5 will switch to the dispatcher. Existing unit tests (`pnpm test`) should still pass: 18/18.

- [ ] **Step 4: Commit**

```bash
git add frontend/customer/src/lib/templates/minimal/
git commit -m "feat(customer): extract MinimalLayout as template component

MinimalLayout reproduces the current B1 body (MinimalDishCard has
slightly more whitespace than the shared DishCard — p-4 vs p-3,
image w-16 vs w-20). Dispatcher wired in Task 5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: GridLayout + children + static preview PNGs

**Files:**
- Create: `frontend/customer/src/lib/templates/grid/MenuPage.svelte`
- Create: `frontend/customer/src/lib/templates/grid/GridDishCard.svelte`
- Create: `frontend/customer/src/lib/templates/grid/CoverHero.svelte`
- Create: `frontend/customer/static/templates/minimal.png`
- Create: `frontend/customer/static/templates/grid.png`

- [ ] **Step 1: Placeholder preview PNGs**

We need two PNG files that exist on disk; content is placeholder (designer replaces later).

Option A (preferred if `convert` / ImageMagick is available):
```bash
cd /home/coder/workspaces/menuray/frontend/customer
mkdir -p static/templates
# Minimal: solid brand green 400x300 with "MINIMAL" text
convert -size 400x300 xc:'#2F5D50' -fill '#E0A969' -gravity center \
  -pointsize 48 -annotate 0 'MINIMAL' static/templates/minimal.png
# Grid: solid brand accent 400x300 with "GRID" text
convert -size 400x300 xc:'#E0A969' -fill '#2F5D50' -gravity center \
  -pointsize 48 -annotate 0 'GRID' static/templates/grid.png
```

Option B (if ImageMagick is absent): use Python PIL:
```bash
python3 -c "
from PIL import Image, ImageDraw, ImageFont
for name, bg, fg in [('minimal','#2F5D50','#E0A969'), ('grid','#E0A969','#2F5D50')]:
    img = Image.new('RGB', (400, 300), bg)
    d = ImageDraw.Draw(img)
    d.text((200, 150), name.upper(), fill=fg, anchor='mm')
    img.save(f'static/templates/{name}.png')
"
```

Option C (if both fail): create minimal 1×1 transparent PNGs:
```bash
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > static/templates/minimal.png
cp static/templates/minimal.png static/templates/grid.png
```

Verify: `ls -la static/templates/` shows both files, non-zero bytes.

- [ ] **Step 2: `CoverHero.svelte`** — renders the hero area for Grid layout

```svelte
<script lang="ts">
  import type { PublishedMenu, Locale } from '$lib/types/menu';
  import { storeName } from '$lib/types/menu';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
</script>

<div class="relative w-full max-w-5xl mx-auto aspect-[3/2] bg-primary overflow-hidden">
  {#if menu.coverImageUrl}
    <img src={menu.coverImageUrl} alt="" class="w-full h-full object-cover" />
  {:else}
    <div class="w-full h-full flex items-center justify-center">
      <h1 class="text-4xl font-bold text-surface">{name}</h1>
    </div>
  {/if}
  <div class="absolute inset-x-0 bottom-0 h-16
              bg-gradient-to-b from-transparent to-[var(--color-surface)]
              pointer-events-none"></div>
</div>
```

- [ ] **Step 3: `GridDishCard.svelte`** — photo-led card for Grid layout

```svelte
<script lang="ts">
  import type { Dish, Locale } from '$lib/types/menu';
  import { dishName } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { dish, locale, currency, href }:
    { dish: Dish; locale: Locale; currency: string; href: string } = $props();
  const name = $derived(dishName(dish, locale));
  const priceDisplay = $derived(formatPrice(dish.price, currency));

  function formatPrice(p: number, curr: string): string {
    try {
      return new Intl.NumberFormat(locale, { style: 'currency', currency: curr }).format(p);
    } catch {
      return `${curr} ${p.toFixed(2)}`;
    }
  }
</script>

<a
  {href}
  class="flex flex-col gap-1.5 rounded-2xl overflow-hidden transition-transform hover:-translate-y-0.5
         {dish.soldOut ? 'opacity-50' : ''}"
  aria-label={name}
>
  <div class="w-full aspect-square rounded-2xl overflow-hidden bg-[#E6E2DB]">
    {#if dish.imageUrl}
      <img src={dish.imageUrl} alt="" class="w-full h-full object-cover" />
    {:else}
      <div class="w-full h-full flex items-center justify-center text-secondary">
        <!-- simple food icon placeholder -->
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M3 13h18v2a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4v-2Zm2-2a7 7 0 0 1 14 0H5Z"
                stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </div>
    {/if}
  </div>
  <div class="px-0.5">
    <div class="flex items-baseline justify-between gap-1">
      <h3 class="text-sm font-medium text-ink line-clamp-2">{name}</h3>
    </div>
    <p class="text-sm font-semibold text-primary mt-0.5">{priceDisplay}</p>
    <div class="flex gap-1 mt-1 flex-nowrap overflow-hidden">
      {#if dish.isSignature}
        <span class="text-[10px] px-1 py-0.5 rounded bg-accent/20 text-accent font-medium whitespace-nowrap">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-[10px] px-1 py-0.5 rounded bg-primary/10 text-primary font-medium whitespace-nowrap">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-[10px] px-1 py-0.5 rounded bg-primary/10 text-primary whitespace-nowrap">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-[10px] px-1 py-0.5 rounded bg-error/10 text-error whitespace-nowrap">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>
  </div>
</a>
```

- [ ] **Step 4: `GridLayout` — `src/lib/templates/grid/MenuPage.svelte`**

```svelte
<script lang="ts">
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import CoverHero from './CoverHero.svelte';
  import GridDishCard from './GridDishCard.svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { categoryName } from '$lib/types/menu';
  import { applyFilters, type FilterState } from '$lib/search/applyFilters';

  let { data }: { data: { menu: import('$lib/types/menu').PublishedMenu; lang: string } } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  let filters = $state<FilterState>({
    query: '',
    spice: new Set(),
    vegetarian: false,
    signature: false,
    recommended: false,
  });
  let filterOpen = $state(false);
  let activeCategoryId = $state<string | null>(null);

  const visibleCategories = $derived(applyFilters(menu.categories, filters, locale));
  const activeFilterCount = $derived(
    (filters.spice.size > 0 ? 1 : 0)
    + (filters.vegetarian ? 1 : 0)
    + (filters.signature ? 1 : 0)
    + (filters.recommended ? 1 : 0),
  );

  function scrollToCategory(id: string) {
    activeCategoryId = id;
    document.getElementById(`category-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  $effect(() => {
    if (typeof localStorage === 'undefined') return;
    const stored = localStorage.getItem('menuray.lang');
    const urlLang = page.url.searchParams.get('lang');
    if (!urlLang && stored && menu.availableLocales.includes(stored) && stored !== data.lang) {
      const url = new URL(page.url);
      url.searchParams.set('lang', stored);
      goto(url.pathname + '?' + url.searchParams.toString(), { noScroll: true, replaceState: true });
    }
  });

  $effect(() => {
    if (typeof document !== 'undefined') document.documentElement.lang = locale;
  });
</script>

<CoverHero {menu} {locale} />
<MenuHeader {menu} {locale} />

<SearchBar
  bind:value={filters.query}
  {locale}
  onFilterClick={() => (filterOpen = true)}
  {activeFilterCount}
/>

<CategoryNav
  categories={visibleCategories}
  {locale}
  activeId={activeCategoryId}
  onSelect={scrollToCategory}
/>

<main class="max-w-5xl mx-auto px-3 py-4">
  {#each visibleCategories as cat (cat.id)}
    <section id="category-{cat.id}" class="mb-10">
      <h2 class="px-1 mb-3 text-xl font-semibold text-ink">
        {categoryName(cat, locale)}
      </h2>
      <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
        {#each cat.dishes as dish (dish.id)}
          <GridDishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" />
        {/each}
      </div>
    </section>
  {/each}

  {#if visibleCategories.length === 0}
    <div class="text-center py-16 text-secondary">
      <p>—</p>
    </div>
  {/if}
</main>

<FilterDrawer bind:open={filterOpen} bind:filters {locale} />
```

- [ ] **Step 5: Check**

Run: `cd /home/coder/workspaces/menuray/frontend/customer && pnpm check`
Expected: 0 errors / 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add frontend/customer/src/lib/templates/grid/ frontend/customer/static/templates/
git commit -m "feat(customer): grid template — cover hero + photo dish cards

GridLayout adds a 3:2 hero cover (or brand-primary fallback block
with store initial) plus a 2/3-column photo grid. Placeholder
preview PNGs committed — designer replaces later.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Dispatcher in `[slug]/+page.svelte` + primary-color injection (B1 + B2)

**Files:**
- Modify: `frontend/customer/src/routes/[slug]/+page.svelte`
- Modify: `frontend/customer/src/routes/[slug]/[dishId]/+page.svelte`

- [ ] **Step 1: Replace `[slug]/+page.svelte` with the dispatcher**

The file currently contains the inline Minimal-style body. Replace it WHOLESALE with:

```svelte
<script lang="ts">
  import type { PageData } from './$types';
  import MinimalLayout from '$lib/templates/minimal/MenuPage.svelte';
  import GridLayout from '$lib/templates/grid/MenuPage.svelte';
  import { storeName } from '$lib/types/menu';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  const title = $derived(`${storeName(menu.store, locale)} — ${menu.name} | MenuRay`);
  const description = $derived(
    `${menu.categories.length} categories, ${menu.categories.reduce((n, c) => n + c.dishes.length, 0)} dishes`,
  );
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />
  {#if menu.coverImageUrl}
    <meta property="og:image" content={menu.coverImageUrl} />
  {/if}
  <meta property="og:title" content={title} />
  <meta property="og:locale" content={locale} />
  {@html `<script type="application/ld+json">${JSON.stringify(data.jsonLd)}</` + `script>`}
  {#if menu.themeOverrides.primaryColor}
    {@html `<style>:root{--color-primary:${menu.themeOverrides.primaryColor};}</style>`}
  {/if}
</svelte:head>

{#if menu.templateId === 'grid'}
  <GridLayout {data} />
{:else}
  <MinimalLayout {data} />
{/if}
```

Key changes vs the previous B1 version:
- All body markup moved out into the template components (Task 3 + 4).
- `<svelte:head>` retains all SEO + JSON-LD and adds the primary-color injection.
- The Search/Filter/Lang state now lives inside the template components, not here.

- [ ] **Step 2: Add primary-color injection to `[slug]/[dishId]/+page.svelte` (B2)**

Find the `<svelte:head>` block in B2. It currently has title / description / og:image / og:title / og:locale. Add ONE more conditional block INSIDE the `<svelte:head>`:

```svelte
  {#if menu.themeOverrides.primaryColor}
    {@html `<style>:root{--color-primary:${menu.themeOverrides.primaryColor};}</style>`}
  {/if}
```

This makes B2's back button / price / badges reflect the chosen primary color too.

- [ ] **Step 3: Check + test**

Run: `cd /home/coder/workspaces/menuray/frontend/customer && pnpm check`
Expected: 0 errors / 0 warnings.

Run: `pnpm test`
Expected: 18/18 still green.

Run: `pnpm test:e2e`
Expected: 5/5 still green (the existing e2e uses the default Minimal-seeded menu; routing should be transparent — dispatcher picks Minimal by default).

Troubleshooting:
- If `pnpm test:e2e` fails on b1-happy because dish-card selectors changed (`main a[aria-label]` still works because MinimalDishCard keeps the `<a aria-label={name}>` envelope — this should be fine), inspect the diff. If the HTML structure changed in a way that breaks selectors, either (a) restore the exact selector in MinimalDishCard or (b) adjust the test. Prefer (a) to keep the test stable.

- [ ] **Step 4: Commit**

```bash
git add frontend/customer/src/routes/\[slug\]/
git commit -m "feat(customer): dispatch template + primary-color override injection

[slug]/+page.svelte is now a 15-line dispatcher picking between
MinimalLayout and GridLayout. Both slug routes emit a
<style>:root{--color-primary:X}</style> when theme_overrides sets
a primary color. Existing e2e remains green (default template is
minimal).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Playwright e2e for templates + primary-color

**Files:**
- Create: `frontend/customer/tests/e2e/templates.spec.ts`

- [ ] **Step 1: Write the tests**

```ts
import { test, expect } from '@playwright/test';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

function admin(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
}

async function resetMenu(client: SupabaseClient) {
  // Restore default state so subsequent tests (and manual dev) see Minimal + no overrides.
  await client.from('menus').update({ template_id: 'minimal', theme_overrides: {} }).eq('slug', SLUG);
}

test('grid template renders photo-card layout', async ({ page }) => {
  const a = admin();
  try {
    const { error } = await a.from('menus').update({ template_id: 'grid' }).eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // Grid layout puts dish cards inside a CSS grid. Assert the class is present.
    const gridSection = page.locator('main div[class*="grid-cols"]').first();
    await expect(gridSection).toBeVisible();

    // Page still shows the menu title.
    await expect(page.getByText('午市套餐 2025 春')).toBeVisible();
  } finally {
    await resetMenu(a);
  }
});

test('primary_color override injects CSS variable', async ({ page }) => {
  const a = admin();
  const OVERRIDE = '#C2553F';
  try {
    const { error } = await a
      .from('menus')
      .update({ theme_overrides: { primary_color: OVERRIDE } })
      .eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // The injected <style> sets :root{--color-primary:#...} — read it from computed styles.
    const value = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim(),
    );
    expect(value.toLowerCase()).toBe(OVERRIDE.toLowerCase());
  } finally {
    await resetMenu(a);
  }
});

test('invalid primary_color is silently ignored', async ({ page }) => {
  const a = admin();
  try {
    const { error } = await a
      .from('menus')
      .update({ theme_overrides: { primary_color: 'not-a-hex' } })
      .eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // Should fall back to the Tailwind @theme default.
    const value = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim(),
    );
    // Default is #2F5D50 (case-insensitive). Do not fail on whitespace / hex case.
    expect(value.toLowerCase()).toBe('#2f5d50');
  } finally {
    await resetMenu(a);
  }
});
```

- [ ] **Step 2: Run the e2e suite**

Run: `cd /home/coder/workspaces/menuray/frontend/customer && pnpm test:e2e`
Expected: 8/8 tests pass (5 existing + 3 new). First run may take longer due to `pnpm build` + preview boot.

Troubleshooting:
- If the grid-selector test fails with "no element matches `div[class*='grid-cols']`", inspect what `GridLayout` renders — it may have emitted `grid-cols-2 md:grid-cols-3` as separate attributes. Tailwind's compiled output should include `grid-cols-2` literally. If needed, relax selector to `main section .grid` or similar.
- If the override test shows an empty string from `getPropertyValue`, the `<style>` tag may not be applying. Check the page HTML via `page.content()` to confirm the style tag is present.

- [ ] **Step 3: Verify all tests + check still clean**

Run: `pnpm test` → 18/18. Run: `pnpm check` → 0/0.

- [ ] **Step 4: Commit**

```bash
git add frontend/customer/tests/e2e/templates.spec.ts
git commit -m "test(customer): playwright e2e for grid template + primary-color override

Three scenarios: grid renders grid-cols, valid primary_color hex
updates --color-primary on :root, malformed hex is silently
ignored. Each test flips the DB via service_role and restores in
finally.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Merchant data layer — swatches + TemplateRepository + MenuRepository.updateMenu

**Files:**
- Create: `frontend/merchant/lib/features/templates/primary_swatches.dart`
- Create: `frontend/merchant/lib/features/templates/data/template_repository.dart`
- Modify: `frontend/merchant/lib/features/home/menu_repository.dart` (add `updateMenu`)

- [ ] **Step 1: `primary_swatches.dart`**

```dart
import 'package:flutter/material.dart';

/// 12 curated primary-color swatches offered in the select_template screen.
/// Must match frontend/customer/src/lib/templates/primarySwatches.ts exactly.
const List<String> kPrimarySwatchHex = <String>[
  '#2F5D50', // brand green (default)
  '#C2553F', // brick red
  '#E0A969', // amber
  '#1F4068', // navy
  '#3E6B89', // slate blue
  '#567D46', // olive
  '#8B4B66', // mulberry
  '#B56E2D', // burnt orange
  '#3E3E4E', // charcoal
  '#6B4E9E', // purple
  '#2E8B82', // teal
  '#6B1E2E', // wine
];

final List<Color> kPrimarySwatchColors = kPrimarySwatchHex.map(parseHexColor).toList(growable: false);

/// Parses a '#RRGGBB' hex string. Returns opaque black on malformed input.
Color parseHexColor(String hex) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (match == null) return const Color(0xFF000000);
  return Color(int.parse('FF${match.group(1)}', radix: 16));
}
```

- [ ] **Step 2: `Template` model + `TemplateRepository`**

```dart
// frontend/merchant/lib/features/templates/data/template_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Template {
  final String id;
  final String name;
  final String description;
  final String? previewImageUrl;
  final bool isLaunch;

  const Template({
    required this.id,
    required this.name,
    required this.description,
    required this.previewImageUrl,
    required this.isLaunch,
  });

  factory Template.fromRow(Map<String, dynamic> row) => Template(
        id: row['id'] as String,
        name: row['name'] as String,
        description: (row['description'] as String?) ?? '',
        previewImageUrl: row['preview_image_url'] as String?,
        isLaunch: row['is_launch'] as bool,
      );
}

class TemplateRepository {
  TemplateRepository(this._client);
  final SupabaseClient _client;

  Future<List<Template>> list() async {
    final rows = await _client
        .from('templates')
        .select('id, name, description, preview_image_url, is_launch')
        .order('is_launch', ascending: false)
        .order('id', ascending: true);
    return (rows as List)
        .map((r) => Template.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(Supabase.instance.client);
});

final templateListProvider = FutureProvider<List<Template>>((ref) async {
  return ref.read(templateRepositoryProvider).list();
});
```

- [ ] **Step 3: Add `updateMenu` to `MenuRepository`**

Open `frontend/merchant/lib/features/home/menu_repository.dart`. Find the existing class body (it has `setDishSoldOut`, `reorderDishes` etc.). Add this method inside the class (place it near the other mutation methods):

```dart
  /// Partial update on a menu row. Any null-valued arg is skipped.
  ///
  /// Used by select_template_screen to write template_id + theme_overrides
  /// in one call. Extend with more params as other settings screens need them.
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
  }) async {
    final patch = <String, dynamic>{};
    if (templateId != null) patch['template_id'] = templateId;
    if (themeOverrides != null) patch['theme_overrides'] = themeOverrides;
    if (patch.isEmpty) return;
    await _client.from('menus').update(patch).eq('id', menuId);
  }
```

If the file does not import `Map` and the class already has a `_client` field, this should compile cleanly. If not, check what supabase client property name the class uses (it might be `client` without underscore, or injected differently) and match the existing convention.

- [ ] **Step 4: Analyze + test**

Run: `cd /home/coder/workspaces/menuray/frontend/merchant && flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: existing tests all pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/merchant/lib/features/templates/ frontend/merchant/lib/features/home/menu_repository.dart
git commit -m "feat(templates): flutter data layer — swatches, TemplateRepository, updateMenu

- primary_swatches.dart mirrors the customer view's 12-hex list
- TemplateRepository + templateListProvider fetch the 5 rows
- MenuRepository.updateMenu accepts templateId + themeOverrides

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Merchant select_template_screen + widgets + router + menu-manage entry + i18n

**Files:**
- Create: `frontend/merchant/lib/features/templates/presentation/select_template_screen.dart`
- Create: `frontend/merchant/lib/features/templates/presentation/widgets/template_card.dart`
- Create: `frontend/merchant/lib/features/templates/presentation/widgets/swatch_tile.dart`
- Modify: `frontend/merchant/lib/router/app_router.dart` (selectTemplate route → parameterized)
- Modify: `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart` (add entry row)
- Modify: `frontend/merchant/lib/l10n/app_en.arb` + `app_zh.arb` (15 new keys)
- Modify: `frontend/merchant/pubspec.yaml` (register `assets/templates/` if not already)
- Create: `frontend/merchant/assets/templates/minimal.png` + `grid.png` (copy from customer)

- [ ] **Step 1: Copy placeholder PNGs into merchant assets**

```bash
mkdir -p /home/coder/workspaces/menuray/frontend/merchant/assets/templates
cp /home/coder/workspaces/menuray/frontend/customer/static/templates/minimal.png \
   /home/coder/workspaces/menuray/frontend/merchant/assets/templates/minimal.png
cp /home/coder/workspaces/menuray/frontend/customer/static/templates/grid.png \
   /home/coder/workspaces/menuray/frontend/merchant/assets/templates/grid.png
```

Verify: `ls -la frontend/merchant/assets/templates/` shows both.

- [ ] **Step 2: Register the asset folder in `pubspec.yaml`**

Open `frontend/merchant/pubspec.yaml`. Find the `flutter:` section that lists `assets:`. Add (if not already present):

```yaml
  assets:
    - assets/templates/
```

Keep any existing entries above/below untouched.

- [ ] **Step 3: `template_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:menuray/features/templates/data/template_repository.dart';
import 'package:menuray/theme/app_colors.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.isSelected,
    required this.onTap,
    required this.comingSoonLabel,
  });

  final Template template;
  final bool isSelected;
  final VoidCallback? onTap;
  final String comingSoonLabel;

  @override
  Widget build(BuildContext context) {
    final bool disabled = !template.isLaunch;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.asset(
                    'assets/templates/${template.id}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.divider),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (disabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              comingSoonLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `swatch_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:menuray/features/templates/primary_swatches.dart';
import 'package:menuray/theme/app_colors.dart';

class SwatchTile extends StatelessWidget {
  const SwatchTile({
    super.key,
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(hex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
```

- [ ] **Step 5: Add i18n keys to `app_en.arb` and `app_zh.arb`**

Open `frontend/merchant/lib/l10n/app_en.arb`. Add (keep existing formatting; paste at an alphabetical-ish position or at the end before the final `}`):

```json
  "appearanceTitle": "Appearance",
  "@appearanceTitle": { "description": "Select template screen AppBar title" },
  "templateSectionTitle": "Template",
  "colorSectionTitle": "Primary color",
  "comingSoon": "Coming soon",
  "resetToDefault": "Reset to default",
  "appearanceSave": "Save",
  "appearanceSaveSuccess": "Appearance saved",
  "appearanceSaveFailed": "Save failed",
  "menuManageAppearance": "Appearance",
  "@menuManageAppearance": { "description": "Entry row in menu manage screen" },
  "logoTapHint": "Tap to change logo",
  "logoUploadInProgress": "Uploading logo…",
  "logoUploadSuccess": "Logo updated",
  "logoUploadFailed": "Logo upload failed",
  "logoUploadTooLarge": "Logo must be under 2 MB",
  "logoUploadBadFormat": "Logo must be PNG or SVG",
```

In `app_zh.arb`, add the matching keys:

```json
  "appearanceTitle": "外观",
  "templateSectionTitle": "模板",
  "colorSectionTitle": "主色",
  "comingSoon": "即将推出",
  "resetToDefault": "重置为默认",
  "appearanceSave": "保存",
  "appearanceSaveSuccess": "外观已保存",
  "appearanceSaveFailed": "保存失败",
  "menuManageAppearance": "外观",
  "logoTapHint": "点击更换 Logo",
  "logoUploadInProgress": "Logo 上传中…",
  "logoUploadSuccess": "Logo 已更新",
  "logoUploadFailed": "Logo 上传失败",
  "logoUploadTooLarge": "Logo 不能超过 2 MB",
  "logoUploadBadFormat": "Logo 仅支持 PNG 或 SVG 格式",
```

Run: `cd frontend/merchant && flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` regenerated, no errors. The new keys become `AppLocalizations.of(context)!.appearanceTitle` etc.

- [ ] **Step 6: `select_template_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:menuray/features/home/menu_repository.dart';
import 'package:menuray/features/templates/data/template_repository.dart';
import 'package:menuray/features/templates/primary_swatches.dart';
import 'package:menuray/features/templates/presentation/widgets/swatch_tile.dart';
import 'package:menuray/features/templates/presentation/widgets/template_card.dart';
import 'package:menuray/l10n/app_localizations.dart';
import 'package:menuray/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectTemplateScreen extends ConsumerStatefulWidget {
  const SelectTemplateScreen({super.key, required this.menuId});
  final String menuId;

  @override
  ConsumerState<SelectTemplateScreen> createState() => _SelectTemplateScreenState();
}

class _SelectTemplateScreenState extends ConsumerState<SelectTemplateScreen> {
  String _templateId = 'minimal';
  String? _primaryColor;  // null = reset/default
  bool _saving = false;
  bool _initialized = false;

  Future<void> _loadInitial() async {
    if (_initialized) return;
    _initialized = true;
    final supabase = Supabase.instance.client;
    final row = await supabase
        .from('menus')
        .select('template_id, theme_overrides')
        .eq('id', widget.menuId)
        .maybeSingle();
    if (row == null || !mounted) return;
    final templateId = (row['template_id'] as String?) ?? 'minimal';
    final overrides = row['theme_overrides'] as Map<String, dynamic>?;
    final pc = overrides?['primary_color'] as String?;
    setState(() {
      _templateId = templateId;
      _primaryColor = pc;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ref.read(menuRepositoryProvider).updateMenu(
            menuId: widget.menuId,
            templateId: _templateId,
            themeOverrides: _primaryColor == null ? <String, dynamic>{} : {'primary_color': _primaryColor},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.appearanceSaveSuccess)));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.appearanceSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final templatesAsync = ref.watch(templateListProvider);

    // Kick off initial load once the screen is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());

    return Scaffold(
      appBar: AppBar(title: Text(l.appearanceTitle)),
      body: templatesAsync.when(
        data: (templates) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.templateSectionTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 3 / 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: templates
                  .map((t) => TemplateCard(
                        template: t,
                        isSelected: _templateId == t.id,
                        onTap: () => setState(() => _templateId = t.id),
                        comingSoonLabel: l.comingSoon,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            Text(l.colorSectionTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kPrimarySwatchHex
                  .map((hex) => SwatchTile(
                        hex: hex,
                        isSelected: _primaryColor?.toLowerCase() == hex.toLowerCase(),
                        onTap: () => setState(() => _primaryColor = hex),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _primaryColor == null ? null : () => setState(() => _primaryColor = null),
                child: Text(l.resetToDefault),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.appearanceSave),
            ),
            const SizedBox(height: 24),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.appearanceSaveFailed)),
      ),
    );
  }
}
```

- [ ] **Step 7: Update `app_router.dart`**

Find `AppRoutes.selectTemplate`. Replace the static constant and the corresponding `GoRoute` with:

```dart
  static const selectTemplate = '/publish/template';
  static String selectTemplateFor(String menuId) => '/publish/template/$menuId';
```

And update the GoRoute definition for this path:

```dart
GoRoute(
  path: '${AppRoutes.selectTemplate}/:menuId',
  builder: (context, state) =>
      SelectTemplateScreen(menuId: state.pathParameters['menuId']!),
),
```

Add the import at the top:

```dart
import 'package:menuray/features/templates/presentation/select_template_screen.dart';
```

If an existing `GoRoute` uses the `selectTemplate` constant WITHOUT the `:menuId` parameter (e.g. a placeholder screen), replace it. If the placeholder screen is referenced elsewhere in the codebase, remove those references or inform the user — most likely this is dead placeholder code from earlier scaffolding.

If there's any lingering reference to the old no-arg `AppRoutes.selectTemplate` path, update it to call `AppRoutes.selectTemplateFor(menuId)` with the appropriate menu id context — the only caller we add is from `menu_management_screen.dart` in the next step.

- [ ] **Step 8: Add the "Appearance" entry in `menu_management_screen.dart`**

Open `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart`. Find where existing section rows / quick actions are built (there's a `_QuickActionsRow` and `_SectionHeader` pattern per context). The simplest place to add is BELOW the main `Column`'s existing children — add a new row that navigates to `SelectTemplateScreen`:

The exact insertion is a judgment call based on the file's structure. The row should:
- Use the same widget/pattern as existing navigation rows (look for ListTile or Ink well over an icon + label).
- Label: `l.menuManageAppearance` (EN: "Appearance", ZH: "外观"), icon: `Icons.palette_outlined`.
- On tap: `context.push(AppRoutes.selectTemplateFor(widget.menuId))`.

If the existing file uses `ListTile` pattern:

```dart
ListTile(
  leading: const Icon(Icons.palette_outlined, color: AppColors.primary),
  title: Text(AppLocalizations.of(context)!.menuManageAppearance),
  trailing: const Icon(Icons.chevron_right, color: AppColors.secondary),
  onTap: () => context.push(AppRoutes.selectTemplateFor(widget.menuId)),
),
```

Insert this after the "Publish" row (or near the end of the settings list — whichever matches the existing structure).

Imports to add at the top of that file if not already present:

```dart
import 'package:go_router/go_router.dart';
import 'package:menuray/router/app_router.dart';
```

- [ ] **Step 9: Analyze + test**

Run: `cd frontend/merchant && flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: existing tests all still pass (new smoke test comes in Task 10).

- [ ] **Step 10: Commit**

```bash
git add frontend/merchant/lib/features/templates/ \
        frontend/merchant/lib/router/app_router.dart \
        frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart \
        frontend/merchant/lib/l10n/ \
        frontend/merchant/assets/templates/ \
        frontend/merchant/pubspec.yaml
git commit -m "feat(templates): SelectTemplateScreen — picker UI + swatches + route

New /publish/template/:menuId route. Shows 2 launch templates
tappable and 3 placeholders as 'Coming soon'. 12-swatch primary
color picker with reset. Save writes template_id + theme_overrides
via MenuRepository.updateMenu. Menu-manage gains an Appearance
entry. 15 new en/zh strings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Merchant tappable logo + Supabase storage upload

**Files:**
- Modify: `frontend/merchant/lib/features/store/presentation/store_management_screen.dart`

- [ ] **Step 1: Make the logo `CircleAvatar` tappable and implement upload**

Open the file. Find the `CircleAvatar` that renders `stores.logoUrl`. Wrap it in a `GestureDetector` (or convert to an `InkWell` if the avatar is inside a Material) and add an upload handler.

Snippet (adapt to the file's existing structure — it uses a stateful widget already per context):

```dart
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// … existing imports …

// Inside the state class, near other methods:
Future<void> _pickAndUploadLogo(Store store) async {
  final l = AppLocalizations.of(context)!;
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 90,
  );
  if (file == null || !mounted) return;

  final ext = p.extension(file.name).toLowerCase().replaceFirst('.', '');
  if (ext != 'png' && ext != 'svg') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.logoUploadBadFormat)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l.logoUploadInProgress), duration: const Duration(seconds: 3)),
  );

  final supabase = Supabase.instance.client;
  final path = '${store.id}/logo.$ext';
  try {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await supabase.storage.from('store-logos').uploadBinary(
            path, bytes,
            fileOptions: const FileOptions(upsert: true, contentType: null),
          );
    } else {
      await supabase.storage.from('store-logos').upload(
            path, File(file.path),
            fileOptions: const FileOptions(upsert: true, contentType: null),
          );
    }
    final publicUrl = supabase.storage.from('store-logos').getPublicUrl(path);
    // Cache-bust so the UI reflects the new image immediately.
    final cacheBusted = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    await ref.read(storeRepositoryProvider).updateStore(
          storeId: store.id, name: store.name,
          address: store.address, logoUrl: cacheBusted,
        );
    ref.invalidate(currentStoreProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.logoUploadSuccess)));
  } on StorageException catch (e) {
    if (!mounted) return;
    final msg = e.statusCode == '413'
        ? l.logoUploadTooLarge
        : e.statusCode == '415'
            ? l.logoUploadBadFormat
            : l.logoUploadFailed;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.logoUploadFailed)));
  }
}
```

Then wrap the `CircleAvatar` with `GestureDetector(onTap: () => _pickAndUploadLogo(store), child: CircleAvatar(...))`. Add a `Tooltip(message: l.logoTapHint, …)` around the avatar if accessibility seems important.

Depending on what `store_management_screen.dart` already has: it already imports `AppLocalizations`, `ref`, `storeRepositoryProvider`. Confirm those imports; add the new ones (`dart:io`, `flutter/foundation.dart`, `image_picker`, `path`, `supabase_flutter`) only if not already present.

If `path` is not in `pubspec.yaml`, add it:

```yaml
dependencies:
  path: ^1.9.0
```

(If `image_picker` is not in pubspec either, add that too — it was introduced for capture flow so should already be there.)

- [ ] **Step 2: Analyze + test**

Run: `cd frontend/merchant && flutter analyze`
Expected: clean.

Run: `flutter test`
Expected: existing tests green. (Smoke test for the new tappable avatar lands in Task 10.)

- [ ] **Step 3: Commit**

```bash
git add frontend/merchant/lib/features/store/presentation/store_management_screen.dart \
        frontend/merchant/pubspec.yaml
git commit -m "feat(store): tappable logo avatar with supabase storage upload

Tap the CircleAvatar → image_picker → upload to
store-logos/{storeId}/logo.png|svg → update stores.logo_url via
StoreRepository. Supabase bucket enforces 2 MB cap + PNG/SVG MIME;
merchant surfaces localized errors for 413/415.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Merchant smoke tests

**Files:**
- Create: `frontend/merchant/test/smoke/select_template_screen_smoke_test.dart`
- Modify: `frontend/merchant/test/smoke/store_management_screen_smoke_test.dart`

- [ ] **Step 1: Write `select_template_screen_smoke_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray/features/templates/data/template_repository.dart';
import 'package:menuray/features/templates/presentation/select_template_screen.dart';
import 'package:menuray/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _templates = <Template>[
  Template(id: 'minimal', name: 'Minimal', description: 'Clean single column.',
      previewImageUrl: '/templates/minimal.png', isLaunch: true),
  Template(id: 'grid', name: 'Grid', description: 'Photo cards.',
      previewImageUrl: '/templates/grid.png', isLaunch: true),
  Template(id: 'bistro', name: 'Bistro', description: 'Coming soon.',
      previewImageUrl: null, isLaunch: false),
  Template(id: 'izakaya', name: 'Izakaya', description: 'Coming soon.',
      previewImageUrl: null, isLaunch: false),
  Template(id: 'street', name: 'Street', description: 'Coming soon.',
      previewImageUrl: null, isLaunch: false),
];

Widget _harness(Widget child) => ProviderScope(
      overrides: [
        templateListProvider.overrideWith((ref) async => _templates),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    );

void main() {
  testWidgets('renders 2 launch templates + 3 coming-soon placeholders',
      (tester) async {
    await tester.pumpWidget(_harness(const SelectTemplateScreen(menuId: 'm1')));
    await tester.pump();  // one frame for FutureProvider resolution
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Bistro'), findsOneWidget);
    // "即将推出" is ZH for "Coming soon"; the test harness locale is zh.
    expect(find.text('即将推出'), findsNWidgets(3));
  });

  testWidgets('tapping a swatch updates selection indicator', (tester) async {
    await tester.pumpWidget(_harness(const SelectTemplateScreen(menuId: 'm1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Each SwatchTile renders Icon(Icons.check) only when selected.
    expect(find.byIcon(Icons.check), findsNothing);

    // Tap the first swatch — first InkWell inside the second section's Wrap.
    // Easier: find the second swatch (#C2553F) by tapping the 2nd of N InkWells
    // within the section. Simpler still: tap the first positional 44x44 tile.
    final tiles = find.byType(InkWell);
    // Filter by widget size would be overkill — we just tap the first InkWell
    // whose size is 44x44. Given the page, swatches come after templates.
    await tester.tap(tiles.at(tiles.evaluate().length - 13)); // approx start of swatches
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
```

Note: the tap-selector logic in the second test is brittle. If it flakes, replace with a more robust finder — e.g. attach a `Key('swatch-#C2553F')` to each `SwatchTile` and tap via key.

If you want the safer version, extend `SwatchTile`:

```dart
// Add to SwatchTile class after const SwatchTile({...}) definition:
// Use a key based on hex so tests can target a specific swatch.
```

and in the widget: `Container(key: Key('swatch-$hex'), …)`. Then in the test: `await tester.tap(find.byKey(const Key('swatch-#C2553F')));`.

Pick whichever is simpler — we don't need swatch ordering to be test-visible beyond "the first one", so the key approach is clean. Implement whichever gets the test green.

- [ ] **Step 2: Extend `store_management_screen_smoke_test.dart`**

The existing test asserts the screen renders. Add (or insert near existing tests):

```dart
testWidgets('logo avatar is wrapped in a GestureDetector (tappable)',
    (tester) async {
  await tester.pumpWidget(/* existing harness — reuse */);
  await tester.pump();

  // Find the avatar (existing assertion probably already identifies it).
  // Assert there's a GestureDetector ancestor whose child includes a CircleAvatar.
  final gestureDetectors = find.byType(GestureDetector);
  expect(gestureDetectors, findsWidgets);

  // A stricter check: find.ancestor(of: find.byType(CircleAvatar), matching: find.byType(GestureDetector)).
  final wrapped = find.ancestor(
    of: find.byType(CircleAvatar),
    matching: find.byType(GestureDetector),
  );
  expect(wrapped, findsWidgets);
});
```

Adapt to whatever the existing file already has. Don't regress existing assertions.

- [ ] **Step 3: Analyze + test**

Run: `cd frontend/merchant && flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: all tests including the new ones pass.

- [ ] **Step 4: Commit**

```bash
git add frontend/merchant/test/smoke/
git commit -m "test(merchant): smoke tests for select_template + tappable logo

Asserts 2 launch templates tappable, 3 placeholders show coming-soon
label, swatch selection flips check icon, and logo avatar has a
GestureDetector ancestor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: ADR-019 + docs + CLAUDE.md + final verification

**Files:**
- Modify: `docs/decisions.md` (append ADR-019)
- Modify: `docs/architecture.md` (templates section)
- Modify: `CLAUDE.md` (Active work cell)

- [ ] **Step 1: Append ADR-019 to `docs/decisions.md`**

Read the file to find its existing format (ADR-001, 002, etc — same conventions). Append at the end:

```md
## ADR-019: Templates persisted per menu; customization via JSONB override

**Date:** 2026-04-20
**Status:** Accepted

### Context

The customer view needs to render different layouts per menu (Minimal vs. Grid initially, three more later). Brand-customization (primary color, logo, cover image) is also per-menu or per-store. We needed a way to persist template choice and customization without a migration every time we add a knob.

### Decision

- Add a curated `templates` reference table (`id text PK`, 5 seeded rows, 2 `is_launch=true`). Anon SELECT is public; mutations restricted to `service_role`.
- Add `menus.template_id text NOT NULL DEFAULT 'minimal' REFERENCES templates(id)`.
- Add `menus.theme_overrides jsonb NOT NULL DEFAULT '{}'`. This sub-batch only reads `{primary_color?: string}`; future fields (accent, font, radius) extend the object without migration.
- Customer view dispatches `if/else` on `template_id`; unknown values fall through to Minimal (defensive).
- Primary-color override is a `<style>:root{--color-primary:X}</style>` block injected into `<svelte:head>`. Tailwind v4's `@theme` CSS variable reads this at runtime — no rebuild.
- Invalid `primary_color` values are silently rejected by a hex regex in the customer mapper.

### Alternatives considered

- **Per-store template (not per-menu):** rejected — merchants often have separate menus (lunch, dinner, bar) that benefit from different layouts.
- **Dedicated columns per override (not JSONB):** rejected — each new knob would require a migration. JSONB's schema-on-read flexibility matches the "experimental customization" phase well.
- **Dynamic import per template:** rejected for 2 templates (YAGNI). Revisit when 3+ templates ship.

### Consequences

- The `templates` table is a deliberate constraint: merchants cannot upload custom templates. All layouts live in the customer-view codebase as Svelte components.
- Bistro/Izakaya/Street rows are seeded but `is_launch=false` — merchant UI hides them behind "Coming soon" until designer delivers.
- `primary_color` is not pro-gated this sub-batch. Session 4 (billing) will enforce the paywall; the schema + UI don't change.
- Any future layout migration (changing the Grid dish card shape, for example) re-renders all grid menus on next request — no versioning.
```

- [ ] **Step 2: Update `docs/architecture.md`**

Append (or extend existing customer-view section with) a templates subsection. Match the file's heading style.

```md
### Templates

Location: `frontend/customer/src/lib/templates/{minimal,grid}/`.

Each template exports a `MenuPage.svelte` that receives `{data}` and renders the full layout. `[slug]/+page.svelte` is a thin dispatcher — `{#if templateId === 'grid'} <GridLayout/> {:else} <MinimalLayout/> {/if}`. Shared components (MenuHeader, SearchBar, FilterDrawer, CategoryNav, LangDropdown) are reused across templates; per-template dish cards live under the template folder.

The `templates` table (migration `20260420000006`) seeds 5 rows with `is_launch` flags. Merchant shows only `is_launch=true` as selectable. Customer dispatcher's `{:else}` branch catches any unknown `templateId` and renders MinimalLayout — prevents broken state from direct SQL tampering.

Primary-color override injects a runtime `<style>:root{--color-primary:X}</style>` into `<svelte:head>`. Tailwind v4's `@theme` declares `--color-primary` at `:root`; the runtime override comes later in the cascade and wins. Values are hex-regex-validated in the SSR mapper; malformed data silently falls back to the brand default.
```

- [ ] **Step 3: Update `CLAUDE.md` Active work**

Read the file's existing "Active work" table. The ✅ Done cell should now include:

> Launch templates (Minimal + Grid) shipped: `templates` table, `menus.template_id` + `theme_overrides` JSONB, customer dispatcher at `frontend/customer/src/lib/templates/`, merchant SelectTemplateScreen + tappable logo upload on StoreManagement. RLS: `templates_public_read`.

In the 🔄 Next cell, remove sub-batch 2 references. Remaining: sub-batch 3 (merchant polish).

Keep previously completed bullets (sub-batch 1, prior sessions) intact.

- [ ] **Step 4: Run full verification trio**

```bash
# 1. Customer
cd /home/coder/workspaces/menuray/frontend/customer
pnpm check    # 0/0
pnpm test     # 18/18
pnpm test:e2e # 8/8 (5 existing + 3 new templates spec)

# 2. Merchant
cd /home/coder/workspaces/menuray/frontend/merchant
flutter analyze
flutter test
```

All five commands must pass. If any fails, fix before committing docs.

Seed sanity check: `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT template_id, theme_overrides FROM menus WHERE slug='yun-jian-xiao-chu-lunch-2025'"`. Expected: `minimal  {}`. If drifted from test runs, re-seed with `cd backend/supabase && npx supabase db reset` before committing.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions.md docs/architecture.md CLAUDE.md
git commit -m "docs: ADR-019 templates architecture + active work update

- docs/decisions.md: ADR-019 documents the templates table +
  theme_overrides JSONB approach, alternatives rejected, open
  consequences (no pro-gate this sub-batch).
- docs/architecture.md: new Templates subsection under customer view.
- CLAUDE.md: mark sub-batch 2 done in Active work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes

Every spec section has a task:

| Spec § | Task |
|---|---|
| §1 Schema migration | Task 1 |
| §1 Customer types additions | Task 2 |
| §1 fetchPublishedMenu mapping | Task 2 |
| §1 Primary-color injection | Task 5 |
| §1 MinimalLayout | Task 3 |
| §1 GridLayout (+ CoverHero + GridDishCard) | Task 4 |
| §1 Static preview images | Task 4 (customer) + Task 8 (merchant copy) |
| §1 Merchant logo upload | Task 9 |
| §1 TemplateRepository + templateListProvider | Task 7 |
| §1 MenuRepository.updateMenu extension | Task 7 |
| §1 SelectTemplateScreen + router + menu-manage entry | Task 8 |
| §1 Customer e2e + merchant smoke | Task 6 + Task 10 |
| §1 ADR-019 + architecture + CLAUDE.md | Task 11 |
| §3.1 Migration SQL | Task 1 |
| §3.2 PublishedMenu fields | Task 2 |
| §3.3 Dispatcher | Task 5 |
| §3.4 Primary-color injection | Task 5 |
| §3.5 12-swatch palette | Task 2 (TS) + Task 7 (Dart) |
| §3.6 GridLayout specifics | Task 4 |
| §3.7 MinimalLayout specifics | Task 3 |
| §3.8 Cover bucket reuse decision | No code — documented in spec; no action beyond the bucket already existing |
| §3.9 SelectTemplateScreen | Task 8 |
| §3.10 Logo upload flow | Task 9 |
| §3.11 RLS summary | Task 1 |
| §3.12 Testing | Task 6 + Task 10 |
| §3.13 Size/MIME rejection UX | Task 9 (inside upload error handling) |

No placeholders on scan. Names consistent: `updateMenu(menuId, templateId?, themeOverrides?)` in both repo (Dart) + select_template (Dart caller); `templateId` + `themeOverrides` property names match across TS model + mapper + dispatcher + merchant save call.

One expected-sharp-edge: Task 8 Step 7 asks the implementer to reuse or rename the existing `AppRoutes.selectTemplate` constant. If the existing route points to a placeholder screen that's referenced elsewhere, deleting it may break compile. The task calls this out explicitly — implementer should investigate and remove dead references or escalate.
