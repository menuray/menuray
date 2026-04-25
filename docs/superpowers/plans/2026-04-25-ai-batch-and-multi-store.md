# Session 7 — AI Batch + Multi-store Button — Implementation Plan

> Spec: `docs/superpowers/specs/2026-04-25-ai-batch-and-multi-store-design.md`. Subagent-driven where useful; sequential where each phase blocks the next.

---

## File structure

**New (backend):**
```
backend/supabase/migrations/20260425000002_ai_runs.sql
backend/supabase/functions/_shared/quotas.ts
backend/supabase/functions/translate-menu/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md, test.ts}
backend/supabase/functions/ai-optimize/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md, test.ts}
backend/supabase/functions/_shared/providers/openai_translate.ts
backend/supabase/functions/_shared/providers/openai_optimize.ts
backend/supabase/functions/_shared/providers/mock_translate.ts
backend/supabase/functions/_shared/providers/mock_optimize.ts
```

**Modified (backend):**
```
backend/supabase/functions/_shared/providers/factory.ts   (+ getTranslateProvider, getOptimizeProvider)
backend/supabase/functions/_shared/providers/types.ts     (+ TranslateProvider, OptimizeProvider interfaces)
```

**New (merchant flutter):**
```
frontend/merchant/lib/features/ai/data/ai_repository.dart
frontend/merchant/lib/features/ai/ai_providers.dart
frontend/merchant/lib/features/store/data/store_creation_repository.dart
frontend/merchant/lib/features/store/store_creation_providers.dart
frontend/merchant/test/unit/ai_repository_test.dart
frontend/merchant/test/unit/store_creation_repository_test.dart
```

**Modified (merchant flutter):**
```
frontend/merchant/lib/features/ai/presentation/ai_optimize_screen.dart
frontend/merchant/lib/features/store/presentation/store_picker_screen.dart
frontend/merchant/lib/router/app_router.dart           (/ai/optimize → /ai/optimize/:menuId)
frontend/merchant/lib/l10n/app_en.arb                  (+ ~16 keys)
frontend/merchant/lib/l10n/app_zh.arb                  (+ ~16 keys)
frontend/merchant/test/smoke/ai_optimize_screen_smoke_test.dart
frontend/merchant/test/smoke/store_picker_screen_smoke_test.dart
```

**Modified (docs):**
```
docs/decisions.md                                       (+ ADR-024)
docs/architecture.md
docs/roadmap.md
CLAUDE.md
```

---

## Phase 1 — Backend foundations

- [ ] **1.1** Add migration `20260425000002_ai_runs.sql` — `ai_runs` table + RLS policy + index per spec §4.3.
- [ ] **1.2** Add `_shared/quotas.ts` exporting `AI_BATCH_QUOTA = { free: 1, pro: 10, growth: 100 }` + `LOCALE_CAP = { free: 2, pro: 5, growth: Infinity }`.
- [ ] **1.3** Extend `_shared/providers/types.ts`: add `TranslateProvider` interface (`translate(menu: TranslateInput, targetLocale): Promise<TranslateOutput>`) and `OptimizeProvider` interface (`optimize(dishes: OptimizeInput[]): Promise<OptimizeOutput>`).
- [ ] **1.4** Add mock implementations: `_shared/providers/mock_translate.ts` (deterministic prefix), `_shared/providers/mock_optimize.ts` (appends "(rewritten)" to descriptions).
- [ ] **1.5** Add OpenAI implementations: `_shared/providers/openai_translate.ts` (uses chatCompletion + strict JSON Schema, follows `openai_structure.ts` pattern), `_shared/providers/openai_optimize.ts`.
- [ ] **1.6** Extend `_shared/providers/factory.ts`: add `getTranslateProvider()` + `getOptimizeProvider()` reading `MENURAY_LLM_PROVIDER` env (mock default).

## Phase 2 — `translate-menu` Edge Function

- [ ] **2.1** Create `translate-menu/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md}`:
  - `index.ts`: routing, auth, JSON body parse, tier-cap check via `LOCALE_CAP`, quota check via `AI_BATCH_QUOTA` against `ai_runs`, delegate to orchestrator, write `ai_runs` row, return `{translatedDishCount, translatedCategoryCount, availableLocales}`.
  - `orchestrator.ts`: load menu + categories + dishes → call `translateProvider.translate()` → upsert `category_translations` + `dish_translations` (single RPC or batched insert) → bump `menus.available_locales`.
  - `schema.ts`: the JSON Schema constants for response_format.
  - `deno.json`: copy from create-store/.
  - `README.md`: smoke runbook.
- [ ] **2.2** Create `translate-menu/test.ts` covering: 401 missing auth, 403 over locale cap, 429 over monthly quota, 200 happy path with mock provider asserts upsert calls + ai_runs insert + available_locales update, 400 malformed JSON.

## Phase 3 — `ai-optimize` Edge Function

- [ ] **3.1** Create `ai-optimize/{index.ts, orchestrator.ts, schema.ts, deno.json, README.md}` mirroring Phase 2. No locale-cap check (operates on source_description). Quota check shared via `ai_runs.kind='optimize'`.
- [ ] **3.2** Create `ai-optimize/test.ts`: 401 missing auth, 429 over quota, 200 happy path asserts dish updates + ai_runs insert, 400 malformed JSON.

