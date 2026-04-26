# Session 8 — Merchant Editorial Polish — Implementation Plan

> Spec: `docs/superpowers/specs/2026-04-26-merchant-polish-design.md`. Three independent items; execute in order: smallest blast radius first.

---

## Phase 1 — Pro+ wordmark gating (S)

- [ ] 1.1 In `frontend/merchant/lib/features/publish/presentation/published_screen.dart`:
  - `_QrShareCard` constructor adds `required this.showWordmark`.
  - The `Text('menuray.com', …)` block + the preceding `SizedBox(height: 12)` are conditionally rendered only when `showWordmark` is true.
  - `_PublishedBodyState.build()` adds `final tier = ref.watch(currentTierProvider).asData?.value ?? Tier.free;` near the top, then passes `showWordmark: tier == Tier.free` into `_QrShareCard`.
  - Import `Tier` + `currentTierProvider` from `features/billing/billing_providers.dart` and `features/billing/tier.dart`.
- [ ] 1.2 Extend `test/smoke/published_screen_smoke_test.dart` with two cases: Free tier still renders the wordmark inside the offstage card; Pro tier omits it. Use `find.text('menuray.com')` and check the count.
- [ ] 1.3 Verify: `flutter analyze` clean + the published_screen test file green.

## Phase 2 — Time-slot persistence (S)

- [ ] 2.1 In `frontend/merchant/lib/features/home/menu_repository.dart`:
  - Extend `updateMenu(...)` signature with `String? timeSlot`. If non-null, include `time_slot: timeSlot` in the patch map.
- [ ] 2.2 In `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart`:
  - `_TimeSlotSection` `onChanged` already updates a local `_timeSlotOverride`; extend it to also call `ref.read(menuRepositoryProvider).updateMenu(menuId: ..., timeSlot: ...)` and `invalidate(menuByIdProvider(...))`.
  - Map `MenuTimeSlot` enum value → API string (`MenuTimeSlot.lunch.toApiString()` or inline switch). Use `'all_day' | 'lunch' | 'dinner' | 'seasonal'` to match the CHECK constraint.
  - On error: show snackbar with `menuTimeSlotSaveFailed`; rollback local state to the previously saved value.
  - On success: optionally show snackbar with `menuTimeSlotSavedSnackbar` (or skip — radio movement is its own confirmation).
- [ ] 2.3 Extend `test/smoke/menu_management_screen_smoke_test.dart`: tap the Lunch radio → assert a fake repo recorded `updateMenu` was called with `timeSlot: 'lunch'`.
- [ ] 2.4 Verify.

## Phase 3 — Menu duplication (M)

- [ ] 3.1 Add `backend/supabase/migrations/20260426000001_duplicate_menu.sql` per spec §4.1.
- [ ] 3.2 Run `npx supabase db reset` (or `db diff`) locally if available; otherwise rely on PgTAP test for verification. (We may not have a local supabase running — fall back to PgTAP-only verification.)
- [ ] 3.3 Extend `backend/supabase/tests/billing_quotas.sql` with cases for `duplicate_menu`:
  - happy path → owner duplicates a 1-category 2-dish menu; assert new menu has `status='draft'`, `slug IS NULL`, dish count = 2, dish_translations count copied if any.
  - cap path → free-tier seed user attempts to duplicate when they're already at 1 menu cap; assert `feature_not_in_subscribed_plan` raised.
  - role path → staff user attempts to duplicate; assert `insufficient_privilege`.
- [ ] 3.4 In `frontend/merchant/lib/features/home/menu_repository.dart`:
  - Add `duplicateMenu(menuId)` calling `_client.rpc('duplicate_menu', params: {'p_source_menu_id': menuId})`. Map `PostgrestException` containing `feature_not_in_subscribed_plan` to a new `MenuCapExceededError`.
  - Define `class MenuCapExceededError implements Exception {}` either inline or in a small `errors.dart`.
- [ ] 3.5 In `frontend/merchant/lib/features/home/presentation/home_screen.dart`:
  - The `_MenuList` builder already passes a `MenuCard` per menu. Add an `onMore` callback that opens a `showModalBottomSheet` containing one `ListTile` for "Duplicate menu". On tap → call repo + handle errors per spec.
  - On success: `ref.invalidate(menusProvider)` then `context.go('/manage/menu/$newId')`.
  - On `MenuCapExceededError`: snackbar with "Upgrade" action linking to `/upgrade`.
  - Use the existing `aiOverQuotaUpgradeAction` key for the snackbar action (already localized) — no new key needed there.
- [ ] 3.6 Extend `test/smoke/home_screen_smoke_test.dart`: assert tapping the menu-card more icon opens a sheet with "Duplicate menu" text.

## Phase 4 — i18n + remaining tests

- [ ] 4.1 Add 6 keys to `app_en.arb` + `app_zh.arb` (per spec §1):
  - `menuOverflowDuplicate`
  - `menuDuplicateSuccess`
  - `menuCapExceededSnackbar`
  - `menuTimeSlotSavedSnackbar`
  - `menuTimeSlotSaveFailed`
  - (`menuCapUpgradeAction` — actually we'll reuse `aiOverQuotaUpgradeAction` from S7; only 5 new keys then)
- [ ] 4.2 Run `flutter gen-l10n` (auto-runs on `flutter test`).
- [ ] 4.3 Extend any test that checks total i18n key count if such a test exists.

## Phase 5 — Docs

- [ ] 5.1 Append ADR-025 to `docs/decisions.md`. Sections: Context, Decision, Alternatives considered, Consequences, References.
- [ ] 5.2 Update `docs/architecture.md` with a short paragraph on the merchant editorial polish (3 items).
- [ ] 5.3 Update `docs/roadmap.md`: flip three rows to ✅ — sold-out persistence (already done, document via S8 confirmation), time-slot UI persistence, menu duplication. Add Session 8 row to the Session map. Update test totals.
- [ ] 5.4 Update `CLAUDE.md` with S8 block + test totals.

## Phase 6 — Full verify

- [ ] 6.1 `flutter analyze` clean.
- [ ] 6.2 `flutter test` all green; capture new total.
- [ ] 6.3 `pnpm check && pnpm test` clean (no customer changes; sanity).
- [ ] 6.4 PgTAP duplicate-menu cases green (or document as deferred if local Supabase isn't available).

---

## Commit plan

1. `feat(publish): Pro+ tier removes menuray.com wordmark from share PNG`
2. `feat(manage): persist menus.time_slot when radio changes`
3. `feat(backend): duplicate_menu SECURITY DEFINER RPC`
4. `feat(home): menu-card overflow → Duplicate menu`
5. `feat(i18n): 5 keys for menu duplicate + time-slot save (en + zh)`
6. `test: smoke updates for wordmark / time-slot / overflow duplicate`
7. `test(backend): PgTAP cases for duplicate_menu (happy + cap + role)`
8. `docs: ADR-025 + architecture + roadmap`
9. `docs: session 8 shipped (CLAUDE.md)`
