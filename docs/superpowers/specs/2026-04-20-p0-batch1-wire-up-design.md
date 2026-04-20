# P0 Batch 1 — 7-Screen Supabase Wire-up — Design

Date: 2026-04-20
Scope: Extend the ADR-017 pattern (repository + hand-written mapper + Riverpod `FutureProvider.family` + `ConsumerStatefulWidget` with local optimistic overlay) to seven more merchant screens, each read-wired plus one primary mutation where meaningful.
Audience: whoever implements the follow-up plan.

## 1. Goal & Scope

Wire these seven screens to Supabase so they render real data under `SHOW_SEED_LOGIN=true`, and so the primary merchant interaction on each persists across refresh:

| # | Screen | Current source | Wire-up target |
|---|---|---|---|
| 1 | `edit_dish` | `MockData.hotDishes.dishes[0]` | `dishByIdProvider(dishId)` + `DishRepository.updateDish(...)` |
| 2 | `organize_menu` | `MockData.lunchMenu` | `menuByIdProvider(menuId)` + `MenuRepository.reorderDishes(...)` |
| 3 | `preview_menu` | `MockData.lunchMenu` | `menuByIdProvider(menuId)` — read only |
| 4 | `published` | — | `menuByIdProvider(menuId)` (for QR slug) — read only |
| 5 | `settings` | `MockData.storeProfile` | `currentStoreProvider` — read only (edit moved to store_management) |
| 6 | `store_management` | `MockData.stores` | `currentStoreProvider` + `StoreRepository.updateStore(...)` |
| 7 | `select_photos` | none | no change — scaffolded for Batch 2 handoff |

**In scope**

- Six new route signatures carrying ids: `/edit/dish/:dishId`, `/edit/organize/:menuId`, `/publish/preview/:menuId`, `/publish/done/:menuId`. `settings` + `store-manage` keep their current parameterless paths.
- One new file: `lib/features/edit/dish_repository.dart` (`fetchDish`, `updateDish`, `upsertEnTranslation`).
- Two existing files extended: `MenuRepository` gains `reorderCategories` + `reorderDishes`; `StoreRepository` gains `updateStore`.
- Model additions: `DishCategory.position: int`, `Dish.position: int`. Mapper copies `position` through (currently dropped).
- Six new providers: `dishByIdProvider`, per-screen no new provider where `menuByIdProvider` / `currentStoreProvider` already fit.
- Six screens rewritten to `ConsumerStatefulWidget` (or `ConsumerWidget` where no local UI state is needed — `preview_menu`, `published`). `store_management` becomes `ConsumerStatefulWidget` owning the edit-dialog form controllers + optimistic overlay.
- Seven smoke tests updated to inject Fake repositories via `ProviderScope.overrides`, each asserting a seed-data string and (where mutations exist) the Save button is present and wired.
- Roadmap update: mark the six wired screens done; `select_photos` stays open for Batch 2.

**Out of scope (deferred)**

- `edit_dish`: no image upload, no AI-translate action, no AI-rewrite. The "本地化" EN row is the only translation persisted this batch (upsert `dish_translations` with locale `'en'`).
- `organize_menu`: no cross-category move, no category rename/add/delete, no dish add/delete. Reorder is dish-within-category only. Category reorder is a potential stretch goal (see §10).
- `preview_menu`: device/lang segment toggles stay local UI state; no persistence. "发布" button continues to navigate to `published` without a `menus.status = 'published'` write (status mutation is a later batch).
- `published`: QR image is still a local stub; only the URL/slug renders from real data.
- `settings`: no subscription/billing, no logo upload, no sub-account management. Store-edit lives on `store_management` per §3.4.
- `store_management`: "新增门店" disabled (schema `stores.owner_id UNIQUE` means one-per-owner this release; multi-store is P2 per roadmap).
- `select_photos`: no change. It has no backend dependency — local asset grid only — and its XFile-output contract will be shaped in Batch 2 alongside `camera`/`processing`.