## Phase 4 — Flutter wiring (translate + optimize)

- [ ] **4.1** Create `lib/features/ai/data/ai_repository.dart`:
  ```dart
  class AiRepository {
    AiRepository(this._client);
    final SupabaseClient _client;
    Future<TranslateResult> translateMenu(String menuId, String targetLocale) async { … }
    Future<OptimizeResult> optimizeDescriptions(String menuId) async { … }
  }
  ```
  Typed result classes; on 402/429 throw a typed `AiQuotaError`.
- [ ] **4.2** Create `lib/features/ai/ai_providers.dart` with `aiRepositoryProvider`.
- [ ] **4.3** Modify `app_router.dart`: `/ai/optimize/:menuId`. Update entry callers (search for `AppRoutes.organize` references that currently navigate from preview / publish flow — none today; just register the new route).
- [ ] **4.4** Rewire `ai_optimize_screen.dart`:
  - Convert to `ConsumerStatefulWidget`.
  - Take `menuId` as constructor arg from the route.
  - Disable the "auto-image" toggle (`onChanged: null`) + suffix subtitle "(coming soon)".
  - Expand `_langOptions` from 4 → 8 locales (en, zh-CN, ja, ko, fr, es, de, vi).
  - `_onStart` becomes async: shows a `_RunDialog` with progress text; calls `optimizeDescriptions` then `translateMenu` per toggle state; on success closes dialog + snackbar + `context.go('/manage/$menuId')`; on error closes + snackbar.
  - Use `AiQuotaError` to route to `/upgrade` with an explanatory snackbar.

## Phase 5 — Multi-store button

- [ ] **5.1** Create `lib/features/store/data/store_creation_repository.dart` with `createStore(name, currency, sourceLocale)` invoking `'create-store'`. On 403 throw `MultiStoreRequiresGrowthError`.
- [ ] **5.2** Create `store_creation_providers.dart` with `storeCreationRepositoryProvider`.
- [ ] **5.3** Modify `store_picker_screen.dart`:
  - Append a `_NewStoreTile` after the membership list (using `Column` not just ListView so the tile sits naturally below).
  - The tile listens to `currentTierProvider`; on Growth tap → `showModalBottomSheet → _NewStoreSheet`; on non-Growth tap → `context.go(AppRoutes.upgrade)`.
  - `_NewStoreSheet`: stateful, three TextFormFields (name required + validator, currency 'USD' default, sourceLocale 'en' default), Save button calls repository, on success `ref.invalidate(membershipsProvider)`, sets active store, navigates to home.
  - Disabled visual: grey + lock icon + "Growth-only" pill (no separate locked-state text needed; the tap routes anyway).

## Phase 6 — i18n + Flutter tests

- [ ] **6.1** Add ~16 keys to `app_en.arb` + `app_zh.arb`:
  - `aiOptimizeAutoImageSubtitleSuffix` (e.g. " (coming soon)")
  - `aiOptimizeLangSpanish`, `aiOptimizeLangGerman`, `aiOptimizeLangChinese`, `aiOptimizeLangVietnamese`
  - `aiRunningTranslating`, `aiRunningOptimizing`, `aiRunSuccess`, `aiOverQuotaSnackbar`, `aiOverLocaleCapSnackbar`
  - `storePickerNewStore`, `storePickerNewStoreGrowthOnly`
  - `storeFormName`, `storeFormCurrency`, `storeFormSourceLocale`, `storeFormCreate`, `storeFormCreating`, `storeCreateSuccess`, `storeCreateGenericError`
- [ ] **6.2** Extend `test/smoke/ai_optimize_screen_smoke_test.dart`: assert auto-image toggle is disabled; assert 8-option locale dropdown.
- [ ] **6.3** Create / extend `test/smoke/store_picker_screen_smoke_test.dart`: Growth tier renders "+ New store" tile; Free tier renders disabled variant.
- [ ] **6.4** Create unit tests for the two repositories using fake `SupabaseClient.functions.invoke`.

## Phase 7 — Verify + docs

- [ ] **7.1** `flutter analyze` clean; `flutter test` all green.
- [ ] **7.2** `pnpm check` clean; `pnpm test` clean.
- [ ] **7.3** Deno tests for both new functions green.
- [ ] **7.4** ADR-024 added to `docs/decisions.md`.
- [ ] **7.5** `docs/architecture.md` paragraph; `docs/roadmap.md` 3 rows flipped.
- [ ] **7.6** `CLAUDE.md` Active work + test totals updated.

---

## Commit plan

1. `feat(backend): ai_runs table + AI batch quota constants`
2. `feat(backend): TranslateProvider + OptimizeProvider interfaces + mock + openai`
3. `feat(backend): translate-menu Edge Function + 5 Deno tests`
4. `feat(backend): ai-optimize Edge Function + 4 Deno tests`
5. `feat(ai): AiRepository + providers`
6. `feat(ai): ai_optimize_screen wired to translate-menu + ai-optimize`
7. `feat(store): + New store tile + new-store sheet on store_picker`
8. `feat(i18n): 16 keys for AI batch + multi-store (en + zh)`
9. `test(merchant): AiRepository + StoreCreationRepository + smoke updates`
10. `docs: ADR-024 + architecture + roadmap`
11. `docs: session 7 shipped (CLAUDE.md)`
