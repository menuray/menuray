# Session 7 — AI Batch (translate + describe-expand) + Multi-store Button — Design

Date: 2026-04-25
Scope: Three small P0-tail features bundled into one session because they each fit the **S** budget and share the existing OpenAI provider factory + `currentTierProvider` + Edge Function patterns established in Sessions 2 and 4. After this session every P0 coding-task on `docs/roadmap.md` is closed; remaining P0 is launch-readiness work the human owner does (logo, domain, ToS, real-device QA).

## 1. Goal & Scope

After Session 7 ships:

1. **Translate menu** — A merchant on the AI Optimize screen flips the "multi-language" toggle, picks a target language, taps "Start", and within ~10 seconds every dish and category has a row in `dish_translations` / `category_translations` for that locale. The customer view's language switcher exposes the new locale on the next page load.
2. **AI describe-expand** — Same screen, "description expand" toggle on, taps "Start", and every dish's `source_description` gets a more enticing/longer rewrite (in-place — no separate column). Source name is **not** rewritten (could change SKU expectations).
3. **+ New store** — A Growth-tier merchant on the Store Picker screen sees a "+ New store" tile at the bottom, taps it, enters a name + currency + source-locale in a modal sheet, and lands on the new store with the existing Edge Function (`create-store`, S4) doing the work. Free / Pro see the tile disabled with a small "Growth-only" pill that links to `/upgrade`.

**In scope**

- **Backend**:
  - New Edge Function `backend/supabase/functions/translate-menu/{index.ts, orchestrator.ts, deno.json, README.md, test.ts}`. Reuses the existing `_shared/providers/factory.ts` + `OpenAIStructureProvider`. Tier-gates by counting `menus.available_locales` (read denormalised from the menu after upsert).
  - New Edge Function `backend/supabase/functions/ai-optimize/{index.ts, orchestrator.ts, deno.json, README.md, test.ts}`. Same provider factory. No locale arg — operates only on `dishes.source_description`.
  - New strict JSON Schema response_format for each — kept separate so prompt/schema evolution doesn't entangle.
  - Both Edge Functions enforce per-month quotas mirrored on the existing `parse-menu` re-parse cap pattern, but stricter — these calls are *cheaper* but still racket up cost. Per-tier caps (per-month, per-store, summed across both Edge Functions): Free 1, Pro 10, Growth 100. Stored on a new `ai_runs` table (or piggyback on `parse_runs` — see §4.5).
- **Flutter merchant**:
  - New `frontend/merchant/lib/features/ai/data/ai_repository.dart` with two methods: `translateMenu(menuId, targetLocale)` and `optimizeDescriptions(menuId)`. Both invoke their respective Edge Functions via `Supabase.client.functions.invoke`, parse the response, and surface typed errors.
  - `frontend/merchant/lib/features/ai/ai_providers.dart` exposing the repository as a Provider.
  - Rewire `ai_optimize_screen.dart`:
    - Route changes from `/ai/optimize` (no param) to `/ai/optimize/:menuId`.
    - `_onStart` becomes async: shows loading dialog, calls `optimizeDescriptions` then `translateMenu` in sequence based on toggle state, updates a progress text ("Translating dishes…"), shows a success snackbar + pops on completion, surfaces errors via snackbar.
    - "Auto-image" toggle stays visible but is disabled (`onChanged: null`) with a "Coming soon" subtitle suffix — P1 deferred per `docs/roadmap.md`.
    - Locale picker grows from 4 → 8 options (en, zh-CN, ja, ko, fr, es, de, vi). Tier-cap enforcement kicks in **after** the call (Edge Function returns 402 if it would push over) — UI shows the upgrade callout snackbar with a link to `/upgrade`.
  - New `frontend/merchant/lib/features/store/data/store_creation_repository.dart` (or extend the existing `StoreRepository`) with `createStore(name, currency, sourceLocale)`.
  - `frontend/merchant/lib/features/store/presentation/store_picker_screen.dart` gets a new bottom tile ("+ New store") rendered after the membership list. Tier-gated: Growth → tappable + opens a modal bottom sheet (`_NewStoreSheet` private widget) with three form fields + Save; non-Growth → tappable but routes to `/upgrade` (matches existing `TierGate` pattern). On success: refresh `membershipsProvider`, set `activeStoreProvider` to the new store, `context.go(AppRoutes.home)`.
