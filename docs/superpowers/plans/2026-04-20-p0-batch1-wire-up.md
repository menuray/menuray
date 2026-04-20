# P0 Batch 1 — 7-Screen Wire-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Tasks 0-4 are the foundation (sequential); Tasks 5-10 are per-screen and parallelisable once the foundation has landed; Tasks 11-14 sweep the result.

**Goal:** Land the design in `docs/superpowers/specs/2026-04-20-p0-batch1-wire-up-design.md` across six merchant screens (edit_dish, organize_menu, preview_menu, published, settings, store_management) — each reading real Supabase data and, where meaningful, persisting its primary mutation with optimistic UI + rollback. `select_photos` is intentionally untouched this batch.

**Architecture:** ADR-017 unchanged — thin repositories + hand-written mappers + Riverpod `FutureProvider.family` + `ConsumerStatefulWidget` (or `ConsumerWidget` for read-only screens) + per-screen `Map`-typed optimistic overlays.

**Tech stack:** Flutter 3.11.5 / Riverpod 2.6 / go_router 14.6 / supabase_flutter 2.12 / Postgres 17. No new packages.

**Spec:** `docs/superpowers/specs/2026-04-20-p0-batch1-wire-up-design.md`

**Repo assumptions:**
- Flutter app root: `frontend/merchant/`. All `flutter`/`dart` commands run from that directory.
- SDK: `/home/coder/flutter/bin/flutter`
- Current branch: `main`. Base commit: `496b61a` (spec landed).
- Existing test count: **33**. Target after this plan: **33** (rewrites, not additions).

---

## Task 0: Model + mapper — carry `position` through

Foundation A. Makes `reorderDishes` safe to compute diffs. Tiny.

**Files:**
- Modify: `frontend/merchant/lib/shared/models/dish.dart`
- Modify: `frontend/merchant/lib/shared/models/category.dart`
- Modify: `frontend/merchant/lib/shared/models/_mappers.dart`

### Steps

- [ ] **Step 0.1:** Add `final int position` to `Dish` (default `0`). Place right after `confidence` in the field list and the constructor. Keep `const`.

- [ ] **Step 0.2:** Add `final int position` to `DishCategory` (default `0`). Constructor keeps `const`.

- [ ] **Step 0.3:** Extend mappers to pass `position` through:

```dart
// In dishFromSupabase, inside the returned Dish(...)
position: (json['position'] as int?) ?? 0,

// In dishCategoryFromSupabase, inside the returned DishCategory(...)
position: (json['position'] as int?) ?? 0,
```

- [ ] **Step 0.4:** Run `flutter analyze` from `frontend/merchant`. Expect `No issues found!`.

- [ ] **Step 0.5:** Run `flutter test`. Expect all 33 pass (model additions with defaults are non-breaking).

- [ ] **Step 0.6:** Commit:

```
chore(models): add position field to Dish and DishCategory

Needed by the organize_menu reorder path; mapper already sorted
by position but dropped the value. Defaults to 0 so all existing
call sites + smoke-test fakes compile unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 1: MenuRepository + StoreRepository extensions

Foundation B. Adds write methods used by Tasks 6 and 10.

**Files:**
- Modify: `frontend/merchant/lib/features/home/menu_repository.dart` (one method added)
- Modify: `frontend/merchant/lib/features/home/store_repository.dart` (one method added)

### Steps

- [ ] **Step 1.1:** In `menu_repository.dart`, add after `setDishSoldOut`:

```dart
Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {
  if (pairs.isEmpty) return;
  await Future.wait(
    pairs.map(
      (p) => _client
          .from('dishes')
          .update({'position': p.position})
          .eq('id', p.dishId),
    ),
  );
}
```

- [ ] **Step 1.2:** In `store_repository.dart`, add after `currentStore`:

```dart
Future<void> updateStore({
  required String storeId,
  required String name,
  String? address,
  String? logoUrl,
}) async {
  final payload = <String, dynamic>{'name': name};
  if (address != null) payload['address'] = address;
  if (logoUrl != null) payload['logo_url'] = logoUrl;
  await _client.from('stores').update(payload).eq('id', storeId);
}
```

- [ ] **Step 1.3:** Analyze clean + existing tests pass.

- [ ] **Step 1.4:** Commit:

```
feat(home): add MenuRepository.reorderDishes + StoreRepository.updateStore

Batch updates for organize_menu drag-end (reorderDishes uses
Future.wait across single-row UPDATEs — see §3.3 of the design).
updateStore writes the store card edits landing in Task 10.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 2: DishRepository (new file)

Foundation C.

**Files:**
- Create: `frontend/merchant/lib/features/edit/dish_repository.dart`

### Steps

- [ ] **Step 2.1:** Create the file with contents:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/dish.dart';

