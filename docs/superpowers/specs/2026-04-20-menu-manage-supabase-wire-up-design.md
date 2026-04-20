# Menu-manage Screen ↔ Supabase Wire-up — Design

Date: 2026-04-20
Scope: Wire the merchant app's menu-manage screen to the Supabase backend.
Audience: Whoever implements the follow-up plan.

## 1. Goal & Scope

Replace `MockData.lunchMenu` in the menu-manage screen with a real Supabase read (keyed by menu id from the route), and make the **dish sold-out toggle** a persistent backend mutation with optimistic UI + rollback. Close the home → menu-manage UUID dead-end introduced in the previous iteration.

**In scope**

- Route becomes `/manage/menu/:id`; home passes `menu.id`.
- `MenuRepository.fetchMenu(menuId)` — single nested PostgREST select for one menu.
- `MenuRepository.setDishSoldOut({dishId, soldOut})` — `dishes.update({sold_out: …})` where `id = dishId`.
- `menuByIdProvider = FutureProvider.family<Menu, String>(...)` in a new `features/manage/menu_management_provider.dart`.
- Menu-manage screen becomes `ConsumerStatefulWidget`, reads `menuByIdProvider(menuId)`, shows loading/error/data states. Sold-out toggle issues optimistic update + persistence + rollback-on-failure.
- Dynamic top-bar title (`menu.name`) replacing the hardcoded "午市套餐 2025 春".
- Smoke test updated to use `ProviderScope` overrides with fake repo.

**Out of scope (deferred)**

- Time-slot radio continues to write `setState` only (not persisted).
- Menu-title inline edit icon remains cosmetic (no handler).
- "编辑内容" / "分享" / "数据" navigation buttons continue to go to their current destinations — `organize` / `published` / `statistics` — all still reading `MockData`. The dead-end is transferred (not resolved) to those screens' own wiring passes.
- `edit_dish_screen` still hardcodes `MockData.hotDishes.dishes[0]`.
- No realtime subscription on the menu or its dishes.
- No mutation of `menu.status` (publish/unpublish) — no publish button present on the current screen.

## 2. Context

- Prior spec: `docs/superpowers/specs/2026-04-19-flutter-supabase-wire-up-design.md`. ADR-017 sets the architectural pattern this iteration extends.
- RLS from `backend/supabase/migrations/20260420000002_rls_policies.sql` enforces tenancy: `.eq('id', menuId)` + `.single()` on `menus` returns at most one row, and only if owned by the caller; `.update(...)` on `dishes` succeeds only if the `dishes.store_id` transitively belongs to the caller.
- `menuFromSupabase` and `dishFromSupabase` (Task 2 of prior iteration) already populate `soldOut` and every other field needed. No mapper changes.

## 3. Decisions

### 3.1 Route: `/manage/menu/:id` path parameter

Path parameter, not query. Consistent with REST conventions; browsers can back/forward across menu ids; deep-link friendly. `AppRoutes.menuManageFor(String id) → '/manage/menu/$id'` as the canonical builder so call sites don't hand-roll the path.

Rejected:
- Query parameter (`/manage/menu?id=…`) — menu id is the *subject*, not a filter.
- Riverpod-only selection (`selectedMenuProvider` read by menu-manage) — breaks browser refresh and deep links on web.

### 3.2 Mutation scope: sold-out only this iteration

Sold-out is the high-frequency merchant interaction (tracked per-dish, flipped day-to-day). Time-slot changes structure and is rare; persisting it requires schema-level care around `time_slot_description` pairing and is better handled when a richer menu-edit flow lands. Leaving time-slot as local-only preserves the current behavior (no regression) while delivering the main value.

Rejected:
- Read-only — leaves the sold-out toggle feeling broken (user toggles, refreshes, changes lost).
- Read + both mutations — doubles task size with low marginal value this iteration.

### 3.3 Optimistic update with local overlay + rollback

Toggling a sold-out Switch writes `_optimistic[dishId] = newValue` via `setState` immediately (UI reflects the new state within one frame), then calls `setDishSoldOut`. On success: `ref.invalidate(menuByIdProvider(menuId))` refetches the authoritative value, and the overlay entry for that dish is cleared so fetched data takes over. On failure: overlay entry is removed (reverting to the previous value) and a SnackBar shows the error.

This pattern matches the spirit of Task 5's login error handling (failures surface to the user, success trusts the router/provider refresh). It uses a `Map<String, bool>` in screen state — no new `AsyncNotifier` / `StateNotifier` — in keeping with ADR-017's "thin abstractions" principle.