## 2. Context

- Canonical pattern: `docs/superpowers/specs/2026-04-20-menu-manage-supabase-wire-up-design.md` and its plan. This spec extends the same architecture (ADR-017) without introducing new layers.
- Schema ground truth: `backend/supabase/migrations/20260420000001_init_schema.sql`. Relevant constraints:
  - `stores.owner_id` is `UNIQUE` — at most one store per authenticated user. Multi-store is explicitly P2.
  - `stores` columns editable in this batch: `name`, `address`, `logo_url`, `source_locale`. No `phone` / `currency` columns exist on `stores` (currency lives on `menus`).
  - `menus.slug` exists and is `UNIQUE`; `published_requires_slug` CHECK enforces slug non-null when status is `'published'`. The `published` screen renders a customer URL built from `menu.slug`.
  - `categories.position` and `dishes.position` are `int NOT NULL DEFAULT 0` — the schema supports reorder; `menus_store_id_idx` + `categories_menu_pos_idx` + `dishes_category_pos_idx` indexes are already in place.
  - `dish_translations (dish_id, locale) UNIQUE` — `edit_dish` EN upsert targets this composite key.
- RLS (`20260420000002_rls_policies.sql`) already authorises the owner to `UPDATE` rows they transitively own via `store_id`. Every write in this batch is a single-row `UPDATE` or small batch of them; no new policies needed.
- Mapper gap: `dishCategoryFromSupabase` sorts by `position` but does **not** store it on the model, and `dishFromSupabase` doesn't either. We need the int on the model so `reorderDishes` can compute diffs correctly — see §5.2.

## 3. Decisions

### 3.1 Path-parameter routes for `:menuId` / `:dishId` (four routes affected)

Extend the canonical pattern's `/manage/menu/:id` convention to `/edit/dish/:dishId`, `/edit/organize/:menuId`, `/publish/preview/:menuId`, `/publish/done/:menuId`. Builder helpers: `AppRoutes.editDishFor(String id)`, `organizeFor(String id)`, `previewFor(String id)`, `publishedFor(String id)`. Call sites updated in §5.8.

Rejected: Riverpod-only `selectedMenuProvider` — breaks refresh & deep-linking, contradicts ADR-017's route-as-URL principle.

### 3.2 Edit-dish form ↔ `dishes.update` + EN-translation upsert

`Save` writes a single `dishes.update({source_name, source_description, price, spice_level, is_signature, is_recommended, is_vegetarian, allergens})` scoped by `id = dishId`. The EN name from the 本地化 card upserts a `dish_translations` row `(dish_id, locale='en', name=...)` **only when it is non-empty and changed from the fetched value**; an empty EN field means the merchant didn't set one, and we skip the upsert rather than writing an empty string.

Rejected alternatives:
- RPC that atomically updates dish + translation: overkill for two statements that each carry their own RLS check and no cross-table invariant.
- Full translations editor inline: more than a batch; `translate-menu` Edge Function (roadmap P0) is the intended entry point for populating other locales.

### 3.3 Organize-menu reorder: `ReorderableListView` per category, batch position update on drag-end

Within each category, dishes are draggable via `ReorderableListView`. On drag-end, the screen computes the new `(dishId, position)` pairs for **that category only** and calls `MenuRepository.reorderDishes(List<DishPosition>)` which issues one `UPDATE` per changed row inside `Future.wait`. Optimistic UI: the list rebuilds from the local ordered copy immediately; on error, we `ref.invalidate(menuByIdProvider)` to re-fetch authoritative state and show a SnackBar.

Category reorder is **out of scope** unless Task 2's work turns out to be trivial enough to include — the plan's self-review will call this out.

