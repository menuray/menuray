import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/menu_repository.dart';
import 'package:menuray_merchant/features/home/presentation/home_screen.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/shared/models/category.dart';
import 'package:menuray_merchant/shared/models/menu.dart';
import 'package:menuray_merchant/shared/models/store.dart';
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

class _FakeStoreRepository implements StoreRepository {
  @override
  Future<Store> fetchById(String storeId) async => const Store(
        id: 'store-seed',
        name: '云间小厨',
        address: '上海市静安区',
        isCurrent: true,
      );
  @override
  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {}

  @override
  Future<void> setDishTracking(String storeId, bool enabled) async {}
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<List<Menu>> listMenusForStore(String storeId) async => [
        Menu(
          id: 'm1',
          name: '午市套餐 2025 春',
          status: MenuStatus.published,
          updatedAt: DateTime(2026, 4, 16),
          timeSlot: MenuTimeSlot.lunch,
          timeSlotDescription: '午市 11:00–14:00',
          categories: const <DishCategory>[],
        ),
      ];

  @override
  Future<Menu> fetchMenu(String menuId) => throw UnimplementedError();

  @override
  Future<void> setDishSoldOut({required String dishId, required bool soldOut}) =>
      throw UnimplementedError();

  @override
  Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {}

  @override
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
  }) async {}
}

void main() {
  testWidgets('HomeScreen renders store name and seed menu from providers',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
          testActiveStoreOverride(storeId: 'store-seed'),
        ],
        child: zhMaterialApp(home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('云间小厨'), findsOneWidget);
    expect(find.text('Curated Menus'), findsOneWidget);
    expect(find.text('1 Total'), findsOneWidget);
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('新建菜单'), findsOneWidget);
  });
}
