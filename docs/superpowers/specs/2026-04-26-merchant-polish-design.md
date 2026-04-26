# Session 8 — Merchant Editorial Polish — Design

Date: 2026-04-26
Scope: Three P1 polish items that close visible gaps in the merchant editorial flow without adding new dependency surface — Pro+ tier removes the `menuray.com` wordmark from the share PNG (S6 polish item), time-slot selection on `MenuManagementScreen` actually persists to the DB (currently local-only), and merchants can duplicate a menu from the Home screen via a 3-dot overflow on the menu card. Sold-out toggle persistence and customer host config were already shipped in earlier sessions and are not included.

## 1. Goal & Scope

After Session 8 ships:

1. **Pro+ wordmark removal** — A Pro or Growth merchant who taps "Share QR image" on `PublishedScreen` gets a brand-styled PNG without the small `menuray.com` wordmark at the bottom. Free tier still gets the wordmark — which is the intent per `docs/product-decisions.md §2` ("Custom branding on QR page" is Pro+).
2. **Time-slot persistence** — Tapping any of the four radio buttons (Lunch / Dinner / All-day / Seasonal) on `MenuManagementScreen` triggers a Supabase update that flips `menus.time_slot`. Reload survives. The setting drives nothing on the customer side yet (P2 deferred), but the data is correct.
3. **Menu duplication** — A merchant taps the existing 3-dot overflow on a menu card on `HomeScreen` and picks "Duplicate". The app calls a new SECURITY DEFINER `duplicate_menu` RPC that deep-clones the menu (categories + dishes + dish translations) into a draft (`status='draft'`) with a fresh `slug=null`, returns the new menu id, and the home list refreshes.

**In scope**

- **Backend**:
  - New migration `20260426000001_duplicate_menu.sql` adding a SECURITY DEFINER `duplicate_menu(p_source_menu_id uuid)` RPC. Validates caller is a member with role IN ('owner', 'manager') of the source store via `public.user_store_role`. Inserts a new `menus` row with `status='draft'`, `slug=null`, `name = source.name + ' (copy)'`. Inserts category rows with new ids preserving position + source_name. Inserts dish rows with new category mapping. Inserts dish_translations + category_translations rows pinned to the new ids. Updates `assert_menu_under_cap` enforcement is automatic via the existing trigger / hard-gate (S4).
  - Tier menu-cap enforcement: `duplicate_menu` runs `assert_menu_under_cap(store_id)` at the top so a Free user with 1 menu can't dupe past the cap. The function raises `feature_not_in_subscribed_plan` (matching S4 convention).
- **Flutter merchant**:
  - `MenuRepository.updateMenu` extended with optional `timeSlot` parameter (string per the existing `MenuTimeSlot.toApiString()` if it exists, else write helper). Mapper trip-checks the value.
  - `MenuRepository.duplicateMenu(menuId)` invokes the new RPC; returns the new menu id. Throws `MenuCapExceededError` on `feature_not_in_subscribed_plan` (parses error code from `PostgrestException`).
  - `MenuManagementScreen`'s `_TimeSlotSection` `onChanged` now calls `setTimeSlot(menuId, value)` (new method routing to `updateMenu`) and invalidates `menuByIdProvider(menuId)`. Optimistic local state still drives the UI snap so the radio doesn't lag the network round-trip.
  - `HomeScreen`'s `_MenuList` wires the `MenuCard.onMore` callback (currently unwired) to a bottom sheet with one option for now: "Duplicate menu". Tap → call `duplicateMenu`, refresh `menusProvider`, navigate to `/manage/menu/<newId>` via `context.go(...)`. On `MenuCapExceededError` show a snackbar with an "Upgrade" action linking to `/upgrade`.
  - `_QrShareCard` (offstage capture target on `PublishedScreen`) takes a new `showWordmark: bool` parameter; the parent reads `currentTierProvider` and passes `showWordmark = (tier == Tier.free)`. The on-screen `_QrCard` is unchanged (no wordmark there).