Rejected:
- Invalidate-on-tap (no overlay) — Switch appears stuck until the network round-trip completes; poor UX.
- Per-dish inline error row — clutters the list for an event that's normally transient. SnackBar matches the existing error-surface pattern.

### 3.4 No new ADR

The design strictly extends ADR-017 (repository + hand-written mappers + Riverpod providers + one nested query). No new architectural decision is introduced.

## 4. Architecture

### 4.1 File layout

```
frontend/merchant/lib/
  features/manage/
    menu_management_provider.dart              NEW — menuByIdProvider(family)
    presentation/menu_management_screen.dart   MODIFIED — ConsumerStatefulWidget, menuId arg
  features/home/
    menu_repository.dart                       MODIFIED — + fetchMenu + setDishSoldOut
    presentation/home_screen.dart              MODIFIED — MenuCard.onTap passes menu.id
  router/app_router.dart                       MODIFIED — path param + AppRoutes.menuManageFor(id)
test/smoke/menu_management_screen_smoke_test.dart  MODIFIED — ProviderScope + fake repos
```

### 4.2 Data flow

```
HomeScreen.MenuCard.onTap
  → context.go(AppRoutes.menuManageFor(menu.id))
  → GoRoute /manage/menu/:id
  → MenuManagementScreen(menuId: id)
  → ref.watch(menuByIdProvider(menuId))
  → MenuRepository.fetchMenu(menuId)
  → supabase.menus.select(nested).eq('id', menuId).single()
  → mapper → Menu
  → .when(loading, error, data) renders

Sold-out toggle tap:
  setState(_optimistic[dishId] = newVal)
  → MenuRepository.setDishSoldOut(dishId, newVal)
  → on success: ref.invalidate(menuByIdProvider(menuId)); _optimistic.remove(dishId)
  → on failure: _optimistic.remove(dishId) (revert); SnackBar(error)
```

## 5. Component specs

### 5.1 `MenuRepository` additions

```dart
Future<Menu> fetchMenu(String menuId) async {
  final row = await _client
      .from('menus')
      .select('''<same nested select as listMenusForStore>''')
      .eq('id', menuId)
      .single();
  return menuFromSupabase(row);
}

Future<void> setDishSoldOut({
  required String dishId,
  required bool soldOut,
}) async {
  await _client
      .from('dishes')
      .update({'sold_out': soldOut})
      .eq('id', dishId);
}
```