- **i18n**:
  - 8 new keys: `translateRunningSubtitle`, `translateSuccessSnackbar`, `translateOverCapSnackbar`, `optimizeRunningSubtitle`, `optimizeSuccessSnackbar`, `aiOverQuotaSnackbar`, `storePickerNewStore`, `storePickerCreateStoreSheetTitle`. Plus 4 form-field labels for the new-store sheet (`storeFormName`, `storeFormCurrency`, `storeFormSourceLocale`, `storeFormCreateAction`). Plus 4 new locale labels for the expanded picker (`aiOptimizeLangSpanish`, `aiOptimizeLangGerman`, `aiOptimizeLangChinese`, `aiOptimizeLangVietnamese`). 16 keys total, en + zh.
- **Tests**:
  - Deno: 5 tests for `translate-menu` (auth, tier-gate, mock provider happy path, schema validation rejection, cap-overage 402). 4 tests for `ai-optimize` (auth, mock provider happy path, schema validation rejection, quota enforcement).
  - Flutter: extend `test/smoke/ai_optimize_screen_smoke_test.dart` to assert the locale picker has 8 options and the auto-image toggle is disabled. New `test/smoke/store_picker_screen_smoke_test.dart` (or extend if it exists) to assert the Growth-tier path renders "+ New store" tile and the non-Growth path renders the disabled variant. New unit test for `StoreCreationRepository` mocking the SupabaseClient functions interface.
- **Docs**: ADR-024, CLAUDE.md "Active work" Session 7, `docs/architecture.md` paragraph on AI batch, `docs/roadmap.md` flips the three rows to ✅.

**Out of scope (deferred)**

- **Auto-generated dish images** — P1 batch, MVP needs to choose between OpenAI gpt-image / Replicate / SDXL; out of session scope. The toggle stays visible but disabled with "Coming soon" copy.
- **Per-dish translation** — only menu-wide batch translation. A merchant editing a single dish doesn't get a per-dish translate button.
- **Translate the source-language strings into a fresh source locale** — translate-menu only adds *additional* locales; if the merchant wants to change source from Chinese to English they must re-create the menu.
- **AI cost tracking with per-merchant analytics** — P1. We log the call to `ai_runs` for quota purposes but no cost-display surface yet.
- **"Translate just the source name"** — translate-menu writes both name+description per dish. The user can't opt into name-only or description-only.
- **Scheduling / async job queue** — both Edge Functions are synchronous (≤30s typical for 50 dishes). Past 200 dishes the request might time out (Supabase Edge default 60s); we accept the limit and surface the error. P1 follow-up: queue + polling.
- **Streaming progress updates** — the loading dialog shows static "Translating…" text; it doesn't stream "12/50 dishes translated". OpenAI gpt-4o-mini batches the entire menu in one round-trip so streaming would expose the LLM's mid-generation state to no real benefit.
- **Re-running translation overwrites existing rows** — the upsert replaces the row for that (dish_id, locale). Good. But there's no undo; if the LLM produces worse copy than the previous run, the merchant has to manually edit each dish.
- **A "test translation" preview** — no per-dish review-before-write step. The translation lands directly. Reverting requires manual editing.
- **PDF table-tent / `image_gallery_saver`** — still P1.
- **AI optimize run logs UI for merchants** — `ai_runs` is internal to quota enforcement; no merchant-facing audit log.

## 2. Context

Schemas and modules:
- `dish_translations(id, dish_id, store_id, locale, name, description, ...)` with `UNIQUE(dish_id, locale)` from `20260420000001_init_schema.sql:84-94`. Source-locale strings live on `dishes.source_name` + `dishes.source_description`. Translations are **separate** rows for non-source locales.
- `category_translations(id, category_id, store_id, locale, name, ...)` from `20260420000001_init_schema.sql:97-106`. Same convention — `categories.source_name` is the source locale; translations are separate rows.
- `menus.available_locales text[]` — populated when the source menu is created. We'll bump it after a successful translate run if the new locale isn't present.
- Provider factory `backend/supabase/functions/_shared/providers/factory.ts:23-36` exposes `getLlmProvider()` that returns `OpenAIStructureProvider` or `MockLlmProvider` based on `MENURAY_LLM_PROVIDER` env. The mock factory is the CI default — both new Edge Functions inherit that policy.
- `OpenAIStructureProvider` (`_shared/providers/openai_structure.ts:42-115`) sets the response format to a strict JSON Schema. Pattern: build a schema, pass `response_format: { type: "json_schema", json_schema: { strict: true, ...} }`, parse the result. Translation + describe-expand each get their own schema co-located with the orchestrator.
- `parse-menu/index.ts:62-80` enforces re-parse quota by counting `parse_runs` rows for the (menu_id, current_month). Translate / optimize quota piggybacks on the same pattern with a new `ai_runs` table — see §4.5.
- Auth/RLS: every Edge Function reads `Authorization: Bearer <jwt>` and uses the user-scoped Supabase client; RLS plus the `user_store_role(store_id)` SETOF helper from S3 prevent cross-store leaks.
- `create-store/index.ts:16-86` (S4) takes `{ name, currency?, source_locale? }`, requires Growth tier (line 38 — checked via `currentTierProvider`-equivalent server logic), inserts a `stores` row, auto-`store_members` the caller as owner, returns `{ storeId }`.
- `store_picker_screen.dart:14-86` — list view of memberships, no mutation entry point. Riverpod `membershipsProvider` is the source of truth; invalidating it after `createStore` re-queries the list.
- `tier_gate.dart` and `currentTierProvider` already exist (S4) — same widget powers the upgrade-callout pattern on Settings, Statistics, custom-theme, etc.