- **i18n**:
  - Approximate count: 6 keys (en + zh).
    - `menuOverflowDuplicate` ("Duplicate menu" / "复制菜单")
    - `menuDuplicateSuccess` ("Menu duplicated — opening copy" / "已复制菜单")
    - `menuCapExceededSnackbar` ("Menu cap reached on your tier — upgrade for more" / "已达本套餐菜单数上限")
    - `menuCapUpgradeAction` ("Upgrade" / "升级")
    - `menuTimeSlotSavedSnackbar` ("Time slot saved" / "时段已保存")
    - `menuTimeSlotSaveFailed` ("Could not save time slot" / "时段保存失败")
- **Tests**:
  - PgTAP: extend `backend/supabase/tests/billing_quotas.sql` with cases for `duplicate_menu` — owner success, manager success, staff forbidden, free-tier 2nd-menu forbidden via cap, dish-count copied correctly.
  - Flutter unit: `test/unit/menu_repository_duplicate_test.dart` mocks the SupabaseClient.functions.invoke / from chain isn't needed — `rpc` is the interface. Test PostgrestException → MenuCapExceededError mapping.
  - Flutter smoke: extend `test/smoke/menu_management_screen_smoke_test.dart` to assert tapping the Lunch radio invokes `setTimeSlot('lunch')` on a fake repo. Extend `test/smoke/home_screen_smoke_test.dart` to assert the overflow callback is wired (tap the 3-dot icon → bottom sheet appears with "Duplicate menu").
  - Flutter smoke: extend `test/smoke/published_screen_smoke_test.dart` with a Pro-tier override → assert `_QrShareCard` does NOT contain `menuray.com`. Free-tier path keeps existing assertion.
- **Docs**: ADR-025 explaining `duplicate_menu` RPC choice + tier-aware share artifact. CLAUDE.md "Active work" S8 block. `docs/roadmap.md` 3 rows flipped.

**Out of scope (deferred)**

- **Customer-side time-slot filtering / display** — `time_slot` is data that can drive a customer-view filter ("show only dinner") later. Not in this session — would need design + UX research on how merchants' diners actually use this.
- **Menu duplication preserving images** — `dishes.image_url` references a path under the `dish-images` bucket. The RPC copies the URL string; we do **not** copy the underlying bucket object. If the source menu is deleted later, the duplicated menu's images go 404. Acceptable trade-off; documented in the ADR.
- **Long-press gesture on the menu card** — overflow menu (3-dot) is the primary affordance. Long-press is a native-only iOS convention that's awkward on web; we stay on the explicit button.
- **Sold-out toggle persistence** — already shipped (`mark_dish_soldout` RPC + `MenuRepository.setDishSoldOut` from S3).
- **Multi-menu UX hints on the customer view** — e.g. showing "Lunch menu" badge to diners. Customer view fetches `time_slot` already (S1) but doesn't render it.
- **Bulk duplication** ("duplicate this menu N times") — single-menu duplicate only.
- **Cross-store duplication** — the RPC requires the caller to be a member of the source store and writes to the same store. Cross-store transfer is a different feature.
- **Duplicating into a non-draft state** — every duplicate is `status='draft'`. The merchant publishes manually if they want it live.

## 2. Context

- `menus.time_slot text NOT NULL DEFAULT 'all_day' CHECK (time_slot IN ('all_day','lunch','dinner','seasonal'))` from `20260420000001_init_schema.sql:36–37`. The four-value enum is fixed.
- `menu_management_screen.dart:539–595` already renders the radio list via `_TimeSlotSection`; only the persistence wire is missing.
- `MenuRepository.updateMenu` (`menu_repository.dart:74–84`) currently accepts `templateId` and `themeOverrides` — we add a third optional `timeSlot` so the API stays one method (no separate `setTimeSlot`).
- `MenuCard.onMore` callback exists in the widget but `_MenuList` in `home_screen.dart` doesn't wire it. Adding the wiring is the smallest change to get the duplication menu surface.
- `currentTierProvider` (`billing/billing_providers.dart:8–13`) reads `currentStoreProvider.future` and resolves the active store's denormalised tier. `PublishedScreen` already watches `currentStoreProvider` so the additional watch is one line.
- `duplicate_menu` RPC pattern follows the S3 `mark_dish_soldout` SECURITY DEFINER + `user_store_role` gate. The S4 `assert_menu_under_cap(p_store_id uuid)` SECURITY DEFINER function already raises `feature_not_in_subscribed_plan` when the menu count meets the tier ceiling.
- Caps: Free 1 menu, Pro 5, Growth unlimited. Duplication that pushes count past the cap fails before any inserts happen.