const _dishSelect = '''
  id, source_name, source_description, price, image_url,
  spice_level, confidence, is_signature, is_recommended,
  is_vegetarian, sold_out, allergens, position,
  menu_id, category_id, store_id,
  dish_translations(locale, name)
''';

class DishRepository {
  DishRepository(this._client);
  final SupabaseClient _client;

  /// Fetch a single dish with its translations. Throws if no row matches
  /// (RLS-filtered — null when caller doesn't own the dish).
  Future<Dish> fetchDish(String dishId) async {
    final row = await _client.from('dishes').select(_dishSelect).eq('id', dishId).single();
    return dishFromSupabase(row);
  }

  /// Fetch the menu_id for a dish — used by the edit screen to navigate back
  /// to /edit/organize/:menuId after Save/Cancel.
  Future<String> fetchMenuIdForDish(String dishId) async {
    final row =
        await _client.from('dishes').select('menu_id').eq('id', dishId).single();
    return row['menu_id'] as String;
  }

  Future<void> updateDish({
    required String dishId,
    required String sourceName,
    String? sourceDescription,
    required double price,
    required String spiceLevel, // 'none' | 'mild' | 'medium' | 'hot'
    required bool isSignature,
    required bool isRecommended,
    required bool isVegetarian,
    required List<String> allergens,
  }) async {
    await _client.from('dishes').update({
      'source_name': sourceName,
      'source_description': sourceDescription,
      'price': price,
      'spice_level': spiceLevel,
      'is_signature': isSignature,
      'is_recommended': isRecommended,
      'is_vegetarian': isVegetarian,
      'allergens': allergens,
    }).eq('id', dishId);
  }

  Future<void> upsertEnTranslation({
    required String dishId,
    required String storeId,
    required String name,
  }) async {
    await _client
        .from('dish_translations')
        .upsert(
          {
            'dish_id': dishId,
            'store_id': storeId,
            'locale': 'en',
            'name': name,
          },
          onConflict: 'dish_id,locale',
        );
  }
}
```

- [ ] **Step 2.2:** Analyze clean.

- [ ] **Step 2.3:** Commit:

```
feat(edit): add DishRepository (fetchDish + updateDish + EN upsert)

Owns the single-dish select, the save mutation, and the EN
translation upsert for the edit_dish screen landing in Task 5.
Uses the same hand-written mapper as MenuRepository.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 3: Provider files (edit_providers + store_providers)

Foundation D.

**Files:**
- Create: `frontend/merchant/lib/features/edit/edit_providers.dart`
- Create: `frontend/merchant/lib/features/store/store_providers.dart`

### Steps

- [ ] **Step 3.1:** `edit_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/dish.dart';
import '../auth/auth_providers.dart';
import 'dish_repository.dart';

final dishRepositoryProvider = Provider<DishRepository>(
  (ref) => DishRepository(ref.watch(supabaseClientProvider)),
);

final dishByIdProvider =
    FutureProvider.family<Dish, String>((ref, dishId) async {
  ref.watch(authStateProvider);
  return ref.watch(dishRepositoryProvider).fetchDish(dishId);
});
```

- [ ] **Step 3.2:** `store_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/store.dart';
import '../home/home_providers.dart';

/// One store per owner (schema: stores.owner_id UNIQUE). This wraps the
/// single currentStore into a List so store_management can keep its
/// list-of-cards UI without pretending to fetch multiple.
final ownerStoresProvider = FutureProvider<List<Store>>((ref) async {
  final s = await ref.watch(currentStoreProvider.future);
  return [s];
});
```

- [ ] **Step 3.3:** Analyze clean.

- [ ] **Step 3.4:** Commit:

```
feat(manage): add dishByIdProvider + ownerStoresProvider

dishByIdProvider re-evaluates on auth change and is consumed by
edit_dish (Task 5). ownerStoresProvider returns a single-element
list built off currentStoreProvider (see §3.5 of the design).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 4: Router changes — add `-For` helpers + path-param GoRoutes

Foundation E. Breaks four routes simultaneously; subsequent screen tasks immediately re-wire them.

**Files:**
- Modify: `frontend/merchant/lib/router/app_router.dart`

### Steps

- [ ] **Step 4.1:** Inside `class AppRoutes`, after `organize = '/edit/organize'`:

Find:
```dart
  static const organize = '/edit/organize';
  static const editDish = '/edit/dish';
```
Replace with:
```dart
  static const organize = '/edit/organize';
  static String organizeFor(String menuId) => '/edit/organize/$menuId';
  static const editDish = '/edit/dish';
  static String editDishFor(String dishId) => '/edit/dish/$dishId';
```

- [ ] **Step 4.2:** After `preview = '/publish/preview'`:

Find:
```dart
  static const preview = '/publish/preview';
  static const published = '/publish/done';
```
Replace with:
```dart
  static const preview = '/publish/preview';
  static String previewFor(String menuId) => '/publish/preview/$menuId';
  static const published = '/publish/done';
  static String publishedFor(String menuId) => '/publish/done/$menuId';
