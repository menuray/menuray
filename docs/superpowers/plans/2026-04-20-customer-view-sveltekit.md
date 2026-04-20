# Customer View (SvelteKit) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship MenuRay's first customer-facing web app — a SvelteKit SSR site that renders any published menu at `/<slug>`, plus per-dish detail pages, search/filter, and a language switcher. All reads use the Supabase anon key. Corresponding spec: `docs/superpowers/specs/2026-04-20-customer-view-sveltekit-design.md`.

**Architecture:** New SvelteKit 2 + Svelte 5 (runes) + Tailwind v4 project at `frontend/customer/`, independent of the Flutter merchant app. Every request hits `+page.server.ts` which fetches the full menu tree via a single Supabase join and logs a `view_logs` row. All UI state (search, filter, language) is client-side; server sends the full translation payload so switching language doesn't refetch. JSON-LD (`Restaurant`, `Menu`, `MenuItem`) is emitted per page.

**Tech Stack:** SvelteKit 2 (adapter-node), Svelte 5 runes, TypeScript, Tailwind v4 (`@tailwindcss/vite`), pnpm, `@supabase/supabase-js`, Vitest (unit), Playwright (e2e).

---

## File structure

**New backend migration (1 file):**
```
backend/supabase/migrations/20260420000005_anon_stores_read.sql
```

**New SvelteKit project (single package, no workspace):**
```
frontend/customer/
├── .gitignore                              # node_modules, .svelte-kit, build, test-results
├── .nvmrc                                  # "22"
├── package.json
├── pnpm-lock.yaml                          # (generated)
├── svelte.config.js
├── vite.config.ts
├── tsconfig.json
├── playwright.config.ts
├── README.md                               # dev-quickstart
├── src/
│   ├── app.css                             # Tailwind base + brand CSS vars + @theme
│   ├── app.html                            # root HTML shell (html lang swap)
│   ├── app.d.ts                            # SvelteKit types augmentation
│   ├── hooks.server.ts                     # per-request Supabase client on locals
│   ├── lib/
│   │   ├── supabase.ts                     # createClient() factory, env defaults
│   │   ├── types/
│   │   │   └── menu.ts                     # PublishedMenu, Store, Category, Dish, Locale
│   │   ├── data/
│   │   │   ├── fetchPublishedMenu.ts       # SSR query + mapper
│   │   │   ├── fetchPublishedMenu.test.ts  # integration test against local Supabase
│   │   │   └── logView.ts                  # view_logs insert (fire-and-forget)
│   │   ├── i18n/
│   │   │   ├── resolveLocale.ts            # pure resolver
│   │   │   ├── resolveLocale.test.ts
│   │   │   └── strings.ts                  # UI strings (en/zh)
│   │   ├── search/
│   │   │   ├── applyFilters.ts             # pure search+filter
│   │   │   └── applyFilters.test.ts
│   │   ├── seo/
│   │   │   ├── jsonLd.ts                   # schema.org builder
│   │   │   └── jsonLd.test.ts
│   │   └── components/
│   │       ├── MenuHeader.svelte
│   │       ├── CategoryNav.svelte
│   │       ├── DishCard.svelte
│   │       ├── SearchBar.svelte
│   │       ├── FilterDrawer.svelte
│   │       ├── LangDropdown.svelte
│   │       ├── AllergensPills.svelte
│   │       ├── SpiceIndicator.svelte
│   │       └── MenurayBadge.svelte
│   └── routes/
│       ├── +layout.svelte                  # shell + MenurayBadge
│       ├── +error.svelte                   # 404 / 410 brand page
│       ├── +page.svelte                    # root `/` stub
│       └── [slug]/
│           ├── +page.server.ts             # B1 SSR
│           ├── +page.svelte                # B1 UI (hosts B3/B4)
│           └── [dishId]/
│               ├── +page.server.ts         # B2 SSR
│               └── +page.svelte            # B2 UI
├── static/
│   └── menuray-logo.svg
└── tests/
    └── e2e/
        ├── b1-happy.spec.ts
        └── b1-410.spec.ts
```

**Modifications elsewhere:** none. The merchant Flutter app is untouched.

---

## Task 1: Add RLS policy — anon SELECT on stores of published menus

**Files:**
- Create: `backend/supabase/migrations/20260420000005_anon_stores_read.sql`

- [ ] **Step 1: Write the migration**

```sql
-- ============================================================================
-- Customer view needs store name + logo + source_locale. Today anon has no
-- SELECT on stores (see 20260420000002_rls_policies.sql line ~95). Mirror
-- Pattern 2 from the RLS file: anon SELECT gated by an EXISTS check against
-- a published menu owned by the store.
-- ============================================================================
CREATE POLICY stores_anon_read_of_published ON stores FOR SELECT TO anon
  USING (EXISTS (
    SELECT 1 FROM menus
    WHERE menus.store_id = stores.id
      AND menus.status = 'published'
  ));
```

- [ ] **Step 2: Reset local Supabase and verify**

Run: `cd backend/supabase && npx supabase db reset`
Expected: runs all migrations and seed without error.

Then in a SQL client (e.g. `psql $(npx supabase status | grep DB | awk '{print $3}')`):
```sql
SET ROLE anon;
SELECT id, name FROM stores LIMIT 1;
```
Expected: one row (the seeded store — it has a published menu).

Then:
```sql
-- Temporarily flip the seeded menu to draft and verify stores disappear for anon.
UPDATE menus SET status = 'draft' WHERE slug = 'yun-jian-xiao-chu-lunch-2025';
RESET ROLE;
SET ROLE anon;
SELECT id FROM stores;
-- Expected: 0 rows.
-- Flip back so the seed stays usable.
RESET ROLE;
UPDATE menus SET status = 'published' WHERE slug = 'yun-jian-xiao-chu-lunch-2025';
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260420000005_anon_stores_read.sql
git commit -m "feat(rls): allow anon to read stores of published menus

Adds stores_anon_read_of_published policy. Required for SvelteKit
customer view to surface store name/logo without service_role.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Scaffold SvelteKit project skeleton

**Files:**
- Create: `frontend/customer/.gitignore`
- Create: `frontend/customer/.nvmrc`
- Create: `frontend/customer/package.json`
- Create: `frontend/customer/svelte.config.js`
- Create: `frontend/customer/vite.config.ts`
- Create: `frontend/customer/tsconfig.json`
- Create: `frontend/customer/src/app.html`
- Create: `frontend/customer/src/app.d.ts`
- Create: `frontend/customer/src/routes/+page.svelte` (temporary root placeholder)
- Create: `frontend/customer/README.md`

- [ ] **Step 1: `.gitignore`**

```gitignore
node_modules
/.svelte-kit
/build
/test-results
/playwright-report
*.log
.env
.env.*
!.env.example
```

- [ ] **Step 2: `.nvmrc`**

```
22
```

- [ ] **Step 3: `package.json`**

```json
{
  "name": "menuray-customer",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev --host --port 5173",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.0"
  },
  "devDependencies": {
    "@sveltejs/adapter-node": "^5.2.0",
    "@sveltejs/kit": "^2.8.0",
    "@sveltejs/vite-plugin-svelte": "^4.0.0",
    "@playwright/test": "^1.48.0",
    "@tailwindcss/vite": "^4.0.0-beta.4",
    "svelte": "^5.1.0",
    "svelte-check": "^4.0.0",
    "tailwindcss": "^4.0.0-beta.4",
    "typescript": "^5.6.0",
    "vite": "^5.4.0",
    "vitest": "^2.1.0"
  }
}
```

Note: if any of these version ranges aren't resolvable at install time, bump to the current published version in the same major line. Record the final versions in pnpm-lock.yaml.

- [ ] **Step 4: `svelte.config.js`**

```js
import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
  },
};
```

- [ ] **Step 5: `vite.config.ts`**

```ts
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()],
  test: {
    include: ['src/**/*.{test,spec}.{js,ts}'],
    environment: 'node',
  },
});
```

- [ ] **Step 6: `tsconfig.json`**

```json
{
  "extends": "./.svelte-kit/tsconfig.json",
  "compilerOptions": {
    "allowJs": true,
    "checkJs": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "moduleResolution": "bundler"
  }
}
```

- [ ] **Step 7: `src/app.html`**

```html
<!doctype html>
<html lang="%sveltekit.lang%">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%sveltekit.assets%/favicon.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    %sveltekit.head%
  </head>
  <body data-sveltekit-preload-data="hover">
    <div style="display: contents">%sveltekit.body%</div>
  </body>
</html>
```

- [ ] **Step 8: `src/app.d.ts`**

```ts
import type { SupabaseClient } from '@supabase/supabase-js';

declare global {
  namespace App {
    interface Locals {
      supabase: SupabaseClient;
    }
    interface PageData {
      lang?: string;
    }
    interface Error {
      code?: string;
    }
  }
}

export {};
```

- [ ] **Step 9: Placeholder root route `src/routes/+page.svelte`**

```svelte
<main class="min-h-dvh flex items-center justify-center p-8 text-center">
  <p>Visit <span class="font-semibold">menu.menuray.com/&lt;slug&gt;</span> to view a menu.</p>
</main>
```

- [ ] **Step 10: `README.md`**

```markdown
# MenuRay Customer View

SvelteKit 2 SSR app serving published menus at `/<slug>`.

## Dev

```bash
pnpm install
pnpm dev           # http://localhost:5173
```

Requires a local Supabase running on `http://127.0.0.1:54321` (see `../../backend/supabase/`).

## Scripts