## 3. Decisions

### 3.1 `duplicate_menu` is a single transactional RPC (not a JS Edge Function)

Pros: Keeps the deep-clone atomic; rolls back the half-cloned state if any step fails. Pros: avoids JWT round-trip + service-role client setup that an Edge Function would need. Pros: leverages the existing role-gate helper.
Cons: SQL-heavy; harder to evolve if duplication later needs LLM enrichment (e.g. "duplicate this menu and translate to en"). Acceptable for this session — when duplication-with-side-effects ships, it can wrap the RPC.

### 3.2 Duplicate result is always `status='draft'`, `slug=null`

A duplicated menu has no published URL until the merchant chooses to publish. Forcing draft prevents accidental cross-pollination (two QR codes pointing at the same content). The merchant manually publishes via the existing flow.

### 3.3 Duplicate copies image URL strings, not bucket objects

A draft menu pointing at the same `dish-images/<storeId>/<uuid>.jpg` keys as the source. No bucket clone. Documented as a known limitation. Justification: bucket-side cloning is a multi-step async pipeline (download → re-upload with new key → update URL); the URL-copy approach is simple, atomic, and acceptable since deleting the source menu is rare and recoverable (re-upload the image).

### 3.4 `updateMenu(timeSlot:)` over a separate `setTimeSlot`

One API surface; reuses the same PATCH; keeps the repository tight. The optimistic local-state in `_TimeSlotSection` (no UI lag) stays as a screen-local concern.

### 3.5 Wordmark gating on the share PNG only, not the on-screen QR card

The on-screen `_QrCard` doesn't have a wordmark; only the offstage `_QrShareCard` capture target does. Pass a `showWordmark` bool down — single-purpose, no cascading reads. The Free → Pro toggle on a paid user updates the share artifact starting on the next publish-flow visit (provider invalidation is automatic).

### 3.6 Menu-cap enforcement on duplicate

Duplicating a menu IS creating a menu; the existing `assert_menu_under_cap` is the right gate. The RPC calls it as the first action; if the cap is hit it raises `feature_not_in_subscribed_plan` and no inserts happen. The Flutter side maps this to `MenuCapExceededError` and routes to `/upgrade` like other tier failures.

### 3.7 Overflow menu on `MenuCard` only carries "Duplicate" today

Single option keeps the bottom sheet trivial. Future siblings (Archive, Delete, Export JSON) can drop in. Title + one ListTile + cancel; no further design.

## 4. Schemas / SQL

### 4.1 `duplicate_menu` migration

