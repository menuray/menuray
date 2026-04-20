# Menu-manage Screen ↔ Supabase Wire-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the merchant app's menu-manage screen to Supabase: route carries the real menu id, a single nested PostgREST select hydrates the screen, and the per-dish sold-out toggle persists via `dishes.update({sold_out})` with optimistic UI + rollback-on-failure.

**Architecture:** Extends ADR-017 — thin repository wrapping `SupabaseClient`, hand-written mappers, Riverpod `FutureProvider.family` keyed by menu id, `ConsumerStatefulWidget` that owns a local optimistic overlay map. No new ADR. Time-slot radio remains local-only this iteration.

**Tech Stack:** Flutter 3.11.5, Riverpod 2.6, go_router 14.6, supabase_flutter 2.12, Supabase Postgres/Auth.

**Spec:** [docs/superpowers/specs/2026-04-20-menu-manage-supabase-wire-up-design.md](../specs/2026-04-20-menu-manage-supabase-wire-up-design.md)

**Repo assumptions:**
- Flutter app root: `frontend/merchant/`
- All `flutter`/`dart` commands run from `frontend/merchant/`.
- Flutter SDK at `/home/coder/flutter/bin/flutter`.
- Current branch: `main`. Base commit: `aa4b4d4` (spec committed).

---

## Task 1: `MenuRepository` — `fetchMenu` + `setDishSoldOut` + DRY select string

**Files:**
- Modify: `frontend/merchant/lib/features/home/menu_repository.dart` (full rewrite)

### Steps

- [ ] **Step 1.1: Replace `lib/features/home/menu_repository.dart`**

Replace the entire file with:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/menu.dart';

// Shared select string: one source of truth for the menu + nested graph,
// used by both listMenusForStore and fetchMenu.
const _menuSelect = '''
  id, name, status, updated_at, cover_image_url,
  time_slot, time_slot_description,
  categories(
    id, source_name, position,
    dishes(
      id, source_name, source_description, price, image_url,
      spice_level, confidence, is_signature, is_recommended,
      is_vegetarian, sold_out, allergens, position,
      dish_translations(locale, name)
    )
  )
''';

class MenuRepository {
  MenuRepository(this._client);

  final SupabaseClient _client;

  Future<List<Menu>> listMenusForStore(String storeId) async {
    final rows = await _client
        .from('menus')
        .select(_menuSelect)
        .eq('store_id', storeId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(menuFromSupabase)
        .toList(growable: false);
  }

  Future<Menu> fetchMenu(String menuId) async {
    final row = await _client
        .from('menus')
        .select(_menuSelect)
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
}
```

- [ ] **Step 1.2: Verify analyze is clean**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 1.3: Verify existing tests still pass**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter test test/smoke/home_screen_smoke_test.dart
```
Expected: 1 test passes (home still uses `listMenusForStore` which uses the extracted `_menuSelect`; behavior unchanged).

- [ ] **Step 1.4: Commit**

```bash
git add frontend/merchant/lib/features/home/menu_repository.dart
git commit -m "$(cat <<'EOF'
feat(home): add MenuRepository.fetchMenu + setDishSoldOut

Extracts the shared nested-select string as a private const so
listMenusForStore and fetchMenu share one source of truth. Adds
setDishSoldOut for the menu-manage screen's sold-out toggle to
persist via RLS-gated dishes.update().

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `menuByIdProvider` family

**Files:**
- Create: `frontend/merchant/lib/features/manage/menu_management_provider.dart`

### Steps

- [ ] **Step 2.1: Create `lib/features/manage/menu_management_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/menu.dart';
import '../auth/auth_providers.dart';
import '../home/home_providers.dart';

final menuByIdProvider =
    FutureProvider.family<Menu, String>((ref, menuId) async {
  ref.watch(authStateProvider); // re-evaluate on auth change
  return ref.watch(menuRepositoryProvider).fetchMenu(menuId);
});
```

- [ ] **Step 2.2: Verify analyze is clean**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 2.3: Commit**

```bash
git add frontend/merchant/lib/features/manage/menu_management_provider.dart
git commit -m "$(cat <<'EOF'
feat(manage): add menuByIdProvider FutureProvider.family

FutureProvider keyed by menu id that re-evaluates on auth change.
Consumed by the menu-manage screen (Task 3).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Router + `MenuManagementScreen` rewrite + smoke test

This task couples three changes that must land together (the screen's constructor gains a required `menuId`, which breaks the old `const MenuManagementScreen()` GoRoute builder and the old smoke test).

**Files:**
- Modify: `frontend/merchant/lib/router/app_router.dart` (two hunks)
- Modify: `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/menu_management_screen_smoke_test.dart` (full rewrite)

### Steps

- [ ] **Step 3.1: Add `menuManageFor` helper and update the GoRoute in `app_router.dart`**

Two targeted edits (do NOT full-rewrite the file):

**Edit A (inside `class AppRoutes`)** — directly after the `menuManage` constant, add:

Find:
```dart
  static const menuManage = '/manage/menu';
```

Replace with:
```dart
  static const menuManage = '/manage/menu';
  static String menuManageFor(String id) => '/manage/menu/$id';
```

**Edit B (GoRoute for menu-manage)** — change the path and the builder to read `menuId` from path params.

Find:
```dart
      GoRoute(path: AppRoutes.menuManage, builder: (c, s) => const MenuManagementScreen()),
```

Replace with:
```dart
      GoRoute(
        path: '${AppRoutes.menuManage}/:id',
        builder: (c, s) =>
            MenuManagementScreen(menuId: s.pathParameters['id']!),
      ),
```

- [ ] **Step 3.2: Replace `lib/features/manage/presentation/menu_management_screen.dart`**

Full replace with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/dish.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../menu_management_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key, required this.menuId});

