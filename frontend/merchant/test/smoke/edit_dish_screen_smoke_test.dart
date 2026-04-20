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

import '../support/test_harness.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Session? get currentSession => null;
  @override
  Future<void> sendOtp(String phone) async {}
  @override
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      throw UnimplementedError();
  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeStoreRepository implements StoreRepository {
  @override
  Future<Store> currentStore() async =>
      const Store(id: 's1', name: '云间小厨·静安店', isCurrent: true);
  @override
  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {}
}

class _FakeDishRepository implements DishRepository {
  @override
  Future<Dish> fetchDish(String dishId) async => Dish(
        id: dishId,
        name: '宫保鸡丁',
        nameEn: 'Kung Pao Chicken',
        price: 48,
        description: '经典川菜',
        isSignature: true,
        isRecommended: true,
      );
  @override
  Future<String> fetchMenuIdForDish(String dishId) async => 'm1';
  @override
  Future<void> updateDish({
    required String dishId,
    required String sourceName,
    String? sourceDescription,
    required double price,
    required String spiceLevel,
    required bool isSignature,
    required bool isRecommended,
    required bool isVegetarian,
    required List<String> allergens,
  }) async {}
  @override
  Future<void> upsertEnTranslation({
    required String dishId,
    required String storeId,
    required String name,
  }) async {}
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
        child: zhMaterialApp(home: const EditDishScreen(dishId: 'd1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑菜品'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // Name field is populated — rendered via TextEditingController, so find by text:
    expect(find.text('宫保鸡丁'), findsWidgets); // appears in name field + translation zh row
  });
}