```sql
-- 20260426000001_duplicate_menu.sql

CREATE OR REPLACE FUNCTION public.duplicate_menu(p_source_menu_id uuid)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_store_id   uuid;
  v_role       text;
  v_new_menu   uuid;
  v_old_cat    record;
  v_new_cat    uuid;
  v_old_dish   record;
  v_new_dish   uuid;
  cat_map      jsonb := '{}'::jsonb;
  dish_map     jsonb := '{}'::jsonb;
BEGIN
  SELECT store_id INTO v_store_id FROM menus WHERE id = p_source_menu_id;
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'menu_not_found' USING ERRCODE = 'no_data_found';
  END IF;

  v_role := public.user_store_role(v_store_id);
  IF v_role IS NULL OR v_role NOT IN ('owner','manager') THEN
    RAISE EXCEPTION 'insufficient_role' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Tier menu-cap gate (S4 convention).
  PERFORM public.assert_menu_under_cap(v_store_id);

  -- Clone the menu row → draft, slug NULL, suffix " (copy)" on name.
  INSERT INTO menus (
    store_id, name, source_locale, available_locales,
    status, currency, time_slot, time_slot_description,
    cover_image_url, template_id, theme_overrides
  )
  SELECT
    store_id, name || ' (copy)', source_locale, available_locales,
    'draft', currency, time_slot, time_slot_description,
    cover_image_url, template_id, theme_overrides
  FROM menus WHERE id = p_source_menu_id
  RETURNING id INTO v_new_menu;

  -- Clone categories, building old→new id map.
  FOR v_old_cat IN
    SELECT * FROM categories WHERE menu_id = p_source_menu_id ORDER BY position
  LOOP
    INSERT INTO categories (store_id, menu_id, source_name, position)
    VALUES (v_old_cat.store_id, v_new_menu, v_old_cat.source_name, v_old_cat.position)
    RETURNING id INTO v_new_cat;
    cat_map := cat_map || jsonb_build_object(v_old_cat.id::text, v_new_cat::text);
  END LOOP;

  -- Clone dishes via the cat_map.
  FOR v_old_dish IN
    SELECT * FROM dishes WHERE menu_id = p_source_menu_id
  LOOP
    INSERT INTO dishes (
      store_id, menu_id, category_id, source_name, source_description,
      price, position, spice_level, confidence,
      is_signature, is_recommended, is_vegetarian, allergens,
      sold_out, image_url
    )
    VALUES (
      v_old_dish.store_id, v_new_menu,
      (cat_map->>(v_old_dish.category_id::text))::uuid,
      v_old_dish.source_name, v_old_dish.source_description,
      v_old_dish.price, v_old_dish.position,
      v_old_dish.spice_level, v_old_dish.confidence,
      v_old_dish.is_signature, v_old_dish.is_recommended, v_old_dish.is_vegetarian, v_old_dish.allergens,
      false,  -- new dishes start NOT sold out
      v_old_dish.image_url
    )
    RETURNING id INTO v_new_dish;
    dish_map := dish_map || jsonb_build_object(v_old_dish.id::text, v_new_dish::text);
  END LOOP;

  -- Clone category_translations.
  INSERT INTO category_translations (category_id, store_id, locale, name)
  SELECT
    (cat_map->>(category_id::text))::uuid,
    store_id, locale, name
  FROM category_translations
  WHERE category_id IN (SELECT id FROM categories WHERE menu_id = p_source_menu_id);

  -- Clone dish_translations.
  INSERT INTO dish_translations (dish_id, store_id, locale, name, description)
  SELECT
    (dish_map->>(dish_id::text))::uuid,
    store_id, locale, name, description
  FROM dish_translations
  WHERE dish_id IN (SELECT id FROM dishes WHERE menu_id = p_source_menu_id);

  RETURN v_new_menu;
END;
$$;

GRANT EXECUTE ON FUNCTION public.duplicate_menu(uuid) TO authenticated;
```