Notes:
- The nested select string is literally the same as `listMenusForStore`'s. Implementer should extract the string into a private `static const _menuSelect = '''...'''` (or a private top-level const) to DRY the two methods.
- `setDishSoldOut` does not `.select()` back — RLS denial becomes a `PostgrestException` thrown from the call.

### 5.2 `menuByIdProvider`

```dart
final menuByIdProvider =
    FutureProvider.family<Menu, String>((ref, menuId) async {
  ref.watch(authStateProvider); // re-evaluate on sign-in/out
  return ref.watch(menuRepositoryProvider).fetchMenu(menuId);
});
```

Lives in `features/manage/menu_management_provider.dart`. Separate file (not in `home_providers.dart`) because the consumer is manage-land. Crosses the `manage → home` import boundary only via `menuRepositoryProvider`, which is acceptable until a follow-up task moves `MenuRepository` out of `features/home/`.

### 5.3 Route change

```dart
class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/';
  // ...
  static const menuManage = '/manage/menu';          // kept for reference
  static String menuManageFor(String id) => '/manage/menu/$id';  // NEW
  // ...
}

GoRoute(
  path: '${AppRoutes.menuManage}/:id',
  builder: (c, s) =>
      MenuManagementScreen(menuId: s.pathParameters['id']!),
),
```

All existing call sites of `AppRoutes.menuManage` are audited and either:
- `home_screen.dart` MenuCard `onTap` — **updated** to `AppRoutes.menuManageFor(menu.id)`.
- `statistics_screen.dart:35` back button — **not updated** (statistics is out of scope; back goes to the parameter-less path, which is not a valid route; this is the pre-existing dead-end documented in §1 out-of-scope).

To avoid the statistics back-button crashing on a now-invalid path, register a no-op redirect OR update `statistics_screen.dart:35` minimally to point at `AppRoutes.home` (home is always valid). **Decision: change the statistics back button to `AppRoutes.home`**. One-line change, removes a crash risk without expanding scope.

### 5.4 Menu-manage screen rewrite

```dart
class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key, required this.menuId});
  final String menuId;

  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  // Local optimistic overlay: dishId -> pending value (while backend confirms)
  final Map<String, bool> _optimisticSoldOut = {};

  // Time-slot remains local-only (see out-of-scope)
  MenuTimeSlot? _timeSlotOverride;

  Future<void> _toggleSoldOut(String dishId, bool next) async {
    setState(() => _optimisticSoldOut[dishId] = next);
    try {
      await ref
          .read(menuRepositoryProvider)
          .setDishSoldOut(dishId: dishId, soldOut: next);
      ref.invalidate(menuByIdProvider(widget.menuId));
      if (mounted) {
        setState(() => _optimisticSoldOut.remove(dishId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimisticSoldOut.remove(dishId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：${e.toString()}')),
      );
    }
  }

  bool _effectiveSoldOut(Dish dish) =>
      _optimisticSoldOut[dish.id] ?? dish.soldOut;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuByIdProvider(widget.menuId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _AppBar(menuAsync: menuAsync),
      body: menuAsync.when(
        loading: () => const _LoadingBody(),
        error: (err, _) => _ErrorBody(
          message: '加载失败：$err',
          onRetry: () => ref.invalidate(menuByIdProvider(widget.menuId)),
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(Menu menu) {
    // Existing visual structure: quick-actions row, 售罄管理 grid, 营业时段 radio.
    // Each _SoldOutItem now reads _effectiveSoldOut(dish) and calls _toggleSoldOut.
    // Time-slot radio still sets _timeSlotOverride via setState.
    ...
  }
}
```

Visual structure, widget decomposition (`_SoldOutItem`, time-slot radios, quick-actions row), and styles are preserved unchanged from the existing screen — only state source and toggle handlers change.

### 5.5 Home screen: one-line change

```dart
// home_screen.dart — _MenuList.build
MenuCard(
  menu: menu,
  onTap: () => context.go(AppRoutes.menuManageFor(menu.id)),  // was AppRoutes.menuManage
),
```

No other home changes.

### 5.6 Statistics screen: one-line change (safety)

```dart
// statistics_screen.dart:35
onPressed: () => context.go(AppRoutes.home),  // was AppRoutes.menuManage
```

Prevents navigating to the now-parameterless path (which no longer matches any route).

### 5.7 Smoke test

`test/smoke/menu_management_screen_smoke_test.dart` — rewrite to pump `MenuManagementScreen(menuId: 'm1')` wrapped in `ProviderScope` overriding `authRepositoryProvider`, `menuRepositoryProvider`. Fake repo returns a hand-built `Menu` with one category and one dish. Assert menu name + dish name render after `pumpAndSettle`.

Existing fake-repo duplication (already flagged in the prior iteration's final review) will be partially re-duplicated here; the shared-fakes extraction remains a tracked follow-up.

## 6. Error handling

| Source | Surface |
|---|---|
| `fetchMenu` — row not found (`.single()` zero rows) | error branch with retry; defensive — should never happen if home only navigates with owned menu ids |
| `fetchMenu` — RLS denies (another tenant's id forged) | Same as above — `PostgrestException` to error branch |
| `setDishSoldOut` — RLS or network failure | SnackBar + local overlay revert; menu list keeps the old value |
| Bad `menuId` in URL (e.g., typo) | error branch; user can navigate back |

## 7. Testing

- **Smoke test** updated for the new screen shape. Asserts render with fake repo.
- **No new unit tests** — repository methods are narrow wrappers; mapper coverage unchanged.
- **Integration / E2E** — manual verification step covering: tap a menu card on home → lands on `/manage/menu/<id>` → sees the correct menu → toggles a dish sold-out → shows Switch moves → refresh page → sold-out state persists.

## 8. Dependencies

No new dependencies. `supabase_flutter ^2.5` (already installed) covers everything.

## 9. Documentation follow-ups

- `docs/roadmap.md`: mark "Menu-manage screen wired to Supabase" as done; add a bullet for `edit_dish_screen` as the next MockData consumer in `features/edit/`.
- No new ADR (extends ADR-017).

## 10. Risks & follow-ups

- **Transferred dead-ends**: tapping "编辑内容" / "分享" / "数据" from menu-manage still lands on MockData-backed screens. This is acceptable because no automated flow relies on those destinations, but a user exploring the app will notice the content mismatch. Documented in §1.
- **Optimistic update race**: if the user taps the same switch twice rapidly before the first round-trip completes, the second tap overwrites the overlay. The backend receives two updates in order; the final state is the second tap. Acceptable — matches user intent.
- **No pull-to-refresh on menu-manage** currently. Not added this iteration (home has it). If a merchant needs to force a reload, they navigate back + re-enter.
- **`statistics_screen.dart` back-button fix** is a scope creep by one line; justified by the crash-risk it avoids. No other out-of-scope touches.