- `pnpm check` — type check (must be clean before commit)
- `pnpm test` — Vitest unit tests
- `pnpm test:e2e` — Playwright e2e (requires `pnpm dev` running or `pnpm build && pnpm preview`)
- `pnpm build` — production build via adapter-node
```

- [ ] **Step 11: Install and verify the skeleton compiles**

Run: `cd frontend/customer && pnpm install`
Expected: pnpm resolves and installs; no peer-dep errors.

Run: `pnpm check`
Expected: no type errors (there's almost no code yet; checks project wiring).

Run: `pnpm dev` (in a second terminal)
Expected: server boots on `http://localhost:5173` and the placeholder page renders. Ctrl-C to stop.

- [ ] **Step 12: Commit**

```bash
git add frontend/customer/
git commit -m "feat(customer): scaffold SvelteKit 2 + Svelte 5 + Tailwind v4 skeleton

New standalone package at frontend/customer/. Adapter-node, pnpm,
Vitest + Playwright wired. Placeholder root route only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Tailwind v4 + brand theme

**Files:**
- Create: `frontend/customer/src/app.css`

- [ ] **Step 1: Write `app.css` with CSS variables + @theme**

```css
@import 'tailwindcss';

/* Brand tokens — mirrors frontend/merchant/lib/theme/app_colors.dart (DESIGN.md). */
@theme {
  --color-primary: #2F5D50;
  --color-accent: #E0A969;
  --color-surface: #FBF7F0;
  --color-ink: #1F1F1F;
  --color-secondary: #6B7B6F;
  --color-error: #C2553F;
  --color-divider: #ECE7DC;

  --font-sans:
    'Inter', 'Noto Sans SC', ui-sans-serif, system-ui, -apple-system,
    'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;

  --radius-card: 1rem;    /* 16px */
  --radius-button: 0.75rem; /* 12px */
}

html, body {
  background: var(--color-surface);
  color: var(--color-ink);
  font-family: var(--font-sans);
  -webkit-text-size-adjust: 100%;
}

/* Reserve space for the fixed MenurayBadge on Free tier so content doesn't
   sit under it. Badge is 32px + 1px top border. */
body {
  padding-bottom: 33px;
}
```

- [ ] **Step 2: Import it in the root layout (file doesn't exist yet — create minimal placeholder)**

Create `frontend/customer/src/routes/+layout.svelte`:

```svelte
<script lang="ts">
  import '../app.css';
  let { children } = $props();
</script>

{@render children()}
```

- [ ] **Step 3: Verify Tailwind v4 works end-to-end**

Update the placeholder `src/routes/+page.svelte`:

```svelte
<main class="min-h-dvh flex items-center justify-center p-8 text-center">
  <p class="text-primary text-lg">
    Visit <span class="font-semibold">menu.menuray.com/&lt;slug&gt;</span> to view a menu.
  </p>
</main>
```

Run: `pnpm dev`
Expected: placeholder text renders in brand green (`#2F5D50`). If Tailwind doesn't resolve `text-primary`, the `@theme` directive isn't wired — re-check `vite.config.ts` includes the tailwind plugin.

- [ ] **Step 4: Commit**

```bash
git add frontend/customer/src/app.css frontend/customer/src/routes/+layout.svelte frontend/customer/src/routes/+page.svelte
git commit -m "feat(customer): Tailwind v4 + MenuRay brand theme tokens

@theme directive exposes brand colors as bg-/text-/border- classes.
Root layout imports app.css.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Supabase client factory

**Files:**
- Create: `frontend/customer/src/lib/supabase.ts`
- Create: `frontend/customer/src/hooks.server.ts`

- [ ] **Step 1: `src/lib/supabase.ts`**

```ts
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

const DEV_URL = 'http://127.0.0.1:54321';
const DEV_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

export function createSupabaseClient(): SupabaseClient {
  const url = PUBLIC_SUPABASE_URL || DEV_URL;
  const key = PUBLIC_SUPABASE_ANON_KEY || DEV_ANON_KEY;
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}
```

- [ ] **Step 2: `src/hooks.server.ts`** — attach a client to `event.locals` per request

```ts
import type { Handle } from '@sveltejs/kit';
import { createSupabaseClient } from '$lib/supabase';

export const handle: Handle = async ({ event, resolve }) => {
  event.locals.supabase = createSupabaseClient();
  return resolve(event);
};
```

- [ ] **Step 3: Type check**

Run: `cd frontend/customer && pnpm check`
Expected: passes. If `$env/static/public` complains, SvelteKit hasn't been synced yet — run `pnpm exec svelte-kit sync` first.

- [ ] **Step 4: Commit**

```bash
git add frontend/customer/src/lib/supabase.ts frontend/customer/src/hooks.server.ts
git commit -m "feat(customer): supabase client factory + per-request locals

Local dev defaults baked in; prod uses PUBLIC_SUPABASE_URL + _ANON_KEY
env vars. Session persistence disabled (customer view is anon only).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: TypeScript domain model

**Files:**
- Create: `frontend/customer/src/lib/types/menu.ts`

- [ ] **Step 1: Write the types**

```ts
export type Locale = string;  // 'en' | 'zh-CN' | 'ja' | …
export type SpiceLevel = 'none' | 'mild' | 'medium' | 'hot';
export type TimeSlot = 'all_day' | 'lunch' | 'dinner' | 'seasonal';

export interface PublishedMenu {
  id: string;
  slug: string;
  name: string;
  currency: string;
  sourceLocale: Locale;
  availableLocales: Locale[];
  timeSlot: TimeSlot;
  timeSlotDescription: string | null;
  coverImageUrl: string | null;
  publishedAt: string;
  store: Store;
  categories: Category[];
}

export interface Store {
  id: string;
  logoUrl: string | null;
  sourceName: string;
  sourceAddress: string | null;
  translations: Record<Locale, { name: string; address: string | null }>;
  customBrandingOff: boolean; // always false this sub-batch
}

export interface Category {
  id: string;
  sourceName: string;
  position: number;
  translations: Record<Locale, { name: string }>;
  dishes: Dish[];
}

export interface Dish {
  id: string;
  sourceName: string;
  sourceDescription: string | null;
  price: number;
  imageUrl: string | null;
  position: number;
  spiceLevel: SpiceLevel;
  isSignature: boolean;
  isRecommended: boolean;
  isVegetarian: boolean;
  soldOut: boolean;
  allergens: string[];
  translations: Record<Locale, { name: string; description: string | null }>;
}

/** Helper: resolve the user-visible name/description for a given locale,
 *  falling back to the source fields. */
export function dishName(d: Dish, locale: Locale): string {
  return d.translations[locale]?.name ?? d.sourceName;
}
export function dishDescription(d: Dish, locale: Locale): string | null {
  return d.translations[locale]?.description ?? d.sourceDescription;
}
export function categoryName(c: Category, locale: Locale): string {
  return c.translations[locale]?.name ?? c.sourceName;
}
export function storeName(s: Store, locale: Locale): string {
  return s.translations[locale]?.name ?? s.sourceName;
}
export function storeAddress(s: Store, locale: Locale): string | null {
  return s.translations[locale]?.address ?? s.sourceAddress;
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/customer/src/lib/types/menu.ts
git commit -m "feat(customer): typescript model for PublishedMenu + locale fallback helpers

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `resolveLocale` — pure function, TDD

**Files:**
- Create: `frontend/customer/src/lib/i18n/resolveLocale.test.ts`
- Create: `frontend/customer/src/lib/i18n/resolveLocale.ts`

- [ ] **Step 1: Write the failing tests**

```ts
// src/lib/i18n/resolveLocale.test.ts
import { describe, it, expect } from 'vitest';
import { resolveLocale } from './resolveLocale';

describe('resolveLocale', () => {
  const available = ['en', 'zh-CN', 'ja'];
  const source = 'zh-CN';

  it('prefers the URL param when available', () => {
    expect(
      resolveLocale({ urlLang: 'ja', storedLang: 'en', acceptLanguage: 'fr', available, source }),
    ).toBe('ja');
  });

  it('ignores unsupported URL param and falls through', () => {
    expect(
      resolveLocale({ urlLang: 'fr', storedLang: 'en', acceptLanguage: null, available, source }),
    ).toBe('en');
  });

  it('uses storedLang when URL param is absent', () => {
    expect(
      resolveLocale({ urlLang: null, storedLang: 'ja', acceptLanguage: 'en', available, source }),
    ).toBe('ja');
  });

  it('parses Accept-Language with quality values', () => {
    expect(
      resolveLocale({
        urlLang: null, storedLang: null,
        acceptLanguage: 'fr;q=0.9,ja;q=0.8,en;q=0.7',
        available, source,
      }),
    ).toBe('ja');
  });

  it('falls back to source when nothing matches', () => {
    expect(
      resolveLocale({ urlLang: null, storedLang: null, acceptLanguage: 'fr', available, source }),
    ).toBe('zh-CN');
  });

  it('matches language-only against language-region (en → en-US not required here, exact match expected)', () => {
    expect(
      resolveLocale({ urlLang: 'en', storedLang: null, acceptLanguage: null,
                     available: ['en', 'zh-CN'], source: 'en' }),
    ).toBe('en');
  });
});
```

- [ ] **Step 2: Run test to verify they fail**

Run: `cd frontend/customer && pnpm test resolveLocale`
Expected: FAIL — "Cannot find module './resolveLocale'".

- [ ] **Step 3: Implement `resolveLocale.ts`**

```ts
import type { Locale } from '$lib/types/menu';

export interface ResolveLocaleInput {
  urlLang: string | null;
  storedLang: string | null;
  acceptLanguage: string | null;
  available: Locale[];
  source: Locale;
}