Notes:
- The CHECK constraint on `dishes.confidence` etc. is satisfied because we copy verbatim.
- `slug` defaults to NULL on insert (per init schema's column definition).
- `created_at` / `updated_at` get fresh timestamps via the column DEFAULT and the existing `touch_updated_at` trigger.
- Uses jsonb maps for the old→new id translation since plpgsql doesn't have a native dict type. Acceptable for menus up to ~hundreds of categories + dishes.

### 4.2 Flutter `MenuRepository` extension

```dart
class MenuRepository {
  // existing constructor + fields

  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
    String? timeSlot,  // NEW — one of 'all_day' | 'lunch' | 'dinner' | 'seasonal'
  }) async {
    final patch = <String, dynamic>{};
    if (templateId != null) patch['template_id'] = templateId;
    if (themeOverrides != null) patch['theme_overrides'] = themeOverrides;
    if (timeSlot != null) patch['time_slot'] = timeSlot;
    if (patch.isEmpty) return;
    await _client.from('menus').update(patch).eq('id', menuId);
  }

  Future<String> duplicateMenu(String menuId) async {
    try {
      final res = await _client.rpc(
        'duplicate_menu',
        params: {'p_source_menu_id': menuId},
      );
      if (res is String) return res;
      throw StateError('duplicate_menu returned non-string: $res');
    } on PostgrestException catch (e) {
      // Tier cap raises feature_not_in_subscribed_plan from assert_menu_under_cap.
      if (e.message.contains('feature_not_in_subscribed_plan') ||
          (e.code != null && e.code == 'P0001' && e.message.contains('menu'))) {
        throw const MenuCapExceededError();
      }
      rethrow;
    }
  }
}
```

### 4.3 `_QrShareCard` tier gating

```dart
// in _PublishedBodyState.build():
final tier = ref.watch(currentTierProvider).asData?.value ?? Tier.free;
final showWordmark = tier == Tier.free;
// ...
Offstage(
  offstage: true,
  child: RepaintBoundary(
    key: _shareCardKey,
    child: _QrShareCard(
      url: _url,
      storeName: storeName,
      scanCaption: l.publishedScanCaption,
      showWordmark: showWordmark,  // NEW
    ),
  ),
)

// _QrShareCard: only render the wordmark Text when showWordmark is true.
```

## 5. File tree

**New (backend):**
```
backend/supabase/migrations/20260426000001_duplicate_menu.sql
```

**Modified (backend):**
```
backend/supabase/tests/billing_quotas.sql      (extend with duplicate_menu cases)
```

**New (merchant flutter):**
```
frontend/merchant/test/unit/duplicate_menu_test.dart   (or extend mappers_test if simpler)
```

**Modified (merchant flutter):**
```
frontend/merchant/lib/features/home/menu_repository.dart           (+ duplicateMenu, + timeSlot param)
frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart   (call setTimeSlot on radio)
frontend/merchant/lib/features/home/presentation/home_screen.dart  (wire onMore)
frontend/merchant/lib/features/publish/presentation/published_screen.dart   (showWordmark gate)
frontend/merchant/lib/l10n/app_en.arb                              (+ ~6 keys)
frontend/merchant/lib/l10n/app_zh.arb                              (+ ~6 keys)
frontend/merchant/test/smoke/menu_management_screen_smoke_test.dart  (extend)
frontend/merchant/test/smoke/home_screen_smoke_test.dart           (extend)
frontend/merchant/test/smoke/published_screen_smoke_test.dart      (extend with Pro-tier case)
```

**Modified (docs):**
```
docs/decisions.md      (+ ADR-025)
docs/architecture.md   (+ paragraph)
docs/roadmap.md        (3 P1 rows flipped)
CLAUDE.md              (S8 block + test totals)
```

Total: 1 new backend migration, 1 new test file, 9 modifications.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `duplicate_menu` RPC executes outside an explicit transaction | Postgres wraps each function call in an implicit transaction; raise + abort = full rollback. Verified via PgTAP "duplicate fails on cap → 0 new rows". |
| Slug collision on the duplicate (currently NULL → safe; if user later publishes it, slug-gen happens at publish-time) | The publish flow already handles NULL slugs by generating one. No new code needed. |
| Long menus (200+ dishes) hit Postgres function timeout | Local plpgsql copy of ~200 rows is sub-second. Not a real risk. |
| `image_url` strings copied; if source dish image is deleted by the merchant, the duplicate dish 404s | Documented in §3.3 + ADR-025. P2 follow-up: opt-in bucket clone. |
| `_QrShareCard` rebuild after tier changes mid-screen could miss the wordmark removal | `currentTierProvider` is reactive via Riverpod; the Offstage subtree re-paints on tier change. The capture happens on tap, after rebuild, so no stale snapshot. |
| `MenuCard.onMore` was not wired before — adding it could surprise users who learned to ignore the icon | The icon was always present; adding behaviour is purely additive. |

## 7. Success criteria

- `cd backend/supabase && npx supabase db reset` then `psql -f tests/billing_quotas.sql` → all PgTAP cases green including the duplicate-menu suite.
- `cd frontend/merchant && flutter analyze && flutter test` → clean; existing 113 + new tests stay green.
- `cd frontend/customer && pnpm check && pnpm test` → clean (no customer changes; sanity).
- Manual on a Pro test user: tap "Share QR image" → captured PNG has no `menuray.com` text. Free user: text still present.
- Manual: change a menu's time slot from All-day to Lunch → reload → still Lunch.
- Manual: tap 3-dot → "Duplicate menu" → land on the new draft. Free user with 1 menu attempts duplicate → snackbar with "Upgrade" action.
- ADR-025 + CLAUDE.md updates land.