```

- [ ] **Step 4.3:** Replace the four `GoRoute` entries:

Find:
```dart
      GoRoute(path: AppRoutes.organize, builder: (c, s) => const OrganizeMenuScreen()),
      GoRoute(path: AppRoutes.editDish, builder: (c, s) => const EditDishScreen()),
```
Replace with:
```dart
      GoRoute(
        path: '${AppRoutes.organize}/:menuId',
        builder: (c, s) => OrganizeMenuScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(
        path: '${AppRoutes.editDish}/:dishId',
        builder: (c, s) => EditDishScreen(dishId: s.pathParameters['dishId']!),
      ),
```

Find:
```dart
      GoRoute(path: AppRoutes.preview, builder: (c, s) => const PreviewMenuScreen()),
      GoRoute(path: AppRoutes.published, builder: (c, s) => const PublishedScreen()),
```
Replace with:
```dart
      GoRoute(
        path: '${AppRoutes.preview}/:menuId',
        builder: (c, s) => PreviewMenuScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(
        path: '${AppRoutes.published}/:menuId',
        builder: (c, s) => PublishedScreen(menuId: s.pathParameters['menuId']!),
      ),
```

> **Expected compile failures after this step** — four screen constructors now require `menuId`/`dishId`. Tasks 5–8 land immediately to fix. Until Task 8 completes, `flutter analyze` will error. **Do not commit Task 4 in isolation.** Instead, bundle Tasks 4–10 into a single commit sequence OR run Tasks 5–10 without re-analyzing between them and run the full sweep in Task 12.

Recommended execution order for subagents:
1. One subagent does Task 4 + stubs the four screen constructors to accept `{required this.menuId}` / `{required this.dishId}` **without yet rewriting the body** — just making `analyze` clean.
2. Parallel subagents then flesh out Tasks 5–10 on top.

- [ ] **Step 4.4:** Implement the minimal constructor stubs so analyze is clean before spawning screen tasks. For each of the four screens:
  - `EditDishScreen`: change `const EditDishScreen({super.key})` → `const EditDishScreen({super.key, required this.dishId}); final String dishId;`.
  - `OrganizeMenuScreen`: add `{required this.menuId}; final String menuId;`.
  - `PreviewMenuScreen`: add `{required this.menuId}; final String menuId;`. Keep `StatefulWidget` (the body still uses local segment state).
  - `PublishedScreen`: add `{required this.menuId}; final String menuId;`.

- [ ] **Step 4.5:** Run `flutter analyze` — must be clean. Failing smoke tests are expected (their `MaterialApp(home: const EditDishScreen())` call sites now need an id). Each screen task fixes its own smoke test.

- [ ] **Step 4.6:** Commit:

```
feat(router): introduce :menuId / :dishId path params for four routes

Adds editDishFor / organizeFor / previewFor / publishedFor helpers
and GoRoutes carrying the id. Screen constructors get a required
id field — bodies still read from mock data (next tasks land the
real wire-up screen by screen).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 5: edit_dish — wire to dishByIdProvider + Save path

**Files:**
- Modify: `frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/edit_dish_screen_smoke_test.dart` (full rewrite)

### Steps

- [ ] **Step 5.1:** Replace the screen. Preserve the current visual layout (image section, basic info, description, translation card, tags + allergens, spice segments). Top-level structure:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/dish.dart';
import '../../home/home_providers.dart';
import '../edit_providers.dart';

class EditDishScreen extends ConsumerStatefulWidget {
  const EditDishScreen({super.key, required this.dishId});
  final String dishId;
  @override
  ConsumerState<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends ConsumerState<EditDishScreen> {
  // Controllers — lazily populated from the first dish fetch.
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _enCtrl = TextEditingController();
  bool _controllersPopulated = false;
  String? _menuIdForNav; // captured after first fetch so Cancel/Save can route

  int _spice = 0;          // 0..3 → none, mild, medium, hot
  bool _isSignature = false;
  bool _isRecommended = false;
  bool _isVegetarian = false;
  final Set<String> _allergens = {};
  bool _saving = false;

  static const _allergenValues = {
    '花生': 'peanut', '乳制品': 'dairy', '海鲜': 'seafood',
    '麸质': 'gluten', '鸡蛋': 'egg',
  };
  static const _spiceEnum = ['none', 'mild', 'medium', 'hot'];

  void _hydrate(Dish d) {
    if (_controllersPopulated) return;
    _nameCtrl.text = d.name;
    _priceCtrl.text = d.price.toStringAsFixed(0);
    _descCtrl.text = d.description ?? '';
    _enCtrl.text = d.nameEn ?? '';
    _spice = SpiceLevel.values.indexOf(d.spice); // direct ordinal
    _isSignature = d.isSignature;
    _isRecommended = d.isRecommended;
    _isVegetarian = d.isVegetarian;
    _allergens..clear()..addAll(d.allergens);
    _controllersPopulated = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(dishRepositoryProvider);
      final store = await ref.read(currentStoreProvider.future);
      await repo.updateDish(
        dishId: widget.dishId,
        sourceName: _nameCtrl.text.trim(),
        sourceDescription: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        spiceLevel: _spiceEnum[_spice],
        isSignature: _isSignature,
        isRecommended: _isRecommended,
        isVegetarian: _isVegetarian,
        allergens: _allergens.toList(growable: false),
      );
      final en = _enCtrl.text.trim();
      if (en.isNotEmpty) {
        await repo.upsertEnTranslation(dishId: widget.dishId, storeId: store.id, name: en);
      }
      ref.invalidate(dishByIdProvider(widget.dishId));
      if (!mounted) return;
      _navBack();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _navBack() {
    if (_menuIdForNav != null) {
      context.go(AppRoutes.organizeFor(_menuIdForNav!));
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dishByIdProvider(widget.dishId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: _ErrorBody(
          message: '加载失败：$err',
          onRetry: () => ref.invalidate(dishByIdProvider(widget.dishId)),
        ),
      ),
      data: (d) {
        _hydrate(d);
        // Capture menu_id for Cancel/Save nav — lazy fetch.
        if (_menuIdForNav == null) {
          ref.read(dishRepositoryProvider).fetchMenuIdForDish(widget.dishId)
              .then((id) { if (mounted) setState(() => _menuIdForNav = id); });
        }
        return _buildForm(context, d);
      },
    );
  }

  // _buildForm(...) — keep the existing Scaffold / Column / section widgets
  // from the pre-rewrite file. Replace:
  //   - `_cancel()` body → _navBack();
  //   - Save TextButton onPressed → _saving ? null : _save;
  //   - Save TextButton label → _saving ? const Text('保存中…') : const Text('保存');
  // The form inner widgets (image, basic, description, translation, tags)
  // remain structurally unchanged but they now read from _nameCtrl/_priceCtrl
  // (populated by _hydrate) and the local state fields which are already
  // populated from the fetched Dish.
}

class _ErrorBody extends StatelessWidget { /* same shape as menu-manage */ }
```

**Implementation guidance:** copy the pre-rewrite file's widget tree verbatim inside `_buildForm(context, d)` — the only diffs are the three bulleted changes above. All the `_DishImageSection`, `_BasicInfoSection`, etc. classes can be retained as-is.

- [ ] **Step 5.2:** Smoke test — replace with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/edit/dish_repository.dart';
import 'package:menuray_merchant/features/edit/edit_providers.dart';
import 'package:menuray_merchant/features/edit/presentation/edit_dish_screen.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/shared/models/dish.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  @override Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override Session? get currentSession => null;
  @override Future<void> sendOtp(String phone) async {}
  @override Future<AuthResponse> verifyOtp({required String phone, required String token}) => throw UnimplementedError();
  @override Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override Future<void> signOut() async {}
}

class _FakeStoreRepository implements StoreRepository {
  @override Future<Store> currentStore() async =>
      const Store(id: 's1', name: '云间小厨·静安店', isCurrent: true);
  @override Future<void> updateStore({required String storeId, required String name, String? address, String? logoUrl}) async {}
}

class _FakeDishRepository implements DishRepository {
  @override Future<Dish> fetchDish(String dishId) async => Dish(
        id: dishId, name: '宫保鸡丁', nameEn: 'Kung Pao Chicken', price: 48,
        description: '经典川菜', isSignature: true, isRecommended: true,
      );
  @override Future<String> fetchMenuIdForDish(String dishId) async => 'm1';
  @override Future<void> updateDish({required String dishId, required String sourceName, String? sourceDescription, required double price, required String spiceLevel, required bool isSignature, required bool isRecommended, required bool isVegetarian, required List<String> allergens}) async {}
  @override Future<void> upsertEnTranslation({required String dishId, required String storeId, required String name}) async {}
}

void main() {
  testWidgets('EditDishScreen renders fetched dish fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
          dishRepositoryProvider.overrideWithValue(_FakeDishRepository()),
        ],
        child: const MaterialApp(home: EditDishScreen(dishId: 'd1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑菜品'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // Name field is populated — rendered via TextEditingController, so find by text:
    expect(find.text('宫保鸡丁'), findsWidgets); // appears in name field + translation zh row
  });
}
```

- [ ] **Step 5.3:** Analyze clean + this smoke test passes.

- [ ] **Step 5.4:** Commit:

```
feat(edit): wire edit_dish screen to dishByIdProvider + Save

Screen becomes ConsumerStatefulWidget reading dishByIdProvider(dishId).
Save writes dishes.update + optionally upserts dish_translations (EN).
Cancel/Save navigate back to /edit/organize/:menuId captured from
the dish's menu_id. Smoke test rewritten with Fake repos.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 6: organize_menu — wire to menuByIdProvider + ReorderableListView per category

**Files:**
- Modify: `frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/organize_menu_screen_smoke_test.dart` (full rewrite)

### Steps

- [ ] **Step 6.1:** Full rewrite:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/dish.dart';
import '../../../shared/widgets/dish_row.dart';
import '../../home/home_providers.dart';
import '../../manage/menu_management_provider.dart';

class OrganizeMenuScreen extends ConsumerStatefulWidget {
  const OrganizeMenuScreen({super.key, required this.menuId});
  final String menuId;
  @override
  ConsumerState<OrganizeMenuScreen> createState() => _OrganizeMenuScreenState();
}

class _OrganizeMenuScreenState extends ConsumerState<OrganizeMenuScreen> {
  // categoryId → optimistic ordered dish-list. Cleared after successful
  // write + invalidate.
  final Map<String, List<Dish>> _optimisticOrder = {};

  Future<void> _reorder(DishCategory cat, int oldIndex, int newIndex) async {
    final current = _optimisticOrder[cat.id] ?? List<Dish>.from(cat.dishes);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    setState(() => _optimisticOrder[cat.id] = current);

    final pairs = <({String dishId, int position})>[
      for (var i = 0; i < current.length; i++)
        (dishId: current[i].id, position: i),
    ];
    try {
      await ref.read(menuRepositoryProvider).reorderDishes(pairs);
      ref.invalidate(menuByIdProvider(widget.menuId));
      if (mounted) setState(() => _optimisticOrder.remove(cat.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimisticOrder.remove(cat.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('排序失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(menuByIdProvider(widget.menuId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: const Text('整理菜单'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.previewFor(widget.menuId)),
            child: const Text('下一步'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(menuByIdProvider(widget.menuId)),
        ),
        data: (menu) {
          final cats = menu.categories;
          if (cats.isEmpty) {
            return const Center(child: Text('暂无分类', style: TextStyle(color: Colors.grey)));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              for (final cat in cats) ...[
                _CategoryHeader(category: cat),
                _CategoryDishList(
                  category: cat,
                  dishes: _optimisticOrder[cat.id] ?? cat.dishes,
                  onReorder: (o, n) => _reorder(cat, o, n),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null, // add-dish is a later batch
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
    );
  }
}

class _CategoryDishList extends StatelessWidget {
  const _CategoryDishList({
    required this.category,
    required this.dishes,
    required this.onReorder,
  });
  final DishCategory category;
  final List<Dish> dishes;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: true,
      onReorder: onReorder,
      itemCount: dishes.length,
      itemBuilder: (ctx, i) {
        final d = dishes[i];
        return DishRow(
          key: ValueKey('${category.id}-${d.id}'),
          dish: d,
          onTap: () => context.go(AppRoutes.editDishFor(d.id)),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final DishCategory category;
  @override
  Widget build(BuildContext context) {
    /* keep the current implementation — only changes are colour tokens left as-is */
    /* ... */
  }
}

class _ErrorBody extends StatelessWidget { /* same shape as menu-manage */ }
```

Keep the current `_CategoryHeader` widget body untouched — only the reorder list inside it changes.

- [ ] **Step 6.2:** Smoke test — parallel to canonical (inject `menuRepositoryProvider` with a fake returning one category, one or two dishes). Assert seed category name (e.g. `'热菜'`) and one dish name render; do **not** simulate a drag.

- [ ] **Step 6.3:** Analyze clean + smoke passes.

- [ ] **Step 6.4:** Commit:

```
feat(edit): wire organize_menu to menuByIdProvider + reorder-on-drag

Screen becomes ConsumerStatefulWidget reading menuByIdProvider(menuId).
Each category's dish list is a ReorderableListView; drag-end writes
(dishId, position) pairs via MenuRepository.reorderDishes with
optimistic overlay + rollback-on-failure. Back goes to home;
下一步 navigates to /publish/preview/:menuId. "新增" disabled.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 7: preview_menu — wire to menuByIdProvider (read only)

**Files:**
- Modify: `frontend/merchant/lib/features/publish/presentation/preview_menu_screen.dart` (targeted edits)
- Modify: `frontend/merchant/test/smoke/preview_menu_screen_smoke_test.dart` (full rewrite)

### Steps

- [ ] **Step 7.1:** In `preview_menu_screen.dart`:
  - Change base class from `StatefulWidget` → `ConsumerStatefulWidget`, `State` → `ConsumerState`.
  - Constructor: `const PreviewMenuScreen({super.key, required this.menuId}); final String menuId;`.
  - Imports: add `flutter_riverpod`, `menuByIdProvider` import, `menu` model.
  - Replace the uses of `MockData.lunchMenu` with `ref.watch(menuByIdProvider(widget.menuId))`. Wrap the current body in `.when(loading/error/data)` like the canonical menu-manage. The segment-toggle state (`_deviceIdx`, `_langIdx`) stays local.
  - `_onBack` → `context.go(AppRoutes.organizeFor(widget.menuId))`.
  - `_onPublish` → `context.go(AppRoutes.publishedFor(widget.menuId))`.
  - `_onReturnEdit` → `context.go(AppRoutes.organizeFor(widget.menuId))`.

- [ ] **Step 7.2:** Smoke test rewrite:

```dart
// (same Fake pattern as canonical; override menuRepositoryProvider; 
//  MaterialApp(home: PreviewMenuScreen(menuId: 'm1'))
//  expect menu name to render somewhere on the screen)
```

- [ ] **Step 7.3:** Analyze clean + smoke passes.

- [ ] **Step 7.4:** Commit:

```
feat(publish): wire preview_menu to menuByIdProvider

Screen becomes ConsumerStatefulWidget reading menuByIdProvider(menuId);
local device/lang segment state preserved. Back → organizeFor(menuId),
发布 → publishedFor(menuId). No mutation this iteration.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 8: published — wire to menuByIdProvider (read only, QR slug)

**Files:**
- Modify: `frontend/merchant/lib/features/publish/presentation/published_screen.dart`
- Modify: `frontend/merchant/test/smoke/published_screen_smoke_test.dart`

### Steps

- [ ] **Step 8.1:** `published_screen.dart`:
  - `ConsumerStatefulWidget` → actually `ConsumerWidget` is enough (no local state). Constructor: `const PublishedScreen({super.key, required this.menuId}); final String menuId;`.
  - Replace `StatelessWidget`/`StatefulWidget` → `ConsumerWidget` with signature `Widget build(BuildContext context, WidgetRef ref)`.
  - Wire `menuByIdProvider(menuId)`. QR caption constructs `'https://menu.menuray.com/${menu.slug ?? '-'}'`.
  - Inside `_QrCard` add an optional prop `final String url;` and render it below the QR placeholder.
  - On `slug == null`: show a small "菜单未发布" badge in the QR area.

- [ ] **Step 8.2:** Smoke test — inject fake menu with `slug: 'yunjian-lunch'`, assert the URL fragment renders.

- [ ] **Step 8.3:** Analyze clean + smoke passes.

- [ ] **Step 8.4:** Commit.

Message:
```
feat(publish): wire published screen to menuByIdProvider for QR slug
```

---

## Task 9: settings — read-only wire-up for profile header

**Files:**
- Modify: `frontend/merchant/lib/features/store/presentation/settings_screen.dart`
- Modify: `frontend/merchant/test/smoke/settings_screen_smoke_test.dart`

### Steps

- [ ] **Step 9.1:** Change `SettingsScreen` to `ConsumerWidget`. Import `currentStoreProvider`.

- [ ] **Step 9.2:** Pass the `AsyncValue<Store>` from `ref.watch(currentStoreProvider)` into `_ProfileHeader`; `_ProfileHeader` accepts `final AsyncValue<Store> storeAsync` and renders:
  - `data`: real `store.name` + avatar (fallback icon if `logoUrl` null).
  - `loading`: subtle shimmer preserving header height.
  - `error`: name becomes "加载失败".

- [ ] **Step 9.3:** The `店铺信息` tile's `onTap` fires `context.go(AppRoutes.storeManage)`. The `子账号管理` tile also routes to store management for now (no sub-screen). Other tiles stay no-op.

- [ ] **Step 9.4:** Smoke test:

```dart
// Override authRepositoryProvider + storeRepositoryProvider
// expect find.text('店铺信息'), findsOneWidget;
// expect find.text(<fake store name>), findsOneWidget;
```

- [ ] **Step 9.5:** Analyze clean + smoke passes.

- [ ] **Step 9.6:** Commit:

```
feat(settings): read-only wire of profile header to currentStoreProvider
```

---

## Task 10: store_management — real store card + inline edit dialog + Save

Biggest task in the batch. Primary mutation.

**Files:**
- Modify: `frontend/merchant/lib/features/store/presentation/store_management_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/store_management_screen_smoke_test.dart` (full rewrite)

### Steps

- [ ] **Step 10.1:** Full rewrite:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/store.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../store_providers.dart';

class StoreManagementScreen extends ConsumerStatefulWidget {
  const StoreManagementScreen({super.key});
  @override
  ConsumerState<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends ConsumerState<StoreManagementScreen> {
  Store? _optimistic; // pending save

  Future<void> _edit(Store original) async {
    final result = await showDialog<_StoreEdit>(
      context: context,
      builder: (_) => _EditDialog(initial: original),
    );
    if (result == null) return;
    final pending = Store(
      id: original.id, name: result.name, address: result.address,
      logoUrl: original.logoUrl, isCurrent: original.isCurrent,
    );
    setState(() => _optimistic = pending);
    try {
      await ref.read(storeRepositoryProvider).updateStore(
        storeId: original.id, name: result.name, address: result.address,
      );
      ref.invalidate(currentStoreProvider);
      if (mounted) setState(() => _optimistic = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimistic = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ownerStoresProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => context.go(AppRoutes.settings),
        ),
        title: const Text('门店管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
        centerTitle: true,
        actions: [
          Tooltip(
            message: '多店管理敬请期待',
            child: TextButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增门店'),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(currentStoreProvider),
        ),
        data: (stores) {
          final display = [
            if (_optimistic != null) _optimistic!
            else if (stores.isNotEmpty) stores.first,
            ...stores.skip(1),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in display) ...[
                  _StoreCard(store: s, onEdit: () => _edit(s)),
                  const SizedBox(height: 16),
                ],
                const _BottomCaption(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget { /* preserve the existing card but add an `onEdit` VoidCallback + trailing edit icon button */ }
class _BottomCaption extends StatelessWidget { /* text: "多店管理敬请期待" */ }
class _EditDialog extends StatefulWidget { /* two TextFields + Cancel/Save, returns (_StoreEdit) via Navigator.pop */ }
class _StoreEdit { final String name; final String? address; const _StoreEdit({required this.name, this.address}); }
class _ErrorBody extends StatelessWidget { /* same shape */ }
```

Retain the pre-rewrite `_StoreCard` visuals; add the edit icon in the card header with `onPressed: onEdit`.

- [ ] **Step 10.2:** Smoke test: inject a fake `StoreRepository` that `currentStore()` returns a seed store; assert the store name renders + an edit icon is found (one `Icons.edit` in the card).

- [ ] **Step 10.3:** Analyze clean + smoke passes.

- [ ] **Step 10.4:** Commit:

```
feat(store): wire store_management to ownerStoresProvider + inline edit

Screen becomes ConsumerStatefulWidget showing the (single) owned
store with an inline edit dialog (name + address). Save flows
through StoreRepository.updateStore with optimistic overlay +
rollback-on-failure. 新增门店 disabled until multi-store (P2).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 11: Existing call sites — fix menu-manage quick actions to carry menuId

**Files:**
- Modify: `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart` (two hunks)

### Steps

- [ ] **Step 11.1:** Find:

```dart
          _QuickActionsRow(
            onEditContent: () => context.go(AppRoutes.organize),
            onShare: () => context.go(AppRoutes.published),
            onStatistics: () => context.go(AppRoutes.statistics),
          ),
```

Replace with:

```dart
          _QuickActionsRow(
            onEditContent: () => context.go(AppRoutes.organizeFor(widget.menuId)),
            onShare: () => context.go(AppRoutes.publishedFor(widget.menuId)),
            onStatistics: () => context.go(AppRoutes.statistics),
          ),
```

- [ ] **Step 11.2:** Smoke test for menu_management unchanged (the current one uses literal string assertions; no call-site assertion breaks).

- [ ] **Step 11.3:** Commit:

```
fix(nav): route menu-manage quick actions to new :menuId paths

After Task 4 the old parameter-less /edit/organize and /publish/done
no longer match any GoRoute.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 12: Full analyze + test sweep

**Files:** none modified unless a regression surfaces.

### Steps

- [ ] **Step 12.1:** `cd frontend/merchant && /home/coder/flutter/bin/flutter analyze` — `No issues found!`.

- [ ] **Step 12.2:** `cd frontend/merchant && /home/coder/flutter/bin/flutter test` — **33/33** pass.

- [ ] **Step 12.3:** Any regression: fix + commit with message `chore(merchant): fix analyze/test regressions after Batch 1 wire-up`.

---

## Task 13: Docs update — roadmap + architecture

**Files:**
- Modify: `docs/roadmap.md`
- Modify: `docs/architecture.md` (find the "wired screens" tally and bump it)

### Steps

- [ ] **Step 13.1:** In `docs/roadmap.md`, under `### Merchant app — connect to real backend`, find:

```
- [ ] **L** Remaining 14 screens wired to Supabase (capture / edit / publish / store / settings)
```

Replace with:

```
- [x] **M** Batch 1 (edit_dish / organize_menu / preview_menu / published / settings / store_management) wired to Supabase
- [ ] **M** Batch 2 (capture / correct_image / processing / select_photos) wired to Supabase + parse-menu realtime
- [ ] **S** Remaining 4 screens (ai_optimize / select_template / custom_theme / statistics) — deferred past P0
```

- [ ] **Step 13.2:** In `docs/architecture.md`, update the count of wired screens from 3 → 9 wherever it's referenced.

- [ ] **Step 13.3:** Commit:

```
docs: mark P0 Batch 1 wire-up done (9/17 screens)
```

---

## Task 14: End-to-end manual verification

Manual — no commit. Record in the PR description.

### Steps

- [ ] **Step 14.1:** `cd backend && supabase status` — confirm `API URL: http://127.0.0.1:54321`. `supabase start` if needed. `supabase db reset` to re-seed if data is stale.

- [ ] **Step 14.2:** Re-apply the `SHOW_SEED_LOGIN` patch on `login_screen.dart:158` (`if (kDebugMode || const bool.fromEnvironment('SHOW_SEED_LOGIN'))`) — to be reverted at Step 14.11.

- [ ] **Step 14.3:** `cd frontend/merchant && /home/coder/flutter/bin/flutter build web --profile --dart-define=SUPABASE_URL=https://54321--main--apang--kuaifan.coder.dootask.com --dart-define=SHOW_SEED_LOGIN=true`.

- [ ] **Step 14.4:** `cd frontend/merchant/build/web && python3 -m http.server 8080 --bind 0.0.0.0`.

- [ ] **Step 14.5:** Visit `https://8080--main--apang--kuaifan.coder.dootask.com/`. Tap 种子账户登录 → land on home.

- [ ] **Step 14.6:** Tap the menu card → `/manage/menu/<uuid>` loads. Tap 编辑内容 → `/edit/organize/<uuid>`. Drag a dish → verify position update persists on refresh. Tap the dish → `/edit/dish/<uuid>`.

- [ ] **Step 14.7:** On edit_dish, change the EN name to "Kung Pao Chicken v2", tap 保存. Hard-reload → verify the new EN name is re-hydrated. Then reset it back to "Kung Pao Chicken" and save again.

- [ ] **Step 14.8:** From home → menu-manage → 分享 → lands on `/publish/done/<uuid>` with the `yunjian-lunch` (or seed) slug URL visible in the QR card.

- [ ] **Step 14.9:** From home → bottom nav / link to `/settings`. Profile header shows `云间小厨 · 静安店`. Tap 店铺信息 → lands on `/store/list`. Tap edit → dialog → change address → 保存. Refresh → address persists.

- [ ] **Step 14.10:** Error path: `supabase stop` → refresh a wired screen → error body + 重试 shows. `supabase start` → 重试 → data reloads.

- [ ] **Step 14.11:** Revert the `SHOW_SEED_LOGIN` patch. Confirm `git status` is clean afterwards.

- [ ] **Step 14.12:** Record outcomes (pass/fail per step) in the batch report.

---

## Self-review (post-plan)

- **Spec coverage:**
  - §1 in-scope bullets → Tasks 0–11.
  - §3.1 path-param routes → Task 4.
  - §3.2 edit-dish save + EN upsert → Task 5.
  - §3.3 organize reorder → Task 6.
  - §3.4 store edit on store_management → Task 10.
  - §3.5 owner-store single-source → Task 3 (`ownerStoresProvider`) + Task 10.
  - §5 component changes → Tasks 0–3, 5–10.
  - §5.7 route helpers → Task 4.
  - §5.8 call sites → Tasks 5–10 + Task 11.
  - §6 error handling → each screen task’s `_ErrorBody` + SnackBar patterns.
  - §7 testing → Tasks 5–10 smoke rewrites + Task 12 sweep.
  - §9 docs → Task 13.
- **Placeholder scan:** two bodies are referenced with `/* preserve / same shape as menu-manage */` — these are acceptable because the original widget trees are in-repo and the canonical plan's `_ErrorBody` is verbatim reusable. The implementer reads the pre-rewrite file once per screen to lift the untouched widget classes.
- **Type consistency:** `{String dishId, int position}` record shape consistent between spec §5.4, Task 1 Step 1.1, Task 6 Step 6.1. `DishRepository.updateDish` signature consistent between spec §5.3, Task 2 Step 2.1, Task 5 Step 5.1. `menuByIdProvider(menuId)` imported from `features/manage/menu_management_provider.dart` across Tasks 6, 7, 8, 11 — unchanged location.
- **Parallelisability:** Tasks 0, 1, 2, 3, 4 are sequential (foundation). Tasks 5, 6, 7, 8, 9, 10 have no cross-dependencies after Task 4 lands with the constructor stubs — safe to fan out to subagents. Task 11 waits on Task 5 (not strictly — any order works since it only edits menu-management). Tasks 12, 13, 14 run after the fan-in.
- **Out-of-scope reaffirmation:** no `parse-menu` realtime, no camera, no image upload, no category reorder, no `menus.status` mutation. `select_photos` unchanged.
- **Risk carry-over:** Spec §10 item 3 (category reorder). The plan does not include it. If Task 6’s implementer finds wrapping a second outer `ReorderableListView` around the categories takes <10 more lines, include it in the same commit and update the message accordingly — else leave for a follow-up.