  final String menuId;

  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  // Local optimistic overlay: dishId → pending sold-out value (cleared on
  // either backend confirmation or error).
  final Map<String, bool> _optimisticSoldOut = {};

  // Time-slot remains local-only (not persisted this iteration).
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
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

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
        data: (menu) => _buildContent(menu),
      ),
    );
  }

  Widget _buildContent(Menu menu) {
    final timeSlot = _timeSlotOverride ?? menu.timeSlot;
    final dishes =
        menu.categories.expand((c) => c.dishes).toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoCard(),
          const SizedBox(height: 20),
          _QuickActionsRow(
            onEditContent: () => context.go(AppRoutes.organize),
            onShare: () => context.go(AppRoutes.published),
            onStatistics: () => context.go(AppRoutes.statistics),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.restaurant, title: '售罄管理'),
          const SizedBox(height: 12),
          _SoldOutSection(
            dishes: dishes,
            effectiveSoldOut: (d) =>
                _optimisticSoldOut[d.id] ?? d.soldOut,
            onToggle: _toggleSoldOut,
          ),
          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.schedule, title: '营业时段'),
          const SizedBox(height: 12),
          _TimeSlotSection(
            selected: timeSlot,
            onChanged: (slot) =>
                setState(() => _timeSlotOverride = slot),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.menuAsync});

  final AsyncValue<Menu> menuAsync;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final title = menuAsync.maybeWhen(
      data: (m) => m.name,
      orElse: () => '加载中…',
    );
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 16, color: AppColors.secondary),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.more_vert, color: AppColors.secondary),
        ),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.ink, fontSize: 14)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card  (content remains hardcoded — analytics wiring is a later pass)
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1C1C18),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _InfoCardContent()),
          SizedBox(width: 16),
          _QrThumbnail(),
        ],
      ),
    );
  }
}

class _InfoCardContent extends StatelessWidget {
  const _InfoCardContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const StatusChip(label: '已发布', variant: ChipVariant.published),
            const SizedBox(width: 10),
            Text(
              '更新于 3 天前',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '浏览量',
          style: TextStyle(fontSize: 12, color: AppColors.secondary),
        ),
        const SizedBox(height: 2),
        const Text(
          '1,247',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _QrThumbnail extends StatelessWidget {
  const _QrThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E2DB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26000000)),
      ),
      child:
          const Icon(Icons.qr_code_2, size: 44, color: AppColors.primaryDark),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onEditContent,
    required this.onShare,
    required this.onStatistics,
  });

  final VoidCallback onEditContent;
  final VoidCallback onShare;
  final VoidCallback onStatistics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
              icon: Icons.edit, label: '编辑内容', onTap: onEditContent),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _ActionButton(icon: Icons.block, label: '售罄管理'),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _ActionButton(icon: Icons.attach_money, label: '调价'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(icon: Icons.share, label: '分享', onTap: onShare),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
              icon: Icons.analytics, label: '数据', onTap: onStatistics),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1C1C18),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sold-out section
// ---------------------------------------------------------------------------

class _SoldOutSection extends StatelessWidget {
  const _SoldOutSection({
    required this.dishes,
    required this.effectiveSoldOut,
    required this.onToggle,
  });