/** Precedence: URL param → localStorage → Accept-Language → source locale. */
export function resolveLocale(input: ResolveLocaleInput): Locale {
  const { urlLang, storedLang, acceptLanguage, available, source } = input;

  if (urlLang && available.includes(urlLang)) return urlLang;
  if (storedLang && available.includes(storedLang)) return storedLang;

  if (acceptLanguage) {
    const ranked = parseAcceptLanguage(acceptLanguage);
    for (const tag of ranked) {
      if (available.includes(tag)) return tag;
    }
  }

  return source;
}

function parseAcceptLanguage(header: string): string[] {
  return header
    .split(',')
    .map((piece) => {
      const [tag, ...params] = piece.trim().split(';');
      const qParam = params.find((p) => p.trim().startsWith('q='));
      const q = qParam ? parseFloat(qParam.split('=')[1]) : 1;
      return { tag: tag.trim(), q: isNaN(q) ? 0 : q };
    })
    .sort((a, b) => b.q - a.q)
    .map((r) => r.tag);
}
```

- [ ] **Step 4: Run tests**

Run: `pnpm test resolveLocale`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add frontend/customer/src/lib/i18n/
git commit -m "feat(customer): resolveLocale — URL→localStorage→Accept-Language→source

Pure function with full unit coverage. Used by both SSR load and
client-side lang switching.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: UI string table + `applyFilters` + `jsonLd`

**Files:**
- Create: `frontend/customer/src/lib/i18n/strings.ts`
- Create: `frontend/customer/src/lib/search/applyFilters.ts`
- Create: `frontend/customer/src/lib/search/applyFilters.test.ts`
- Create: `frontend/customer/src/lib/seo/jsonLd.ts`
- Create: `frontend/customer/src/lib/seo/jsonLd.test.ts`

- [ ] **Step 1: `src/lib/i18n/strings.ts`**

```ts
import type { Locale } from '$lib/types/menu';

type StringKey =
  | 'search.placeholder'
  | 'filter.label'
  | 'filter.spice'
  | 'filter.vegetarian'
  | 'filter.signature'
  | 'filter.recommended'
  | 'filter.clear'
  | 'badge.poweredBy'
  | 'back'
  | 'soldOut'
  | 'dish.signature'
  | 'dish.recommended'
  | 'dish.vegetarian'
  | 'spice.mild'
  | 'spice.medium'
  | 'spice.hot'
  | 'error.notFound.title'
  | 'error.notFound.body'
  | 'error.gone.title'
  | 'error.gone.body';

const en: Record<StringKey, string> = {
  'search.placeholder': 'Search dishes',
  'filter.label': 'Filter',
  'filter.spice': 'Spice',
  'filter.vegetarian': 'Vegetarian',
  'filter.signature': 'Signature',
  'filter.recommended': 'Recommended',
  'filter.clear': 'Clear',
  'badge.poweredBy': 'Powered by MenuRay →',
  'back': 'Back',
  'soldOut': 'Sold out',
  'dish.signature': 'Signature',
  'dish.recommended': 'Recommended',
  'dish.vegetarian': 'Vegetarian',
  'spice.mild': 'Mild',
  'spice.medium': 'Medium',
  'spice.hot': 'Hot',
  'error.notFound.title': 'Menu not found',
  'error.notFound.body': 'The menu you\u2019re looking for doesn\u2019t exist.',
  'error.gone.title': 'Menu unavailable',
  'error.gone.body': 'This menu is no longer available.',
};

const zh: Record<StringKey, string> = {
  'search.placeholder': '搜索菜品',
  'filter.label': '筛选',
  'filter.spice': '辣度',
  'filter.vegetarian': '素食',
  'filter.signature': '招牌',
  'filter.recommended': '推荐',
  'filter.clear': '清除',
  'badge.poweredBy': '由 MenuRay 提供 →',
  'back': '返回',
  'soldOut': '已售罄',
  'dish.signature': '招牌',
  'dish.recommended': '推荐',
  'dish.vegetarian': '素食',
  'spice.mild': '微辣',
  'spice.medium': '中辣',
  'spice.hot': '重辣',
  'error.notFound.title': '菜单不存在',
  'error.notFound.body': '您访问的菜单不存在。',
  'error.gone.title': '菜单不可用',
  'error.gone.body': '此菜单已不再提供。',
};

export function t(locale: Locale, key: StringKey): string {
  const table = locale.startsWith('zh') ? zh : en;
  return table[key];
}
```

- [ ] **Step 2: Write failing tests for `applyFilters`**

```ts
// src/lib/search/applyFilters.test.ts
import { describe, it, expect } from 'vitest';
import { applyFilters, type FilterState } from './applyFilters';
import type { Category, Dish } from '$lib/types/menu';

const dish = (overrides: Partial<Dish> = {}): Dish => ({
  id: 'd' + Math.random(),
  sourceName: 'Kung Pao Chicken',
  sourceDescription: 'Spicy peanut stir-fry',
  price: 58,
  imageUrl: null,
  position: 0,
  spiceLevel: 'medium',
  isSignature: false,
  isRecommended: false,
  isVegetarian: false,
  soldOut: false,
  allergens: [],
  translations: {},
  ...overrides,
});

const cat = (dishes: Dish[]): Category => ({
  id: 'c1', sourceName: 'Mains', position: 0, translations: {}, dishes,
});

const emptyFilters: FilterState = {
  query: '',
  spice: new Set(),
  vegetarian: false,
  signature: false,
  recommended: false,
};