Existing i18n keys to reuse:
- `aiOptimizeAutoImageTitle` / `aiOptimizeAutoImageSubtitle` — kept; subtitle gets a "(Coming soon)" suffix added.
- `aiOptimizeMultiLangTitle` / `aiOptimizeMultiLangSubtitle({lang})` — kept.
- `aiOptimizeDescExpandTitle` / `aiOptimizeDescExpandSubtitle` — kept.
- `aiOptimizeCta` — kept.
- `aiOptimizeLang*` — Japanese / Korean / French exist. Add the four new locales (Spanish, German, Chinese, Vietnamese).

## 3. Architecture

### 3.1 Translate flow (per call)

```
Flutter (ai_optimize_screen.dart)
  → AiRepository.translateMenu(menuId, targetLocale)
  → Supabase.functions.invoke('translate-menu', body: { menu_id, target_locale })
  → translate-menu/index.ts
      ├── auth: verify JWT
      ├── load: stores (tier), menus (available_locales, source_locale), categories[] + dishes[]
      ├── tier check: count(distinct(available_locales ∪ {target_locale})) ≤ tier_cap → else 402
      ├── quota check: count(ai_runs WHERE store_id=X AND month=now() AND kind IN ('translate','optimize')) < tier_quota → else 429
      ├── orchestrator.translateMenu(...)
      │     ├── build prompt: "translate the following menu from {source} to {target}; preserve numbering"
      │     ├── strict JSON Schema response: { categories: [{id,name}], dishes: [{id,name,description}] }
      │     ├── call llmProvider.structure(prompt, schema)
      │     └── return parsed { categories, dishes }
      ├── upsert: category_translations + dish_translations (single transaction)
      ├── update: menus.available_locales = available_locales ∪ {target_locale}
      ├── insert: ai_runs row {kind: 'translate', target_locale, dish_count, ms, ok: true}
      └── return: { translatedDishCount, translatedCategoryCount, availableLocales }
```

### 3.2 Describe-expand flow (per call)

```
Flutter
  → AiRepository.optimizeDescriptions(menuId)
  → Supabase.functions.invoke('ai-optimize', body: { menu_id })
  → ai-optimize/index.ts
      ├── auth + same quota gate (kind='optimize')
      ├── load: dishes[] (source_name, source_description)
      ├── orchestrator.expandDescriptions(...)
      │     ├── build prompt: "rewrite each description more enticing; ≤2 sentences; never invent ingredients"
      │     ├── strict JSON Schema response: { dishes: [{id, source_description}] }
      │     └── return parsed
      ├── update: dishes.source_description per row (single transaction)
      ├── insert: ai_runs row {kind: 'optimize', dish_count, ms, ok: true}
      └── return: { rewrittenDishCount }
```

### 3.3 + New store flow

```
Flutter (store_picker_screen.dart)
  → tap "+ New store" tile (TierGate enforced)
  → showModalBottomSheet → _NewStoreSheet
      ├── three form fields (name required; currency default 'USD'; source_locale default 'en')
      └── Save tap → StoreCreationRepository.createStore(...)
                        → Supabase.functions.invoke('create-store', body: {...})
  → on 200: ref.invalidate(membershipsProvider) + activeStoreProvider.setStore(...) + context.go(AppRoutes.home)
  → on 402: redirect to /upgrade
  → on other error: snackbar with localized message
```

## 4. Decisions

### 4.1 One Edge Function per concern (not a single `ai-batch`)