  final List<Dish> dishes;
  final bool Function(Dish) effectiveSoldOut;
  final Future<void> Function(String dishId, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final dish in dishes) ...[
            _SoldOutItem(
              dish: dish,
              isSoldOut: effectiveSoldOut(dish),
              onToggle: (v) => onToggle(dish.id, v),
            ),
            if (dish != dishes.last)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _SoldOutItem extends StatelessWidget {
  const _SoldOutItem({
    required this.dish,
    required this.isSoldOut,
    required this.onToggle,
  });

  final Dish dish;
  final bool isSoldOut;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSoldOut
                  ? const Color(0xFFE6E2DB)
                  : AppColors.primaryDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant,
              size: 24,
              color: isSoldOut ? AppColors.secondary : AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dish.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSoldOut ? AppColors.secondary : AppColors.ink,
              ),
            ),
          ),
          if (isSoldOut) ...[
            const StatusChip(label: '已售罄', variant: ChipVariant.soldOut),
            const SizedBox(width: 12),
          ],
          Switch(
            value: isSoldOut,
            onChanged: onToggle,
            activeThumbColor: AppColors.error,
            activeTrackColor: AppColors.error.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time slot section  (local-only, not persisted)
// ---------------------------------------------------------------------------

class _TimeSlotSection extends StatelessWidget {
  const _TimeSlotSection({required this.selected, required this.onChanged});

  final MenuTimeSlot selected;
  final ValueChanged<MenuTimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _TimeSlotOption(
            slot: MenuTimeSlot.lunch,
            label: '午市',
            subtitle: '11:00–14:00',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.dinner,
            label: '晚市',
            subtitle: '17:00–22:00',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.allDay,
            label: '全天',
            subtitle: '营业时间内',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.seasonal,
            label: '季节限定',
            subtitle: '自定义日期',
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TimeSlotOption extends StatelessWidget {
  const _TimeSlotOption({
    required this.slot,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final MenuTimeSlot slot;
  final String label;
  final String subtitle;
  final MenuTimeSlot selected;
  final ValueChanged<MenuTimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == slot;
    return GestureDetector(
      onTap: () => onChanged(slot),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            _RadioIndicator(selected: isSelected),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primaryDark : AppColors.secondary,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark,
                ),
              ),
            )
          : null,
    );
  }
}
```

- [ ] **Step 3.3: Replace `test/smoke/menu_management_screen_smoke_test.dart`**

Full replace with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/menu_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/manage/presentation/menu_management_screen.dart';
import 'package:menuray_merchant/shared/models/category.dart';
import 'package:menuray_merchant/shared/models/dish.dart';
import 'package:menuray_merchant/shared/models/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Session? get currentSession => null;
  @override
  Future<void> sendOtp(String phone) async {}
  @override
  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      throw UnimplementedError();
  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<List<Menu>> listMenusForStore(String storeId) async => [];

  @override
  Future<Menu> fetchMenu(String menuId) async => Menu(
        id: menuId,
        name: '午市套餐 2025 春',
        status: MenuStatus.published,
        updatedAt: DateTime(2026, 4, 16),
        timeSlot: MenuTimeSlot.lunch,
        timeSlotDescription: '11:00–14:00',
        categories: const [
          DishCategory(
            id: 'c_hot',
            name: '热菜',
            dishes: [
              Dish(id: 'd_kp', name: '宫保鸡丁', price: 48),
            ],
          ),
        ],
      );

  @override
  Future<void> setDishSoldOut({
    required String dishId,
    required bool soldOut,
  }) async {}
}

void main() {
  testWidgets('MenuManagementScreen renders menu name and dish from provider',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
        ],
        child: const MaterialApp(
          home: MenuManagementScreen(menuId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('编辑内容'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('宫保鸡丁'), findsOneWidget);
  });
}
```

- [ ] **Step 3.4: Run the menu-manage smoke test**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter test test/smoke/menu_management_screen_smoke_test.dart
```
Expected: `+1: All tests passed!`

- [ ] **Step 3.5: Verify analyze is clean**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3.6: Commit**

```bash
git add frontend/merchant/lib/router/app_router.dart \
        frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart \
        frontend/merchant/test/smoke/menu_management_screen_smoke_test.dart
git commit -m "$(cat <<'EOF'
feat(manage): wire menu-manage screen to Supabase menuByIdProvider

Route becomes /manage/menu/:id; screen is now a ConsumerStatefulWidget
that reads menuByIdProvider(menuId), shows loading/error/data states,
and persists the dish sold-out toggle via MenuRepository.setDishSoldOut
with optimistic UI + rollback-on-failure. Top-bar title is dynamic.
Time-slot radio stays local-only this iteration.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update call sites (home + statistics)

Task 3 changed the GoRoute path — existing `context.go(AppRoutes.menuManage)` calls now navigate to `/manage/menu` which no longer matches any route. Fix both call sites.

**Files:**
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart:214` (one hunk)
- Modify: `frontend/merchant/lib/features/manage/presentation/statistics_screen.dart:35` (one hunk)

### Steps

- [ ] **Step 4.1: Update home MenuCard onTap**

In `lib/features/home/presentation/home_screen.dart`, find:

```dart
                  child: MenuCard(
                    menu: menu,
                    onTap: () => context.go(AppRoutes.menuManage),
                  ),
```

Replace with:

```dart
                  child: MenuCard(
                    menu: menu,
                    onTap: () => context.go(AppRoutes.menuManageFor(menu.id)),
                  ),
```

- [ ] **Step 4.2: Update statistics back button**

In `lib/features/manage/presentation/statistics_screen.dart`, find:

```dart
          onPressed: () => context.go(AppRoutes.menuManage),
```

Replace with:

```dart
          onPressed: () => context.go(AppRoutes.home),
```

- [ ] **Step 4.3: Run home + statistics smoke tests**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter test test/smoke/home_screen_smoke_test.dart test/smoke/statistics_screen_smoke_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 4.4: Verify analyze is clean**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4.5: Commit**

```bash
git add frontend/merchant/lib/features/home/presentation/home_screen.dart \
        frontend/merchant/lib/features/manage/presentation/statistics_screen.dart
git commit -m "$(cat <<'EOF'
fix(nav): route call sites to the new /manage/menu/:id path

Home MenuCard.onTap now passes menu.id via AppRoutes.menuManageFor.
Statistics back button points at /home (the old path-less
/manage/menu no longer matches any GoRoute after Task 3's change).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Full analyze + test sweep

**Files:** none modified unless a regression surfaces

### Steps

- [ ] **Step 5.1: Full analyze**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5.2: Full test suite**

```bash
cd frontend/merchant && /home/coder/flutter/bin/flutter test
```
Expected: all tests pass (previously 33; still 33 — no tests added or removed). If any smoke test fails because its screen indirectly depends on a newly-provider-backed path, report which test and stop.

- [ ] **Step 5.3: If a fix was needed, commit it**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(merchant): fix analyze/test regressions after menu-manage wire-up

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(Skip if 5.1 + 5.2 were already clean.)

---

## Task 6: Roadmap update

**Files:**
- Modify: `docs/roadmap.md` (one line)

### Steps

- [ ] **Step 6.1: Check the existing roadmap bullet**

Open `docs/roadmap.md`. Inside the `### Merchant app — connect to real backend` section, find the line:

```
- [ ] **M** Menu-manage screen wired to Supabase
```

Replace with:

```
- [x] **M** Menu-manage screen wired to Supabase (read + sold-out mutation)
```

- [ ] **Step 6.2: Commit**

```bash
git add docs/roadmap.md
git commit -m "$(cat <<'EOF'
docs(roadmap): mark menu-manage Supabase wire-up done

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: End-to-end manual verification against local Supabase

Manual — produces no commit. Record the outcome in the PR description / task log.

### Steps

- [ ] **Step 7.1: Confirm the local Supabase stack is running**

```bash
cd backend && supabase status
```
Expected: API URL listed at `http://127.0.0.1:54321`. If not running, `supabase start`.

- [ ] **Step 7.2: Build the web app**

```bash
cd frontend/merchant
/home/coder/flutter/bin/flutter build web --profile \
  --dart-define=SUPABASE_URL=https://54321--main--apang--kuaifan.coder.dootask.com \
  --dart-define=SHOW_SEED_LOGIN=true
```

**NOTE for the implementer:** the `SHOW_SEED_LOGIN` dart-define requires the temporary patch to `login_screen.dart` line 158 (`if (kDebugMode || const bool.fromEnvironment('SHOW_SEED_LOGIN'))`). This patch was applied+reverted during the previous iteration's Task 10. If it was not re-applied, either (a) re-apply it just for this E2E and revert before committing, or (b) sign in via a `curl` POST to `/auth/v1/token?grant_type=password` and paste the returned session into `localStorage`. Easiest is (a).

- [ ] **Step 7.3: Serve the static build**

```bash
cd frontend/merchant/build/web
python3 -m http.server 8080 --bind 0.0.0.0
```

- [ ] **Step 7.4: Open the app**

Visit `https://8080--main--apang--kuaifan.coder.dootask.com/` in your browser. Hard-reload if cached.

- [ ] **Step 7.5: Tap 种子账户登录 → land on home**

Expected: home renders `云间小厨 · 静安店` top bar and one menu card `午市套餐 2025 春`.

- [ ] **Step 7.6: Tap the menu card**

Expected: URL changes to `/manage/menu/<uuid>` (the seed menu's real uuid visible in the address bar). The screen loads and shows:
- Top-bar title `午市套餐 2025 春`
- 售罄管理 list with the 5 seed dishes (`口水鸡`, `凉拌黄瓜`, `川北凉粉`, `宫保鸡丁`, `麻婆豆腐`)
- Any dish where seed.sql set `sold_out = true` shows the red 已售罄 chip and the Switch on.

- [ ] **Step 7.7: Toggle a dish sold-out**

Pick any dish whose Switch is off (e.g. `宫保鸡丁`). Tap the Switch.

Expected:
- Switch animates to on immediately (optimistic).
- No SnackBar (no error).
- Value persists: refresh the page, toggle stays in new state.

- [ ] **Step 7.8: Verify in Supabase Studio**

Open http://localhost:54323, navigate to the `dishes` table, confirm the `sold_out` column now shows `true` for the dish you toggled.

- [ ] **Step 7.9: Error-path check (optional but recommended)**

Stop Supabase locally (`supabase stop`), reload the menu-manage page. Expected: error body with 重试 button. Restart Supabase (`supabase start`), tap 重试. Expected: data re-loads.

- [ ] **Step 7.10: Revert the temporary login patch**

If you re-applied the `SHOW_SEED_LOGIN` patch in Step 7.2, revert it now:

```bash
cd frontend/merchant
# Verify the patch line is currently the 2-condition version, then revert:
sed -i 's|if (kDebugMode || const bool.fromEnvironment('\''SHOW_SEED_LOGIN'\'')) \.\.\.\[|if (kDebugMode) \.\.\.\[|' \
  lib/features/auth/presentation/login_screen.dart
/home/coder/flutter/bin/flutter analyze
git status   # Expect: nothing to commit (patch reverted, worktree clean)
```

- [ ] **Step 7.11: Record the verification**

Note pass/fail for Steps 7.5–7.9 in the PR description.

---

## Self-review (post-plan)

- **Spec coverage:**
  - §1 in-scope items → covered by Tasks 1–4 (repo methods, provider family, screen rewrite, dynamic title, smoke test, route/home/statistics fixups).
  - §3.1 decision (route path param) → Task 3 Step 3.1.
  - §3.2 decision (sold-out only) → Task 1's `setDishSoldOut`; Task 3 screen rewrite. Time-slot remains local-only (`_timeSlotOverride`).
  - §3.3 decision (optimistic overlay + rollback) → Task 3 Step 3.2, `_toggleSoldOut`.
  - §5.1 (`fetchMenu` + `setDishSoldOut` + DRY const) → Task 1.
  - §5.2 (`menuByIdProvider`) → Task 2.
  - §5.3 (route + `menuManageFor`) → Task 3 Step 3.1.
  - §5.4 (screen rewrite) → Task 3 Step 3.2.
  - §5.5 (home MenuCard.onTap) → Task 4 Step 4.1.
  - §5.6 (statistics back button) → Task 4 Step 4.2.
  - §5.7 (smoke test) → Task 3 Step 3.3.
  - §6 error handling table → covered by `_toggleSoldOut` SnackBar, `_ErrorBody`, retry callback.
  - §7 testing → Task 3 Step 3.3 + Task 5.
  - §8 no new deps → confirmed.
  - §9 docs follow-ups → Task 6.
  - §10 risks → documented; `statistics_screen.dart:35` back-button fix is the only scope creep and is explicit in Task 4 Step 4.2.
- **Placeholder scan:** no TBD / TODO / "implement later" / "similar to Task N". The one unverified assumption is the pre-existing statistics smoke test — if it doesn't exist, Task 4 Step 4.3 will silently skip it (flutter test accepts non-existent files with a no-op on a per-file basis; if it errors, the implementer reports and Task 4 Step 4.3 becomes "run only home smoke test").
- **Type consistency:** `MenuRepository.fetchMenu` / `setDishSoldOut` signatures match between Tasks 1, 2, 3. `menuByIdProvider(menuId)` signature consistent across Tasks 2, 3. `AppRoutes.menuManageFor(String id)` signature consistent across Tasks 3, 4. `_optimisticSoldOut` / `_timeSlotOverride` field names match between Task 3's rewrite and the self-review's §5.4 summary. Fake repo method shapes in Task 3 Step 3.3 match the real `MenuRepository` interface in Task 1.