describe('applyFilters', () => {
  it('returns all categories unchanged when no filters apply', () => {
    const cats = [cat([dish(), dish({ sourceName: 'Other' })])];
    expect(applyFilters(cats, emptyFilters, 'en')).toEqual(cats);
  });

  it('filters by case-insensitive search in current locale', () => {
    const cats = [cat([dish({ sourceName: 'Kung Pao Chicken' }), dish({ sourceName: 'Ma Po Tofu' })])];
    const result = applyFilters(cats, { ...emptyFilters, query: 'kung' }, 'en');
    expect(result[0].dishes).toHaveLength(1);
    expect(result[0].dishes[0].sourceName).toBe('Kung Pao Chicken');
  });

  it('searches translated name when available', () => {
    const d = dish({
      sourceName: 'Kung Pao Chicken',
      translations: { 'zh-CN': { name: '宫保鸡丁', description: null } },
    });
    const cats = [cat([d])];
    expect(applyFilters(cats, { ...emptyFilters, query: '宫保' }, 'zh-CN')[0].dishes).toHaveLength(1);
    expect(applyFilters(cats, { ...emptyFilters, query: '宫保' }, 'en')[0].dishes).toHaveLength(0);
  });

  it('filters by vegetarian', () => {
    const cats = [cat([dish({ isVegetarian: false }), dish({ isVegetarian: true })])];
    const result = applyFilters(cats, { ...emptyFilters, vegetarian: true }, 'en');
    expect(result[0].dishes).toHaveLength(1);
  });

  it('filters by spice levels (set membership)', () => {
    const cats = [cat([
      dish({ spiceLevel: 'mild' }),
      dish({ spiceLevel: 'hot' }),
      dish({ spiceLevel: 'none' }),
    ])];
    const result = applyFilters(cats, { ...emptyFilters, spice: new Set(['mild', 'hot']) }, 'en');
    expect(result[0].dishes.map(d => d.spiceLevel).sort()).toEqual(['hot', 'mild']);
  });

  it('hides categories with no matching dishes', () => {
    const cats = [
      cat([dish({ isVegetarian: true })]),
      cat([dish({ isVegetarian: false })]),
    ];
    const result = applyFilters(cats, { ...emptyFilters, vegetarian: true }, 'en');
    expect(result).toHaveLength(1);
  });

  it('is diacritic-insensitive', () => {
    const d = dish({ sourceName: 'Café Crème' });
    const cats = [cat([d])];
    expect(applyFilters(cats, { ...emptyFilters, query: 'cafe creme' }, 'en')[0].dishes).toHaveLength(1);
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `pnpm test applyFilters`
Expected: FAIL — "Cannot find module './applyFilters'".

- [ ] **Step 4: Implement `applyFilters.ts`**

```ts
import type { Category, Dish, Locale, SpiceLevel } from '$lib/types/menu';
import { dishName, dishDescription } from '$lib/types/menu';

export interface FilterState {
  query: string;
  spice: Set<SpiceLevel>;
  vegetarian: boolean;
  signature: boolean;
  recommended: boolean;
}

function normalize(s: string): string {
  return s.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function dishMatches(dish: Dish, f: FilterState, locale: Locale): boolean {
  if (f.vegetarian && !dish.isVegetarian) return false;
  if (f.signature && !dish.isSignature) return false;
  if (f.recommended && !dish.isRecommended) return false;
  if (f.spice.size > 0 && !f.spice.has(dish.spiceLevel)) return false;

  if (f.query.trim() === '') return true;
  const q = normalize(f.query);
  const name = normalize(dishName(dish, locale));
  const desc = normalize(dishDescription(dish, locale) ?? '');
  return name.includes(q) || desc.includes(q);
}

export function applyFilters(
  categories: Category[],
  filters: FilterState,
  locale: Locale,
): Category[] {
  return categories
    .map((c) => ({ ...c, dishes: c.dishes.filter((d) => dishMatches(d, filters, locale)) }))
    .filter((c) => c.dishes.length > 0);
}
```

- [ ] **Step 5: Run tests**

Run: `pnpm test applyFilters`
Expected: PASS — all 7 tests green.

- [ ] **Step 6: Write failing test for `jsonLd`**

```ts
// src/lib/seo/jsonLd.test.ts
import { describe, it, expect } from 'vitest';
import { buildMenuJsonLd } from './jsonLd';
import type { PublishedMenu } from '$lib/types/menu';

const menu: PublishedMenu = {
  id: 'm1',
  slug: 'demo',
  name: 'Lunch Menu',
  currency: 'CNY',
  sourceLocale: 'zh-CN',
  availableLocales: ['zh-CN', 'en'],
  timeSlot: 'lunch',
  timeSlotDescription: null,
  coverImageUrl: 'https://example.com/cover.jpg',
  publishedAt: '2026-04-20T00:00:00Z',
  store: {
    id: 's1', logoUrl: null, sourceName: '云涧小厨', sourceAddress: null,
    translations: { en: { name: 'Yunjian Kitchen', address: null } },
    customBrandingOff: false,
  },
  categories: [{
    id: 'c1', sourceName: '凉菜', position: 0,
    translations: { en: { name: 'Cold' } },
    dishes: [{
      id: 'd1', sourceName: '宫保鸡丁', sourceDescription: '花生辣味',
      price: 58, imageUrl: null, position: 0, spiceLevel: 'medium',
      isSignature: false, isRecommended: false, isVegetarian: false,
      soldOut: false, allergens: [],
      translations: { en: { name: 'Kung Pao Chicken', description: 'Peanut spicy' } },
    }],
  }],
};

describe('buildMenuJsonLd', () => {
  it('produces a Restaurant with nested Menu + MenuSection + MenuItem', () => {
    const ld = buildMenuJsonLd(menu, 'en');
    expect(ld['@context']).toBe('https://schema.org');
    expect(ld['@type']).toBe('Restaurant');
    expect(ld.name).toBe('Yunjian Kitchen');
    expect(ld.hasMenu['@type']).toBe('Menu');
    expect(ld.hasMenu.hasMenuSection[0]['@type']).toBe('MenuSection');
    expect(ld.hasMenu.hasMenuSection[0].name).toBe('Cold');
    const item = ld.hasMenu.hasMenuSection[0].hasMenuItem[0];
    expect(item['@type']).toBe('MenuItem');
    expect(item.name).toBe('Kung Pao Chicken');
    expect(item.offers.price).toBe('58');
    expect(item.offers.priceCurrency).toBe('CNY');
  });

  it('falls back to source name when translation missing', () => {
    const ld = buildMenuJsonLd(menu, 'ja');
    expect(ld.name).toBe('云涧小厨');
    expect(ld.hasMenu.hasMenuSection[0].name).toBe('凉菜');
  });
});
```

- [ ] **Step 7: Run to verify failure**

Run: `pnpm test jsonLd`
Expected: FAIL — "Cannot find module './jsonLd'".

- [ ] **Step 8: Implement `jsonLd.ts`**

```ts
import type { PublishedMenu, Locale } from '$lib/types/menu';
import {
  dishName, dishDescription, categoryName, storeName, storeAddress,
} from '$lib/types/menu';

export interface MenuJsonLd {
  '@context': 'https://schema.org';
  '@type': 'Restaurant';
  name: string;
  address?: string;
  image?: string;
  hasMenu: {
    '@type': 'Menu';
    name: string;
    hasMenuSection: Array<{
      '@type': 'MenuSection';
      name: string;
      hasMenuItem: Array<{
        '@type': 'MenuItem';
        name: string;
        description?: string;
        image?: string;
        offers: {
          '@type': 'Offer';
          price: string;
          priceCurrency: string;
        };
      }>;
    }>;
  };
}

export function buildMenuJsonLd(menu: PublishedMenu, locale: Locale): MenuJsonLd {
  const address = storeAddress(menu.store, locale);
  return {
    '@context': 'https://schema.org',
    '@type': 'Restaurant',
    name: storeName(menu.store, locale),
    ...(address ? { address } : {}),
    ...(menu.coverImageUrl ? { image: menu.coverImageUrl } : {}),
    hasMenu: {
      '@type': 'Menu',
      name: menu.name,
      hasMenuSection: menu.categories.map((cat) => ({
        '@type': 'MenuSection',
        name: categoryName(cat, locale),
        hasMenuItem: cat.dishes.map((d) => {
          const desc = dishDescription(d, locale);
          return {
            '@type': 'MenuItem',
            name: dishName(d, locale),
            ...(desc ? { description: desc } : {}),
            ...(d.imageUrl ? { image: d.imageUrl } : {}),
            offers: {
              '@type': 'Offer',
              price: String(d.price),
              priceCurrency: menu.currency,
            },
          };
        }),
      })),
    },
  };
}
```

- [ ] **Step 9: Run tests**

Run: `pnpm test`
Expected: PASS — all `resolveLocale`, `applyFilters`, `jsonLd` tests green.

- [ ] **Step 10: `pnpm check`**

Run: `pnpm check`
Expected: clean.

- [ ] **Step 11: Commit**

```bash
git add frontend/customer/src/lib/
git commit -m "feat(customer): i18n strings + applyFilters + schema.org jsonLd

Three pure helpers, all TDD'd. strings.ts keyed by StringKey type.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `fetchPublishedMenu` + `logView` (integration tested against local Supabase)

**Files:**
- Create: `frontend/customer/src/lib/data/fetchPublishedMenu.ts`
- Create: `frontend/customer/src/lib/data/fetchPublishedMenu.test.ts`
- Create: `frontend/customer/src/lib/data/logView.ts`

- [ ] **Step 1: Write the failing integration test**

This test talks to the real local Supabase with the seed already loaded. It expects `yun-jian-xiao-chu-lunch-2025` to exist.

```ts
// src/lib/data/fetchPublishedMenu.test.ts
import { describe, it, expect } from 'vitest';
import { createSupabaseClient } from '$lib/supabase';
import { fetchPublishedMenu } from './fetchPublishedMenu';

describe('fetchPublishedMenu (integration)', () => {
  const supabase = createSupabaseClient();
  const SLUG = 'yun-jian-xiao-chu-lunch-2025';

  it('returns the full menu tree for a published slug', async () => {
    const menu = await fetchPublishedMenu(supabase, SLUG);
    expect(menu).not.toBeNull();
    expect(menu!.slug).toBe(SLUG);
    expect(menu!.name).toBeTruthy();
    expect(menu!.store.sourceName).toBeTruthy();
    expect(menu!.categories.length).toBeGreaterThan(0);
    expect(menu!.categories[0].dishes.length).toBeGreaterThan(0);
    // Sorted by position ascending
    const positions = menu!.categories.map(c => c.position);
    expect([...positions].sort((a, b) => a - b)).toEqual(positions);
  });

  it('returns null for an unknown slug', async () => {
    const menu = await fetchPublishedMenu(supabase, 'no-such-slug-exists-here');
    expect(menu).toBeNull();
  });

  it('resolves translations into a keyed map', async () => {
    const menu = await fetchPublishedMenu(supabase, SLUG);
    expect(menu!.availableLocales).toContain(menu!.sourceLocale);
    // The seed inserts en translations for a couple of dishes.
    const hasAnyEnTranslation = menu!.categories.some(c =>
      c.dishes.some(d => d.translations['en']?.name !== undefined),
    );
    expect(hasAnyEnTranslation).toBe(true);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend/customer && pnpm test fetchPublishedMenu`
Expected: FAIL — "Cannot find module './fetchPublishedMenu'".

- [ ] **Step 3: Implement `fetchPublishedMenu.ts`**

```ts
import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  PublishedMenu, Store, Category, Dish, Locale, SpiceLevel, TimeSlot,
} from '$lib/types/menu';

// Shape returned by the Supabase PostgREST join (minimal typing — not the
// full generated types, since we don't run the codegen yet).
type JoinedMenuRow = {
  id: string; slug: string; name: string; status: string; currency: string;
  source_locale: string; time_slot: TimeSlot; time_slot_description: string | null;
  cover_image_url: string | null; published_at: string;
  store: {
    id: string; logo_url: string | null; name: string; address: string | null;
    source_locale: string;
    store_translations: Array<{ locale: string; name: string; address: string | null }>;
  } | null;
  categories: Array<{
    id: string; source_name: string; position: number;
    category_translations: Array<{ locale: string; name: string }>;
    dishes: Array<{
      id: string; source_name: string; source_description: string | null;
      price: number | string; image_url: string | null; position: number;
      spice_level: SpiceLevel; is_signature: boolean; is_recommended: boolean;
      is_vegetarian: boolean; sold_out: boolean; allergens: string[];
      dish_translations: Array<{ locale: string; name: string; description: string | null }>;
    }>;
  }>;
};

export async function fetchPublishedMenu(
  supabase: SupabaseClient,
  slug: string,
): Promise<PublishedMenu | null> {
  const { data, error } = await supabase
    .from('menus')
    .select(`
      id, slug, name, status, currency, source_locale,
      time_slot, time_slot_description, cover_image_url, published_at,
      store:stores (
        id, logo_url, name, address, source_locale,
        store_translations ( locale, name, address )
      ),
      categories (
        id, source_name, position,
        category_translations ( locale, name ),
        dishes (
          id, source_name, source_description, price, image_url, position,
          spice_level, is_signature, is_recommended, is_vegetarian, sold_out, allergens,
          dish_translations ( locale, name, description )
        )
      )
    `)
    .eq('slug', slug)
    .eq('status', 'published')
    .maybeSingle<JoinedMenuRow>();

  if (error) {
    console.error('fetchPublishedMenu error', error);
    return null;
  }
  if (!data) return null;
  if (!data.store) return null;  // defensive: store RLS blocked → treat as 404

  return mapRow(data);
}

function mapRow(row: JoinedMenuRow): PublishedMenu {
  const store: Store = {
    id: row.store!.id,
    logoUrl: row.store!.logo_url,
    sourceName: row.store!.name,
    sourceAddress: row.store!.address,
    translations: Object.fromEntries(
      row.store!.store_translations.map((t) => [t.locale, { name: t.name, address: t.address }]),
    ),
    customBrandingOff: false,
  };

  const categories: Category[] = [...row.categories]
    .sort((a, b) => a.position - b.position)
    .map<Category>((c) => ({
      id: c.id,
      sourceName: c.source_name,
      position: c.position,
      translations: Object.fromEntries(
        c.category_translations.map((t) => [t.locale, { name: t.name }]),
      ),
      dishes: [...c.dishes]
        .sort((a, b) => a.position - b.position)
        .map<Dish>((d) => ({
          id: d.id,
          sourceName: d.source_name,
          sourceDescription: d.source_description,
          price: typeof d.price === 'string' ? parseFloat(d.price) : d.price,
          imageUrl: d.image_url,
          position: d.position,
          spiceLevel: d.spice_level,
          isSignature: d.is_signature,
          isRecommended: d.is_recommended,
          isVegetarian: d.is_vegetarian,
          soldOut: d.sold_out,
          allergens: d.allergens,
          translations: Object.fromEntries(
            d.dish_translations.map((t) => [t.locale, { name: t.name, description: t.description }]),
          ),
        })),
    }));

  const allLocales = new Set<Locale>([row.source_locale]);
  for (const cat of categories) {
    Object.keys(cat.translations).forEach((l) => allLocales.add(l));
    for (const dish of cat.dishes) {
      Object.keys(dish.translations).forEach((l) => allLocales.add(l));
    }
  }
  Object.keys(store.translations).forEach((l) => allLocales.add(l));

  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    currency: row.currency,
    sourceLocale: row.source_locale,
    availableLocales: [...allLocales],
    timeSlot: row.time_slot,
    timeSlotDescription: row.time_slot_description,
    coverImageUrl: row.cover_image_url,
    publishedAt: row.published_at,
    store,
    categories,
  };
}
```

- [ ] **Step 4: Implement `logView.ts`**

```ts
import type { SupabaseClient } from '@supabase/supabase-js';

export async function logView(
  supabase: SupabaseClient,
  menuId: string,
  storeId: string,
  locale: string,
  requestHeaders: Headers,
  requestUrl: URL,
): Promise<void> {
  try {
    const referer = requestHeaders.get('referer');
    let referrerDomain: string | null = null;
    if (referer) {
      try {
        const refererHost = new URL(referer).hostname;
        if (refererHost !== requestUrl.hostname) referrerDomain = refererHost;
      } catch {
        /* malformed referer — drop */
      }
    }
    await supabase.from('view_logs').insert({
      menu_id: menuId,
      store_id: storeId,
      locale,
      session_id: null,
      referrer_domain: referrerDomain,
    });
  } catch (e) {
    console.warn('logView failed (non-fatal)', e);
  }
}
```

- [ ] **Step 5: Run tests**

Prerequisite: `cd backend/supabase && npx supabase start && npx supabase db reset` (reset applies migrations + seed).

Then: `cd frontend/customer && pnpm test fetchPublishedMenu`
Expected: PASS — all 3 integration tests green. If Supabase isn't running, tests will fail with ECONNREFUSED — start Supabase first.

- [ ] **Step 6: `pnpm check`**

Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add frontend/customer/src/lib/data/
git commit -m "feat(customer): fetchPublishedMenu join query + logView insert

Integration-tested against local Supabase with existing seed
(yun-jian-xiao-chu-lunch-2025). Single join returns menu + store
+ categories + dishes + all translations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Root layout + MenurayBadge + error page + logo asset

**Files:**
- Create: `frontend/customer/static/menuray-logo.svg`
- Create: `frontend/customer/src/lib/components/MenurayBadge.svelte`
- Modify: `frontend/customer/src/routes/+layout.svelte`
- Create: `frontend/customer/src/routes/+error.svelte`

- [ ] **Step 1: Add `menuray-logo.svg`**

If `frontend/merchant/assets/` contains a logo, copy it. Otherwise a minimal placeholder:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="12" fill="#2F5D50"/>
  <text x="32" y="40" font-family="Inter, sans-serif" font-size="28" font-weight="700"
        text-anchor="middle" fill="#E0A969">M</text>
</svg>
```

- [ ] **Step 2: `MenurayBadge.svelte`**

```svelte
<script lang="ts">
  import type { Locale } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { locale, hidden = false }: { locale: Locale; hidden?: boolean } = $props();
  const href = 'https://menuray.com/?utm_source=menu&utm_medium=customer_view&utm_campaign=powered_by';
</script>

{#if !hidden}
  <a
    {href}
    target="_blank"
    rel="noopener noreferrer"
    class="fixed bottom-0 left-0 right-0 z-50 flex items-center justify-center h-8
           bg-surface border-t border-divider text-secondary text-xs
           hover:text-primary transition-colors"
  >
    {t(locale, 'badge.poweredBy')}
  </a>
{/if}
```

- [ ] **Step 3: Update `+layout.svelte`**

```svelte
<script lang="ts">
  import '../app.css';
  import MenurayBadge from '$lib/components/MenurayBadge.svelte';

  let { children, data } = $props();
  const locale = $derived(data?.lang ?? 'en');
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link
    rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;600;700&display=swap"
  />
</svelte:head>

{@render children()}

<MenurayBadge {locale} />
```

- [ ] **Step 4: `+error.svelte`**

```svelte
<script lang="ts">
  import { page } from '$app/state';
  import { t } from '$lib/i18n/strings';
  const locale = 'en';
  const is410 = $derived(page.status === 410);
  const titleKey = $derived(is410 ? 'error.gone.title' : 'error.notFound.title');
  const bodyKey = $derived(is410 ? 'error.gone.body' : 'error.notFound.body');
</script>

<main class="min-h-dvh flex flex-col items-center justify-center p-8 text-center gap-4">
  <h1 class="text-2xl font-semibold text-ink">{t(locale, titleKey)}</h1>
  <p class="text-secondary max-w-md">{t(locale, bodyKey)}</p>
  <a href="https://menuray.com" class="text-primary underline underline-offset-4">menuray.com</a>
</main>
```

- [ ] **Step 5: Verify the page still boots**

Run: `pnpm check && pnpm dev`
Expected: `/` still renders; visit `/definitely-no-slug` → 404 error page renders with brand shell. Ctrl-C to stop.

- [ ] **Step 6: Commit**

```bash
git add frontend/customer/static/ frontend/customer/src/lib/components/MenurayBadge.svelte frontend/customer/src/routes/+layout.svelte frontend/customer/src/routes/+error.svelte
git commit -m "feat(customer): root layout with MenurayBadge + brand error page

Badge fixed-bottom, utm-tagged. Google Fonts preconnect for Inter +
Noto Sans SC. Error page handles 404 and 410 with locale-aware text.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: B1 — menu home SSR + UI (no search/filter/lang yet)

**Files:**
- Create: `frontend/customer/src/routes/[slug]/+page.server.ts`
- Create: `frontend/customer/src/routes/[slug]/+page.svelte`
- Create: `frontend/customer/src/lib/components/MenuHeader.svelte`
- Create: `frontend/customer/src/lib/components/CategoryNav.svelte`
- Create: `frontend/customer/src/lib/components/DishCard.svelte`

- [ ] **Step 1: `[slug]/+page.server.ts`**

```ts
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { logView } from '$lib/data/logView';
import { resolveLocale } from '$lib/i18n/resolveLocale';
import { buildMenuJsonLd } from '$lib/seo/jsonLd';

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,  // resolved client-side
    acceptLanguage: request.headers.get('accept-language'),
    available: menu.availableLocales,
    source: menu.sourceLocale,
  });

  logView(locals.supabase, menu.id, menu.store.id, locale, request.headers, url);

  return {
    menu,
    lang: locale,
    jsonLd: buildMenuJsonLd(menu, locale),
  };
};
```

- [ ] **Step 2: `MenuHeader.svelte`**

```svelte
<script lang="ts">
  import type { PublishedMenu, Locale } from '$lib/types/menu';
  import { storeName, storeAddress } from '$lib/types/menu';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
  const address = $derived(storeAddress(menu.store, locale));
</script>

<header class="bg-surface border-b border-divider">
  <div class="max-w-3xl mx-auto px-4 py-6 flex items-start gap-4">
    {#if menu.store.logoUrl}
      <img src={menu.store.logoUrl} alt="" class="w-14 h-14 rounded-xl object-cover bg-divider" />
    {/if}
    <div class="flex-1 min-w-0">
      <h1 class="text-xl font-semibold text-ink truncate">{name}</h1>
      {#if address}
        <p class="text-sm text-secondary truncate">{address}</p>
      {/if}
      <p class="text-sm text-primary mt-1">{menu.name}</p>
    </div>
  </div>
</header>
```

- [ ] **Step 3: `CategoryNav.svelte`** — sticky horizontal scroller

```svelte
<script lang="ts">
  import type { Category, Locale } from '$lib/types/menu';
  import { categoryName } from '$lib/types/menu';

  let { categories, locale, activeId, onSelect }:
    { categories: Category[]; locale: Locale; activeId: string | null; onSelect: (id: string) => void } =
    $props();
</script>

<nav class="sticky top-0 z-30 bg-surface/95 backdrop-blur border-b border-divider">
  <div class="max-w-3xl mx-auto flex gap-2 overflow-x-auto px-4 py-2 no-scrollbar">
    {#each categories as cat (cat.id)}
      <button
        type="button"
        class="shrink-0 px-3 py-1.5 rounded-full text-sm transition-colors
               {activeId === cat.id
                 ? 'bg-primary text-surface'
                 : 'bg-divider/50 text-ink hover:bg-divider'}"
        onclick={() => onSelect(cat.id)}
      >
        {categoryName(cat, locale)}
      </button>
    {/each}
  </div>
</nav>

<style>
  .no-scrollbar { scrollbar-width: none; }
  .no-scrollbar::-webkit-scrollbar { display: none; }
</style>
```

- [ ] **Step 4: `DishCard.svelte`**

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
  class="flex gap-3 p-3 rounded-2xl hover:bg-divider/30 transition-colors
         {dish.soldOut ? 'opacity-50' : ''}"
  aria-label={name}
>
  {#if dish.imageUrl}
    <img src={dish.imageUrl} alt="" class="w-20 h-20 rounded-xl object-cover bg-divider shrink-0" />
  {/if}
  <div class="flex-1 min-w-0">
    <div class="flex items-start justify-between gap-2">
      <h3 class="font-medium text-ink truncate">{name}</h3>
      <span class="font-semibold text-primary whitespace-nowrap">{priceDisplay}</span>
    </div>
    {#if desc}
      <p class="text-sm text-secondary line-clamp-2 mt-0.5">{desc}</p>
    {/if}
    <div class="flex flex-wrap gap-1 mt-1.5">
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

- [ ] **Step 5: `[slug]/+page.svelte`** — B1 home (search/filter/lang come in the next tasks)

```svelte
<script lang="ts">
  import type { PageData } from './$types';
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import DishCard from '$lib/components/DishCard.svelte';
  import { categoryName, storeName } from '$lib/types/menu';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  let activeCategoryId = $state<string | null>(null);

  function scrollToCategory(id: string) {
    activeCategoryId = id;
    document.getElementById(`category-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

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
</svelte:head>

<MenuHeader {menu} {locale} />
<CategoryNav
  categories={menu.categories}
  {locale}
  activeId={activeCategoryId}
  onSelect={scrollToCategory}
/>

<main class="max-w-3xl mx-auto px-2 py-4">
  {#each menu.categories as cat (cat.id)}
    <section id="category-{cat.id}" class="mb-8">
      <h2 class="px-2 mb-2 text-lg font-semibold text-ink">
        {categoryName(cat, locale)}
      </h2>
      <div class="flex flex-col gap-1">
        {#each cat.dishes as dish (dish.id)}
          <DishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" />
        {/each}
      </div>
    </section>
  {/each}
</main>
```

- [ ] **Step 6: Verify end-to-end**

Run: `pnpm check` (expected clean).
Run: `pnpm dev`. Then open `http://localhost:5173/yun-jian-xiao-chu-lunch-2025`.
Expected:
- Store name + menu title render.
- Categories and dishes list.
- Price, badges (signature/recommended/vegetarian/sold-out) render when applicable.
- Tapping a category button scrolls to its section.
- Viewing page source contains a `<script type="application/ld+json">` block with the schema.

- [ ] **Step 7: Commit**

```bash
git add frontend/customer/src/routes/\[slug\]/ frontend/customer/src/lib/components/MenuHeader.svelte frontend/customer/src/lib/components/CategoryNav.svelte frontend/customer/src/lib/components/DishCard.svelte
git commit -m "feat(customer): B1 menu home — SSR + header + category nav + dish cards

Renders the full menu tree, sticky category nav, dish cards with
badges, JSON-LD, SEO meta. Search/filter/lang come next.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: B3 — search + filter drawer

**Files:**
- Create: `frontend/customer/src/lib/components/SearchBar.svelte`
- Create: `frontend/customer/src/lib/components/FilterDrawer.svelte`
- Modify: `frontend/customer/src/routes/[slug]/+page.svelte`

- [ ] **Step 1: `SearchBar.svelte`**

```svelte
<script lang="ts">
  import type { Locale } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let {
    value = $bindable(''),
    locale,
    onFilterClick,
    activeFilterCount,
  }: {
    value: string;
    locale: Locale;
    onFilterClick: () => void;
    activeFilterCount: number;
  } = $props();
</script>

<div class="flex gap-2 px-4 py-2 bg-surface border-b border-divider">
  <input
    type="search"
    bind:value
    placeholder={t(locale, 'search.placeholder')}
    class="flex-1 h-10 px-3 rounded-button border border-divider bg-surface
           text-ink placeholder:text-secondary focus:outline-none focus:border-primary"
  />
  <button
    type="button"
    onclick={onFilterClick}
    class="relative h-10 px-3 rounded-button border border-divider text-ink
           hover:border-primary transition-colors flex items-center gap-1"
  >
    {t(locale, 'filter.label')}
    {#if activeFilterCount > 0}
      <span class="ml-1 inline-flex items-center justify-center min-w-5 h-5 px-1
                   rounded-full bg-primary text-surface text-xs font-medium">
        {activeFilterCount}
      </span>
    {/if}
  </button>
</div>
```

- [ ] **Step 2: `FilterDrawer.svelte`**

```svelte
<script lang="ts">
  import type { Locale, SpiceLevel } from '$lib/types/menu';
  import type { FilterState } from '$lib/search/applyFilters';
  import { t } from '$lib/i18n/strings';

  let {
    open = $bindable(false),
    filters = $bindable(),
    locale,
  }: {
    open: boolean;
    filters: FilterState;
    locale: Locale;
  } = $props();

  const SPICE_LEVELS: Exclude<SpiceLevel, 'none'>[] = ['mild', 'medium', 'hot'];

  function toggleSpice(s: SpiceLevel) {
    const next = new Set(filters.spice);
    if (next.has(s)) next.delete(s); else next.add(s);
    filters = { ...filters, spice: next };
  }

  function clearAll() {
    filters = { query: filters.query, spice: new Set(), vegetarian: false, signature: false, recommended: false };
  }
</script>

{#if open}
  <div
    class="fixed inset-0 z-40 bg-ink/40"
    onclick={() => (open = false)}
    onkeydown={(e) => e.key === 'Escape' && (open = false)}
    role="button"
    tabindex="-1"
    aria-label="Close filter"
  ></div>
  <div
    class="fixed z-50 inset-x-0 bottom-0 md:inset-y-0 md:right-0 md:left-auto md:w-80
           bg-surface shadow-xl rounded-t-2xl md:rounded-t-none md:rounded-l-2xl
           p-4 pb-10 md:pb-4 max-h-[80vh] overflow-y-auto"
    role="dialog"
    aria-modal="true"
  >
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold">{t(locale, 'filter.label')}</h2>
      <button type="button" onclick={clearAll} class="text-sm text-primary">
        {t(locale, 'filter.clear')}
      </button>
    </div>

    <section class="mb-4">
      <p class="text-sm font-medium text-ink mb-2">{t(locale, 'filter.spice')}</p>
      <div class="flex flex-wrap gap-2">
        {#each SPICE_LEVELS as level (level)}
          <button
            type="button"
            onclick={() => toggleSpice(level)}
            class="px-3 py-1.5 rounded-full text-sm border transition-colors
                   {filters.spice.has(level)
                     ? 'bg-primary text-surface border-primary'
                     : 'border-divider text-ink hover:border-primary'}"
          >
            {t(locale, `spice.${level}`)}
          </button>
        {/each}
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.vegetarian} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.vegetarian')}
      </label>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.signature} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.signature')}
      </label>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.recommended} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.recommended')}
      </label>
    </section>
  </div>
{/if}
```

- [ ] **Step 3: Wire search + filter into `[slug]/+page.svelte`**

Replace the existing `+page.svelte` with:

```svelte
<script lang="ts">
  import type { PageData } from './$types';
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import DishCard from '$lib/components/DishCard.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import { categoryName, storeName } from '$lib/types/menu';
  import { applyFilters, type FilterState } from '$lib/search/applyFilters';

  let { data }: { data: PageData } = $props();
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
</svelte:head>

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
          <DishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" />
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

- [ ] **Step 4: Verify**

Run: `pnpm check` (expected clean).
Run: `pnpm dev` and open `http://localhost:5173/yun-jian-xiao-chu-lunch-2025`.
Expected:
- SearchBar renders above CategoryNav.
- Typing a query filters dishes in real time (case- and diacritic-insensitive).
- Tapping the filter button opens the drawer (bottom sheet on mobile / right panel ≥768px).
- Toggling vegetarian/signature/recommended and spice chips updates the visible list.
- Clearing returns to the full list.
- Categories with zero visible dishes disappear from both the sticky nav and the list.

- [ ] **Step 5: Commit**

```bash
git add frontend/customer/src/lib/components/SearchBar.svelte frontend/customer/src/lib/components/FilterDrawer.svelte frontend/customer/src/routes/\[slug\]/+page.svelte
git commit -m "feat(customer): B3 client-side search + filter drawer

SearchBar + FilterDrawer wired into B1. Uses applyFilters() so no
network refetch. Empty-category hiding, active-filter count badge.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: B4 — language dropdown + persistence

**Files:**
- Create: `frontend/customer/src/lib/components/LangDropdown.svelte`
- Modify: `frontend/customer/src/routes/[slug]/+page.svelte`
- Modify: `frontend/customer/src/lib/components/MenuHeader.svelte`

- [ ] **Step 1: `LangDropdown.svelte`**

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import type { Locale } from '$lib/types/menu';

  let {
    locale,
    available,
  }: {
    locale: Locale;
    available: Locale[];
  } = $props();

  const LABELS: Record<string, string> = {
    en: 'English',
    'zh-CN': '中文',
    ja: '日本語',
    ko: '한국어',
    es: 'Español',
    fr: 'Français',
  };

  function label(l: Locale): string {
    return LABELS[l] ?? l;
  }

  async function pick(next: Locale) {
    if (typeof localStorage !== 'undefined') localStorage.setItem('menuray.lang', next);
    const url = new URL(page.url);
    url.searchParams.set('lang', next);
    await goto(url.pathname + '?' + url.searchParams.toString(), { noScroll: true, replaceState: true });
  }

  let open = $state(false);
</script>

<div class="relative">
  <button
    type="button"
    onclick={() => (open = !open)}
    class="h-9 px-3 rounded-button border border-divider text-sm text-ink
           hover:border-primary transition-colors flex items-center gap-1"
    aria-haspopup="listbox"
    aria-expanded={open}
  >
    {label(locale)}
    <span aria-hidden="true" class="text-secondary">▾</span>
  </button>
  {#if open}
    <ul
      class="absolute right-0 top-full mt-1 z-40 min-w-36 py-1 rounded-button
             bg-surface border border-divider shadow-lg"
      role="listbox"
    >
      {#each available as l (l)}
        <li>
          <button
            type="button"
            onclick={() => { open = false; pick(l); }}
            class="w-full text-left px-3 py-1.5 text-sm hover:bg-divider/40
                   {l === locale ? 'text-primary font-medium' : 'text-ink'}"
            role="option"
            aria-selected={l === locale}
          >
            {label(l)}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
```

- [ ] **Step 2: Add LangDropdown to `MenuHeader.svelte`**

```svelte
<script lang="ts">
  import type { PublishedMenu, Locale } from '$lib/types/menu';
  import { storeName, storeAddress } from '$lib/types/menu';
  import LangDropdown from './LangDropdown.svelte';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
  const address = $derived(storeAddress(menu.store, locale));
</script>

<header class="bg-surface border-b border-divider">
  <div class="max-w-3xl mx-auto px-4 py-6 flex items-start gap-4">
    {#if menu.store.logoUrl}
      <img src={menu.store.logoUrl} alt="" class="w-14 h-14 rounded-xl object-cover bg-divider" />
    {/if}
    <div class="flex-1 min-w-0">
      <h1 class="text-xl font-semibold text-ink truncate">{name}</h1>
      {#if address}
        <p class="text-sm text-secondary truncate">{address}</p>
      {/if}
      <p class="text-sm text-primary mt-1">{menu.name}</p>
    </div>
    {#if menu.availableLocales.length > 1}
      <LangDropdown {locale} available={menu.availableLocales} />
    {/if}
  </div>
</header>
```

- [ ] **Step 3: Read localStorage on mount and redirect if server-resolved locale differs**

Append inside the `<script>` of `[slug]/+page.svelte` (before the `<svelte:head>`):

```ts
import { goto } from '$app/navigation';
import { page } from '$app/state';

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
```

- [ ] **Step 4: Verify**

Run: `pnpm check` (expected clean).
Run: `pnpm dev` and open the menu URL.
Expected:
- LangDropdown appears in the header when `availableLocales.length > 1`.
- Picking a language changes URL to `?lang=<code>` and flips visible strings instantly (store name, category names, dish names, UI buttons).
- localStorage key `menuray.lang` is set.
- Refreshing without `?lang` (e.g. open a new tab to `/<slug>` with no query) redirects to `?lang=<stored>` seamlessly.
- `<html lang>` reflects current locale.

- [ ] **Step 5: Commit**

```bash
git add frontend/customer/src/lib/components/LangDropdown.svelte frontend/customer/src/lib/components/MenuHeader.svelte frontend/customer/src/routes/\[slug\]/+page.svelte
git commit -m "feat(customer): B4 language dropdown with URL + localStorage persistence

Dropdown in MenuHeader when availableLocales > 1. Client restores
stored preference when URL has no ?lang. <html lang> synced.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: B2 — dish detail page

**Files:**
- Create: `frontend/customer/src/routes/[slug]/[dishId]/+page.server.ts`
- Create: `frontend/customer/src/routes/[slug]/[dishId]/+page.svelte`
- Create: `frontend/customer/src/lib/components/AllergensPills.svelte`
- Create: `frontend/customer/src/lib/components/SpiceIndicator.svelte`

- [ ] **Step 1: `AllergensPills.svelte`**

```svelte
<script lang="ts">
  let { allergens }: { allergens: string[] } = $props();
</script>

{#if allergens.length > 0}
  <div class="flex flex-wrap gap-1.5" aria-label="allergens">
    {#each allergens as a (a)}
      <span class="text-xs px-2 py-0.5 rounded-full border border-divider text-secondary bg-surface">
        {a}
      </span>
    {/each}
  </div>
{/if}
```

- [ ] **Step 2: `SpiceIndicator.svelte`**

```svelte
<script lang="ts">
  import type { Locale, SpiceLevel } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { level, locale }: { level: SpiceLevel; locale: Locale } = $props();
  const pepperCount = $derived({ none: 0, mild: 1, medium: 2, hot: 3 }[level]);
</script>

{#if pepperCount > 0}
  <div class="flex items-center gap-1 text-sm text-error" aria-label={t(locale, `spice.${level}`)}>
    {#each Array(pepperCount) as _, i (i)}
      <span aria-hidden="true">🌶</span>
    {/each}
    <span class="ml-1">{t(locale, `spice.${level}`)}</span>
  </div>
{/if}
```

- [ ] **Step 3: `[slug]/[dishId]/+page.server.ts`**

```ts
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { resolveLocale } from '$lib/i18n/resolveLocale';

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  let foundDish = null;
  let foundCategory = null;
  for (const cat of menu.categories) {
    const d = cat.dishes.find((x) => x.id === params.dishId);
    if (d) {
      foundDish = d;
      foundCategory = cat;
      break;
    }
  }
  if (!foundDish || !foundCategory) throw error(404, 'Dish not found');

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,
    acceptLanguage: request.headers.get('accept-language'),
    available: menu.availableLocales,
    source: menu.sourceLocale,
  });

  return {
    menu,
    category: foundCategory,
    dish: foundDish,
    lang: locale,
  };
};
```

- [ ] **Step 4: `[slug]/[dishId]/+page.svelte`**

```svelte
<script lang="ts">
  import type { PageData } from './$types';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import AllergensPills from '$lib/components/AllergensPills.svelte';
  import SpiceIndicator from '$lib/components/SpiceIndicator.svelte';
  import { dishName, dishDescription, categoryName, storeName } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const dish = $derived(data.dish);
  const category = $derived(data.category);
  const locale = $derived(data.lang);

  const name = $derived(dishName(dish, locale));
  const desc = $derived(dishDescription(dish, locale));
  const priceDisplay = $derived(
    (() => {
      try {
        return new Intl.NumberFormat(locale, { style: 'currency', currency: menu.currency }).format(dish.price);
      } catch {
        return `${menu.currency} ${dish.price.toFixed(2)}`;
      }
    })(),
  );

  $effect(() => {
    if (typeof document !== 'undefined') document.documentElement.lang = locale;
  });

  function back() {
    // Prefer history back if we arrived from B1; fall back to slug home.
    if (typeof history !== 'undefined' && history.length > 1 && document.referrer.includes(`/${menu.slug}`)) {
      history.back();
    } else {
      goto(`/${menu.slug}${page.url.search}`, { noScroll: false });
    }
  }

  const title = $derived(`${name} — ${storeName(menu.store, locale)} | MenuRay`);
</script>

<svelte:head>
  <title>{title}</title>
  {#if desc}<meta name="description" content={desc.slice(0, 155)} />{/if}
  {#if dish.imageUrl}<meta property="og:image" content={dish.imageUrl} />{/if}
  <meta property="og:title" content={title} />
  <meta property="og:locale" content={locale} />
</svelte:head>

<div class="min-h-dvh bg-surface">
  <button
    type="button"
    onclick={back}
    class="sticky top-0 z-30 w-full px-4 py-3 text-sm text-primary bg-surface/95 backdrop-blur border-b border-divider text-left"
  >
    ← {t(locale, 'back')}
  </button>

  {#if dish.imageUrl}
    <img src={dish.imageUrl} alt="" class="w-full max-w-3xl mx-auto aspect-video object-cover bg-divider" />
  {/if}

  <article class="max-w-3xl mx-auto px-4 py-6 flex flex-col gap-4">
    <div class="flex items-start justify-between gap-3">
      <div class="flex-1 min-w-0">
        <p class="text-sm text-secondary">{categoryName(category, locale)}</p>
        <h1 class="text-2xl font-semibold text-ink mt-0.5">{name}</h1>
      </div>
      <span class="text-xl font-semibold text-primary whitespace-nowrap">{priceDisplay}</span>
    </div>

    {#if desc}
      <p class="text-ink leading-relaxed">{desc}</p>
    {/if}

    <div class="flex flex-wrap gap-2 items-center">
      {#if dish.isSignature}
        <span class="text-xs px-2 py-0.5 rounded-full bg-accent/20 text-accent font-medium">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-xs px-2 py-0.5 rounded-full bg-error/10 text-error">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>

    <SpiceIndicator level={dish.spiceLevel} {locale} />
    <AllergensPills allergens={dish.allergens} />
  </article>
</div>
```

- [ ] **Step 5: Verify**

Run: `pnpm check`.
Run: `pnpm dev`. From B1, tap any dish card.
Expected:
- B2 renders at `/<slug>/<dishId>` with image (if present), name, category breadcrumb, price, description, badges, spice indicator, allergens.
- Back button returns to B1 preserving the previous scroll.
- `?lang=` carries through (open `/<slug>/<dishId>?lang=en` directly — all strings render in English).
- Visiting `/<slug>/does-not-exist` → 404 error page.

- [ ] **Step 6: Commit**

```bash
git add frontend/customer/src/routes/\[slug\]/\[dishId\]/ frontend/customer/src/lib/components/AllergensPills.svelte frontend/customer/src/lib/components/SpiceIndicator.svelte
git commit -m "feat(customer): B2 dish detail page with spice indicator + allergens

Independent route enables deep linking + SEO. SSR fetch reuses the
menu load and walks categories to find the dish.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Playwright e2e — happy path + 410

**Files:**
- Create: `frontend/customer/playwright.config.ts`
- Create: `frontend/customer/tests/e2e/b1-happy.spec.ts`
- Create: `frontend/customer/tests/e2e/b1-410.spec.ts`

- [ ] **Step 1: `playwright.config.ts`**

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: false,     // tests mutate the DB; serialize
  retries: 0,
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'pnpm build && pnpm preview --port 4173',
    port: 4173,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
```

- [ ] **Step 2: Install Playwright browsers**

Run: `cd frontend/customer && pnpm exec playwright install chromium`
Expected: downloads chromium once.

- [ ] **Step 3: `b1-happy.spec.ts`**

```ts
import { test, expect } from '@playwright/test';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

test('B1 renders the seeded menu and navigates to B2', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  // Menu title (in zh source locale).
  await expect(page.locator('h1').first()).toBeVisible();
  await expect(page.getByText('午市套餐 2025 春')).toBeVisible();

  // Category nav has at least one button.
  const catButtons = page.locator('nav button');
  await expect(catButtons.first()).toBeVisible();

  // Tap the first dish card.
  const firstDish = page.locator('main a[aria-label]').first();
  await firstDish.click();

  // Arrive on B2.
  await expect(page).toHaveURL(new RegExp(`/${SLUG}/[0-9a-f-]+`));
  await expect(page.getByText('返回')).toBeVisible();

  // Back button returns to B1.
  await page.getByText('返回').click();
  await expect(page).toHaveURL(new RegExp(`/${SLUG}(\\?.*)?$`));
});

test('search filters dishes in real time', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  const cardsBefore = await page.locator('main a[aria-label]').count();
  expect(cardsBefore).toBeGreaterThan(0);

  // Type a query that should match only the 宫保鸡丁-style dish.
  await page.getByPlaceholder('搜索菜品').fill('宫保');

  const cardsAfter = await page.locator('main a[aria-label]').count();
  expect(cardsAfter).toBeLessThan(cardsBefore);
});

test('language switcher flips visible UI strings', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  // Default is zh (source_locale of seed).
  await expect(page.getByPlaceholder('搜索菜品')).toBeVisible();

  await page.getByRole('button', { name: /中文/ }).click();
  await page.getByRole('option', { name: 'English' }).click();

  await expect(page.getByPlaceholder('Search dishes')).toBeVisible();
  await expect(page).toHaveURL(/lang=en/);
});

test('JSON-LD script tag is emitted', async ({ page }) => {
  await page.goto(`/${SLUG}`);
  const json = await page.locator('script[type="application/ld+json"]').innerText();
  const parsed = JSON.parse(json);
  expect(parsed['@context']).toBe('https://schema.org');
  expect(parsed['@type']).toBe('Restaurant');
  expect(parsed.hasMenu['@type']).toBe('Menu');
});
```

- [ ] **Step 4: `b1-410.spec.ts`**

```ts
import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
// Service role key from local Supabase default (no secrets — local only).
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

test('archived menu returns 404 page', async ({ page }) => {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  try {
    // Flip the seeded menu to archived.
    const { error } = await admin.from('menus').update({ status: 'archived' }).eq('slug', SLUG);
    expect(error).toBeNull();

    const resp = await page.goto(`/${SLUG}`);
    expect(resp!.status()).toBe(404);
    // Error page rendered.
    await expect(page.getByText(/Menu not found/i)).toBeVisible();
  } finally {
    // Always flip back so subsequent tests still work.
    await admin.from('menus').update({ status: 'published' }).eq('slug', SLUG);
  }
});
```

Note: for this sub-batch we treat archived-menu-via-slug as 404 (not 410) because `fetchPublishedMenu` returns null under RLS (the row is invisible to anon). A true 410 would require a second service-role query inside SSR that we deliberately didn't add this sub-batch — revisit if UX needs discrimination.

- [ ] **Step 5: Run the e2e suite**

Prerequisite: local Supabase running (`cd backend/supabase && npx supabase start`). Seed must be loaded (`npx supabase db reset`).

Run: `cd frontend/customer && pnpm test:e2e`
Expected: 5 tests pass. On first run Playwright will build the app and serve preview.

- [ ] **Step 6: Commit**

```bash
git add frontend/customer/playwright.config.ts frontend/customer/tests/
git commit -m "test(customer): playwright e2e for B1 happy path + archived menu

Covers render, search, language switch, JSON-LD emission, and
404 when menu is flipped to archived.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Spec alignment + repo-level glue + final verification

**Files:**
- Modify: `README.md` (root) — single-line mention of the customer app under tech stack / quickstart.
- Modify: `CLAUDE.md` (root) — "Active work" cell update.
- Modify: `docs/architecture.md` — add a paragraph on the new customer app layout + the new RLS policy.

- [ ] **Step 1: Update root `README.md`**

Add one line to the "Run it locally" or "Tech stack" section, e.g. under the merchant instructions:

```md
### Customer view (SvelteKit)

```bash
cd frontend/customer
pnpm install
pnpm dev   # http://localhost:5173/<slug>
```

(Requires a local Supabase running — see `backend/supabase/`.)
```

Use whatever section/format is already idiomatic in the README.

- [ ] **Step 2: Update root `CLAUDE.md` "Active work" cell**

Change the ✅ Done cell to include: "SvelteKit customer view B1–B4 (`frontend/customer/`): SSR by slug, search/filter, language switcher, JSON-LD, MenurayBadge. Anon RLS extended with `stores_anon_read_of_published`."

Keep the 🔄 Next cell; strike the completed sub-batch.

- [ ] **Step 3: Update `docs/architecture.md`**

Append (or extend) the "Customer view" section with:

```md
### Customer view (SvelteKit)

Location: `frontend/customer/` (standalone package, pnpm, Node 22, adapter-node).

Runtime: single Supabase anon client per SSR request (attached to `event.locals.supabase` in `hooks.server.ts`). One join query per page loads menu + store + categories + dishes + all translations; search/filter/language are fully client-side after that.

RLS note: the anon role reads `stores` via the `stores_anon_read_of_published` policy (migration `20260420000005`) — gated on the existence of a published menu owned by the store. Every other table anon touches is still governed by the original policies in `20260420000002_rls_policies.sql`.

SEO: each `[slug]` page emits schema.org `Restaurant` + `Menu` + `MenuSection` + `MenuItem` JSON-LD. Language is negotiated via URL `?lang=` → localStorage → Accept-Language → menu `source_locale`.

View logging: `view_logs` inserted fire-and-forget from SSR. Dedup / bot filtering lands with the analytics pipeline (Session 5).
```

- [ ] **Step 4: Run full verification**

```bash
cd frontend/customer
pnpm check     # must be clean
pnpm test      # unit — must pass
pnpm test:e2e  # e2e — must pass
```

If any step fails, fix before moving on. Paste the outputs into the final commit message.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md docs/architecture.md
git commit -m "docs: reflect customer-view sveltekit app in root + architecture

Updates:
- README: add customer-view dev quickstart
- CLAUDE.md: mark sub-batch 1 done in Active work
- architecture.md: document customer-view runtime + new RLS policy

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes

Every spec section has a task:

| Spec § | Task |
|---|---|
| §1 In scope: RLS migration | Task 1 |
| §1 In scope: SvelteKit scaffolding | Task 2 |
| §1 In scope: Tailwind v4 + brand theme | Task 3 |
| §3.3 Data fetching (+ mapper) | Task 8 |
| §3.4 SSR view logging | Task 8 + Task 10 |
| §3.5 B3 search & filter | Task 11 (+ `applyFilters` pure helper in Task 7) |
| §3.6 B4 language resolution | Task 6 (resolver) + Task 12 (UI + persistence) |
| §3.7 SEO + JSON-LD | Task 7 (builder) + Task 10 (`<svelte:head>`) |
| §3.8 MenurayBadge | Task 9 |
| §3.9 Error states | Task 9 (404/410 page) + Task 10 (`throw error()`) + Task 14 (test) |
| §3.10 Testing | Task 6/7/8 (unit) + Task 14 (e2e) |
| §3.11 Stores RLS addition | Task 1 |
| §3.12 Local dev | README in Task 2 + docs in Task 15 |
| §1 In scope: B1 + B2 UI | Tasks 10 (B1 shell) + 11 (B3) + 12 (B4) + 13 (B2) |

No placeholders detected on re-scan. Type names consistent across tasks (PublishedMenu / Store / Category / Dish; FilterState; MenuJsonLd). Method signatures align — `applyFilters(categories, filters, locale)`, `buildMenuJsonLd(menu, locale)`, `fetchPublishedMenu(supabase, slug)`, `logView(supabase, menuId, storeId, locale, headers, url)`, `resolveLocale(input)`.

One subtle adjustment recorded in Task 14 Step 4: archived menus surface as 404 (not 410) because RLS makes them invisible to anon; the spec's 410 branch would require a second service-role query, which is out of scope this sub-batch.