Rejected alternatives:
- Client computes a full re-numbering (`0, 10, 20, …`) and writes **every** dish's position: O(n) writes where O(k) changed — wasteful for long menus.
- Single-SQL RPC `reorder_dishes(category_id, ordered_ids uuid[])`: cleaner, but no other screen uses RPC yet; we defer introducing that pattern until a use-case really needs atomicity across rows.

### 3.4 Store edit lives on `store_management`, not `settings`

The current `settings` screen is a tile-list (店铺信息 / 子账号 / 订阅 / 通知 / 帮助 / 关于 / 退出登录). None of these tiles currently have a destination — they're placeholders. Adding an inline store-edit form on `settings` would change the information architecture.

`store_management` already renders a store card that visually invites editing. We put the edit dialog there: tap the card → modal form (name, address, logo_url) → Save → `StoreRepository.updateStore(...)` + optimistic overlay + rollback. `settings` tiles 店铺信息 and 子账号 both become `context.go(AppRoutes.storeManage)` for now — `settings` stays read-only this batch except for the profile header that reads real data.

Rejected:
- Inline edit-in-place on `settings` — breaks the tile-list UX; one-tile-one-destination is the established pattern.
- Separate `/store/edit` screen — extra route for a modal-sized form.

### 3.5 One store per owner — `currentStoreProvider` is the single source

`stores.owner_id UNIQUE` means every `store_management` render is a list of length 1. We reuse `currentStoreProvider` (which already returns `Store`) and wrap it in an adapter provider `ownerStoresProvider = FutureProvider<List<Store>>` returning `[await ref.watch(currentStoreProvider.future)]`. This keeps the store-management screen's existing "list of cards" UI working without pretending to fetch multiple. "新增门店" button is disabled with a tooltip "即将支持多店" (P2).

Rejected:
- Change schema now to allow multi-store: out of scope for Batch 1; requires an ADR and RLS rework.
- Hide the list entirely and make `store_management` a single-card screen: churns the UI more than needed; the list pattern survives the future multi-store addition.

### 3.6 `_optimistic*` overlay pattern preserved screen-local

Each screen with a mutation owns its own `Map<String, T>` overlay in `ConsumerStatefulWidget`, identical to the canonical menu-manage pattern. We explicitly do **not** introduce `AsyncNotifier` / `StateNotifier` — the failure modes (one row, one toast, one invalidate) remain tiny and stateless. This is called out in ADR-017 and still holds.

## 4. Architecture — screen by screen

Each entry lists: route, provider(s) consumed, new repo methods used, UI deltas, smoke-test assertion.

### 4.1 `edit_dish`

- Route: `GET /edit/dish/:dishId` (was `/edit/dish`).
- Consumes: `dishByIdProvider(dishId)` → `Dish` + eagerly-fetched EN translation value. The mapper already surfaces `nameEn` from `dish_translations`, so `fetchDish` reuses the select pattern.
- Writes: `DishRepository.updateDish(dishId: ..., fields: ...)` + conditionally `DishRepository.upsertEnTranslation(dishId: ..., name: ...)`. Both awaited on Save; if either fails the whole save rolls back locally and we SnackBar the error. RLS guarantees tenancy.
- UI deltas: `initState` pulls the dish from the provider's resolved value via `ref.read(dishByIdProvider(widget.dishId).future)` in a `FutureBuilder`-less pattern — instead the screen reads `menuAsync.when(data: (d) => ...)` and builds the form only on `data`. Loading/error bodies identical shape to menu-manage. Spice level enum maps from `SpiceLevel` (already in model) ↔ the local `int _spice` index. Allergen chips map the `List<String>` to the five chip booleans and back.
- Smoke test: seed `宫保鸡丁` appears in `名称` field; tapping 保存 on an unchanged form invokes `updateDish` exactly once with the original values.

### 4.2 `organize_menu`