Rejected unifying translate + describe into a single Edge Function. The two have different JSON Schemas, different prompt strategies, different write paths (translations table vs. `dishes.source_description`), and may end up with different quotas later (image generation will be its own thing too). Splitting keeps each function focused and easier to mock in tests.

### 4.2 Tier cap = 2 / 5 / unlimited locales per menu

Read directly from `docs/product-decisions.md §2`. Free = 2, Pro = 5, Growth = unlimited. Implemented in `translate-menu` as a count check before the LLM call. The `available_locales` includes the source locale, so Free's 2 means source + 1 translation.

### 4.3 Quota = 1 / 10 / 100 batch AI calls per store per month

Cumulative across translate + describe-expand. New table:

```sql
-- 20260425000002_ai_runs.sql
CREATE TABLE ai_runs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('translate','optimize')),
  target_locale text NULL,
  dish_count  integer NOT NULL DEFAULT 0,
  ms          integer NOT NULL DEFAULT 0,
  ok          boolean NOT NULL DEFAULT true,
  error       text NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ai_runs_store_month ON ai_runs (store_id, date_trunc('month', created_at));

ALTER TABLE ai_runs ENABLE ROW LEVEL SECURITY;

-- Owners + Managers can SELECT; Edge Functions write via service role.
CREATE POLICY ai_runs_member_read ON ai_runs FOR SELECT
  USING (store_id = ANY(public.user_store_ids()));
-- No INSERT/UPDATE/DELETE policies → only service role mutates.
```

Caps in code (`_shared/quotas.ts` constant):

```ts
export const AI_BATCH_QUOTA = { free: 1, pro: 10, growth: 100 } as const;
```

