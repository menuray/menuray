import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/menu_repository.dart';
import 'package:menuray_merchant/features/publish/presentation/published_screen.dart';
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
        slug: 'yunjian-lunch',
      );

  @override
  Future<void> setDishSoldOut({
    required String dishId,
    required bool soldOut,
  }) async {}

  @override
  Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {}
}

void main() {
  testWidgets('PublishedScreen renders URL fragment from menu slug', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
        ],
        child: const MaterialApp(home: PublishedScreen(menuId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('yunjian-lunch'), findsOneWidget);
  });
}
