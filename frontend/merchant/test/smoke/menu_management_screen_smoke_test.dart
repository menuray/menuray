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

import '../support/test_harness.dart';

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
  _FakeMenuRepository({this.timeSlot = MenuTimeSlot.lunch});

  MenuTimeSlot timeSlot;
  String? lastUpdatedTimeSlot;

  @override
  Future<List<Menu>> listMenusForStore(String storeId) async => [];

  @override
  Future<Menu> fetchMenu(String menuId) async => Menu(
        id: menuId,
        name: '午市套餐 2025 春',
        status: MenuStatus.published,
        updatedAt: DateTime(2026, 4, 16),
        timeSlot: timeSlot,
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

  @override
  Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {}

  @override
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
    String? timeSlot,
  }) async {
    if (timeSlot != null) lastUpdatedTimeSlot = timeSlot;
  }

  @override
  Future<String> duplicateMenu(String menuId) async => "new-menu";
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
        child: zhMaterialApp(
          home: const MenuManagementScreen(menuId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('编辑内容'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('宫保鸡丁'), findsOneWidget);
  });

  testWidgets('tap All-day radio persists time_slot via updateMenu',
      (tester) async {
    final repo = _FakeMenuRepository();  // seeded with lunch
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          menuRepositoryProvider.overrideWithValue(repo),
        ],
        child: zhMaterialApp(
          home: const MenuManagementScreen(menuId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the All-day radio row by its localized label and tap it.
    final allDay = find.text('全天');
    await tester.ensureVisible(allDay);
    await tester.pumpAndSettle();
    await tester.tap(allDay);
    await tester.pumpAndSettle();

    expect(repo.lastUpdatedTimeSlot, 'all_day');
  });
}