Tier resolution per call: `stores.tier`. Cap enforcement: `SELECT count(*) FROM ai_runs WHERE store_id = $1 AND created_at >= date_trunc('month', now())`. Fail-closed semantics — if the count succeeds and is ≥ cap, return 429 + a localized message. If the count query fails, fall through to the LLM call (don't block on infra hiccup).

### 4.4 Mock provider in CI

Both new Edge Functions follow Session 2's pattern: the provider factory's default is mock. Tests run against the mock; setting `MENURAY_LLM_PROVIDER=openai` + `OPENAI_API_KEY` in production env opts in to real OpenAI.

The mock provider returns a deterministic response (e.g. translated names = `[locale]_<source_name>`). Tests assert this shape — no real API calls in CI.

### 4.5 ai_runs as a separate table (not piggyback on parse_runs)

Rejected piggyback because:
- `parse_runs` has a `menu_id` column (parses are scoped to specific menu uploads); ai_runs is store-scoped.
- `parse_runs` has detailed status fields and `parse_inputs` linkage. ai_runs needs none of that.
- A merchant who burns parse quota shouldn't also burn AI quota.

The dedicated table keeps the two quota systems cleanly separable for product-tier tuning later.

### 4.6 `+ New store` is a tile not a FAB

Rejected FAB because the picker screen is a list — adding a FAB makes the cursor float over content. A bottom tile blends with the existing membership list and is more discoverable. The TierGate wraps the tile so non-Growth users see a visually-locked variant.

### 4.7 Source locale is fixed at store creation; no editor

Once `stores.source_locale` is set (S4 made it Growth-only via `create-store` Edge Function), there's no UI to change it. Translate-menu only adds *additional* locales. This is a deliberate constraint — re-parsing a menu in a different source language is the workaround.

### 4.8 Locale picker grows to 8 options

Adding Spanish, German, Chinese (the bidirectional case — a Chinese-source menu can translate to English; an English-source menu to Chinese), Vietnamese. The locale codes match the customer-view's `Locale` type which is open-ended (`type Locale = string`); we don't need to add a Postgres enum.

### 4.9 Auto-image toggle stays visible but disabled

Rejected hiding the toggle because the row position contributes to the screen's information architecture and removing it makes the layout look incomplete. The disabled state is a clear signal that the feature is on the roadmap.

## 5. JSON Schemas

### 5.1 translate-menu

```ts
const TRANSLATE_SCHEMA = {
  name: 'menu_translation',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['categories', 'dishes'],
    properties: {
      categories: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['id', 'name'],
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
          },
        },
      },
      dishes: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['id', 'name', 'description'],
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            description: { type: 'string' },
          },
        },
      },
    },
  },
};
```

### 5.2 ai-optimize (describe-expand)

```ts
const OPTIMIZE_SCHEMA = {
  name: 'menu_optimize',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['dishes'],
    properties: {
      dishes: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['id', 'description'],
          properties: {
            id: { type: 'string' },
            description: { type: 'string' },
          },
        },
      },
    },
  },
};
```

## 6. File tree

**New (backend):**
```
backend/supabase/migrations/20260425000002_ai_runs.sql
backend/supabase/functions/translate-menu/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md, test.ts}
backend/supabase/functions/ai-optimize/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md, test.ts}
backend/supabase/functions/_shared/quotas.ts
```

**New (merchant flutter):**
```
frontend/merchant/lib/features/ai/data/ai_repository.dart
frontend/merchant/lib/features/ai/ai_providers.dart
frontend/merchant/lib/features/store/data/store_creation_repository.dart
frontend/merchant/lib/features/store/presentation/widgets/new_store_sheet.dart
frontend/merchant/test/smoke/store_picker_screen_smoke_test.dart   (or extend the existing one)
```

**Modified (backend):** none after migration.

**Modified (merchant flutter):**
```
frontend/merchant/lib/features/ai/presentation/ai_optimize_screen.dart    (full wire-up)
frontend/merchant/lib/features/store/presentation/store_picker_screen.dart    (+ tile)
frontend/merchant/lib/router/app_router.dart                               (/ai/optimize/:menuId)
frontend/merchant/lib/l10n/app_en.arb                                      (+ 16 keys)
frontend/merchant/lib/l10n/app_zh.arb                                      (+ 16 keys)
frontend/merchant/test/smoke/ai_optimize_screen_smoke_test.dart            (extend)
```

**Modified (docs):**
```
docs/decisions.md                                                          (+ ADR-024)
docs/architecture.md                                                       (+ AI batch paragraph)
docs/roadmap.md                                                            (3 P0 rows flipped)
CLAUDE.md                                                                  (Active work + tests)
```

Total: ~13 new + 8 modified.

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| OpenAI gpt-4o-mini batch translation hits 30s+ for menus with 100+ dishes | Document the soft limit; chunk in orchestrator if dish count > 80. P1 follow-up: async + polling. |
| LLM produces invalid locale-coded strings (English when target is French) | Strict JSON Schema doesn't catch wrong-language content. Acceptance: trust the model; add a post-flight regex sanity check ("if French target, ≥50% of names contain a French diacritic OR common French word") — log a warning to ai_runs.error but accept the write. |
| Mock provider's deterministic stub doesn't exercise prompt logic | Tests cover the *interface* (schema validation + writes) not the prompt quality. Real-world prompt quality is verified by manual smoke against OpenAI. |
| Race: two simultaneous translate calls for the same menu both write to the same locale → upsert conflict | `dish_translations.UNIQUE(dish_id, locale)` enforces at the DB level; the second upsert's ON CONFLICT DO UPDATE wins. Acceptable. |
| Multi-store creation succeeds but `activeStoreProvider.setStore` fails (e.g. local pref write blocked) | UI still navigates to home; on next app start the new store is in the membership list and pickable. Acceptable degradation. |
| Translate over-cap returns 402 *after* the LLM call has run | Tier cap check happens BEFORE the LLM call (orchestrator step 1). No wasted spend. |
| `ai_runs` quota query fails (DB hiccup) → blocks the call | Fail-open per §4.3 — the LLM call proceeds. We log "quota check failed" to console. The store is over-quota by at most one extra call, which is fine. |

## 8. Success criteria

- `cd backend/supabase && npx supabase db reset` → ai_runs table exists; can insert via service role; user-as-Owner can SELECT only their store's rows.
- `cd backend/supabase/functions/translate-menu && deno test --allow-env --allow-net` → 5 tests green.
- `cd backend/supabase/functions/ai-optimize && deno test --allow-env --allow-net` → 4 tests green.
- `cd frontend/merchant && flutter analyze` → clean.
- `cd frontend/merchant && flutter test` → all green; new store-picker tests + extended ai_optimize_screen test pass.
- `cd frontend/customer && pnpm check && pnpm test` → all clean (no customer changes; sanity check).
- Manual: log in as Growth user → AI Optimize screen with multi-lang on + ja → Start → ~5 sec wait → success snackbar → reload customer view → `?lang=ja` shows Japanese names + descriptions.
- Manual: AI Optimize with desc-expand on → Start → ~5 sec → reload editor → first dish's `source_description` reads markedly better.
- Manual: Store Picker → tap "+ New store" → form → Save → land on home of new store; old store still selectable.
- Manual (Free user): same flow → "+ New store" tile shows lock icon + opens `/upgrade`.
- ADR-024 rendered cleanly; CLAUDE.md "Active work" reflects S7.