- Route: `GET /edit/organize/:menuId`.
- Consumes: `menuByIdProvider(menuId)`.
- Writes: `MenuRepository.reorderDishes(List<DishPosition>)` called on `onReorder` drag-end of each category's `ReorderableListView`. `DishPosition = ({String dishId, int position})` — a plain record.
- UI deltas: previous `ListView` of `DishRow`s in each category becomes `ReorderableListView.builder` with the same `DishRow` widget. Tapping a row still navigates to `AppRoutes.editDishFor(dish.id)`. Back button goes to `AppRoutes.home` (was `processing` — a Batch 2 concern).
- Smoke test: seed `热菜` category renders 3+ dishes; does not attempt to simulate a drag (that's integration-level).

### 4.3 `preview_menu`

- Route: `GET /publish/preview/:menuId`.
- Consumes: `menuByIdProvider(menuId)`.
- Writes: none.
- UI deltas: the preview card body reads `menu.name`, `menu.categories`, dish fields from provider `data`. Device/lang segments remain local state. "发布" navigates to `AppRoutes.publishedFor(menuId)` — slug already present on published menus.
- Smoke test: seed menu name renders in the preview card.

### 4.4 `published`

- Route: `GET /publish/done/:menuId`.
- Consumes: `menuByIdProvider(menuId)`.
- Writes: none.
- UI deltas: QR caption / share URL built as `'https://menu.menuray.com/${menu.slug}'`. If `menu.slug` is null (`draft` menu) we render a placeholder "菜单未发布" badge where the URL would be and hide the social-share row — but our seed data has slug set on the published menu, so this is a defensive branch.
- Smoke test: seed slug fragment (`yunjian-lunch` or equivalent) renders somewhere on the screen.

### 4.5 `settings`

- Route unchanged: `/settings`.
- Consumes: `currentStoreProvider`.
- Writes: none this batch.
- UI deltas: `_ProfileHeader` binds to the `Store` asyncValue — name/avatar from real data; loading body is a shimmer placeholder that preserves header height. `店铺信息` tile `onTap = context.go(AppRoutes.storeManage)`. Other tiles no-op.
- Smoke test: seed store name appears in the profile header.

### 4.6 `store_management`

- Route unchanged: `/store/list`.
- Consumes: `ownerStoresProvider` (wraps `currentStoreProvider` into a single-element list).
- Writes: `StoreRepository.updateStore({id, fields})`. Triggered by an edit icon on the store card → dialog with `name` + `address` text fields + a read-only `logo_url` preview. Save dispatches the update, invalidates `currentStoreProvider`. Optimistic overlay: `_optimisticStore` holds the pending `Store` while the update flies.
- UI deltas: "新增门店" button disabled (`onPressed: null`) with tooltip. Bottom caption text adjusted from "多家门店更方便管理" to "多店管理敬请期待" — honest to current state.
- Smoke test: seed store name appears on the card; tapping edit opens dialog; saving invokes `updateStore` once.

### 4.7 `select_photos`

- No changes this batch. Listed for completeness; Batch 2 plan will replace the hardcoded `_sampleAssets` with `image_picker` output and produce `List<XFile>` for the capture handoff.

## 5. Detailed component changes

### 5.1 Models (`lib/shared/models/`)

```dart
// dish.dart — add position
class Dish {
  // ...existing fields
  final int position;
  const Dish({..., this.position = 0});
}

// category.dart — add position
class DishCategory {
  // ...existing fields
  final int position;
  const DishCategory({..., this.position = 0});
}
```

No new enum values, no new models.

### 5.2 Mapper (`_mappers.dart`)

`dishFromSupabase` and `dishCategoryFromSupabase` currently drop `position`. Copy it through:

```dart
return Dish(..., position: (json['position'] as int?) ?? 0);
return DishCategory(..., position: (json['position'] as int?) ?? 0);
```

No other mapper changes (sorting by position already works).

### 5.3 `DishRepository` (new — `lib/features/edit/dish_repository.dart`)

```dart
class DishRepository {
  DishRepository(this._client);
  final SupabaseClient _client;

  Future<Dish> fetchDish(String dishId) async { /* single row + dish_translations */ }

  Future<void> updateDish({
    required String dishId,
    required String sourceName,
    String? sourceDescription,
    required double price,
    required SpiceLevel spice,
    required bool isSignature,
    required bool isRecommended,
    required bool isVegetarian,
    required List<String> allergens,
  }) async { /* single UPDATE */ }

  Future<void> upsertEnTranslation({
    required String dishId,
    required String storeId,
    required String name,
  }) async {
    await _client
      .from('dish_translations')
      .upsert({'dish_id': dishId, 'store_id': storeId,
               'locale': 'en', 'name': name},
              onConflict: 'dish_id,locale');
  }
}
```

`store_id` on translations is required by RLS/schema; we pass the current store's id — available on the fetched `Dish`'s `menu → store_id` lineage (read via menu select) or by reading `currentStoreProvider` at call time. We choose the latter — simpler and avoids adding `storeId` to the `Dish` model.

### 5.4 `MenuRepository` extensions

```dart
Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {
  await Future.wait(
    pairs.map((p) => _client.from('dishes').update({'position': p.position}).eq('id', p.dishId)),
  );
}

// stretch:
Future<void> reorderCategories(List<({String categoryId, int position})> pairs) async { ... }
```

### 5.5 `StoreRepository` extensions

```dart
Future<void> updateStore({
  required String storeId,
  required String name,
  String? address,
  String? logoUrl,
}) async {
  await _client.from('stores').update({
    'name': name,
    if (address != null) 'address': address,
    if (logoUrl != null) 'logo_url': logoUrl,
  }).eq('id', storeId);
}
```

### 5.6 Providers

Colocate per feature. Files:

- `lib/features/edit/edit_providers.dart` (new):
  ```dart
  final dishRepositoryProvider = Provider<DishRepository>(
    (ref) => DishRepository(ref.watch(supabaseClientProvider)),
  );
  final dishByIdProvider = FutureProvider.family<Dish, String>((ref, dishId) async {
    ref.watch(authStateProvider);
    return ref.watch(dishRepositoryProvider).fetchDish(dishId);
  });
  ```
- `lib/features/store/store_providers.dart` (new):
  ```dart
  final ownerStoresProvider = FutureProvider<List<Store>>((ref) async {
    final s = await ref.watch(currentStoreProvider.future);
    return [s];
  });
  ```

`menuByIdProvider` is already in `features/manage/menu_management_provider.dart`. `preview_menu`, `published`, `organize_menu` all import it from there. (An alternative is to lift it to `features/home/`; we keep it where it is to avoid churning an already-working file.)

### 5.7 Routes (`app_router.dart`)

Add these helpers to `AppRoutes`:

```dart
static const editDish = '/edit/dish';
static String editDishFor(String id) => '/edit/dish/$id';
static const organize = '/edit/organize';
static String organizeFor(String id) => '/edit/organize/$id';
static const preview = '/publish/preview';
static String previewFor(String id) => '/publish/preview/$id';
static const published = '/publish/done';
static String publishedFor(String id) => '/publish/done/$id';
```

Four `GoRoute` definitions change to path-parameter form.

### 5.8 Call sites updated

- `home_screen.dart` `MenuCard.onTap`: already fixed to `menuManageFor(menu.id)` in previous iteration; nothing here.
- `menu_management_screen.dart`:
  - 编辑内容 tile: `context.go(AppRoutes.organizeFor(widget.menuId))`.
  - 分享 tile: `context.go(AppRoutes.publishedFor(widget.menuId))`.
- `organize_menu_screen.dart`:
  - Dish `onTap`: `context.go(AppRoutes.editDishFor(dish.id))`.
  - Back button: `context.go(AppRoutes.home)` (was `processing`).
- `edit_dish_screen.dart`:
  - Cancel / Save: `context.go(AppRoutes.organizeFor(menuId))` — `menuId` piggybacks via the fetched dish's `menu_id`. **Alternative**: always pop. Since this screen is reached via `context.go` (not push), popping won't have a route to return to after a web refresh; we prefer explicit navigation with the captured `menuId`.
- `preview_menu_screen.dart`:
  - 发布 action: `context.go(AppRoutes.publishedFor(widget.menuId))`.
  - 返回: `context.go(AppRoutes.home)` (customTheme is out of scope).
- `published_screen.dart`:
  - Close / Bottom CTA: unchanged (`AppRoutes.home`).
- `settings_screen.dart`:
  - 店铺信息 tile `onTap`: `context.go(AppRoutes.storeManage)`.
- `store_management_screen.dart`:
  - 新增门店 → disabled.

## 6. Error handling

Every screen follows the canonical three-state body:

| State | Display |
|---|---|
| Loading | `CircularProgressIndicator` centered (identical widget to menu-manage) |
| Error | Error icon + message + 重试 (invalidates the relevant provider) |
| Empty | Only applies to screens that could plausibly return empty (`organize_menu` with no categories) — a muted "暂无分类" placeholder. Seed data will not hit this. |

Mutation failures surface via SnackBar + optimistic-overlay rollback. No toast library, no banner widget — plain `ScaffoldMessenger.of(context).showSnackBar(...)` consistent with menu-manage.

## 7. Testing

- **Smoke test per screen** (7 files touched; `select_photos` unchanged): renders without throwing + asserts one seed-data string. Pattern identical to the menu-manage smoke test: `ProviderScope.overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository()), menuRepositoryProvider.overrideWithValue(...), dishRepositoryProvider.overrideWithValue(...), storeRepositoryProvider.overrideWithValue(...)]`.
- **No mutation tests** — we do not assert that `updateDish` is called from a smoke test because that requires pumping inputs and the `FilterChip` interactions have too many moving parts for the 1-assertion-per-smoke bar ADR-007 set. Leave write-path coverage to a later integration harness.
- `flutter analyze` remains clean; `flutter test` count stays at **33 + 0 net change** (existing smoke tests rewritten, not added).
- Manual E2E under `SHOW_SEED_LOGIN=true` covers all six wired screens end-to-end.

## 8. Dependencies

No new packages. `ReorderableListView` is core Flutter. `supabase_flutter` already handles upsert. `image_picker` / `camera` remain deferred to Batch 2.

## 9. Follow-ups / docs

- Update `docs/roadmap.md`: check off the Batch 1 six screens under "Remaining 14 screens wired to Supabase".
- Update `docs/architecture.md`: bump "wired screens" count from 3 to 9 and list the new repository + provider files.
- No new ADR — ADR-017 still covers the pattern.

## 10. Risks & open questions

1. **`reorderDishes` race on first drag after a stale fetch**: If the menu was fetched, the merchant reorders, and the UPDATE lands while another session also reorders, the second arrival silently overwrites. Mitigation: accept this (single-tenant merchant app, same user); no `updated_at` optimistic-locking this batch. Called out here so we don't rediscover it.
2. **`edit_dish` cancel without menuId context**: If the route is opened via deep link (no referrer menu), Cancel needs a home destination. We fall back to `AppRoutes.home` when `menuId` can't be derived.
3. **Category reorder inclusion** — the plan's self-review should call this out. If Task 2's diff is small (adding a second `ReorderableListView` around the categories) we include it; otherwise defer to a future micro-batch.
4. **`_FakeStoreRepository` / `_FakeDishRepository` duplication across smoke tests** — acceptable short-term, consolidate in a `test/support/fakes.dart` if the third+ usage appears.
5. **Path conflict between `AppRoutes.editDish = '/edit/dish'` and the `:dishId`-carrying `GoRoute`**: the constant stays only as a *string prefix* for the helper; no `GoRoute` listens at `/edit/dish` after the change. Verified in §5.7.
