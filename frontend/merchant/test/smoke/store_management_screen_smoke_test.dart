import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/features/store/presentation/store_management_screen.dart';
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
        id: 's1',
        name: '云间小厨·静安店',
        address: '上海·静安',
        isCurrent: true,
      );

  @override
  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {}
}

Widget _harness() => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
      ],
      child: zhMaterialApp(home: const StoreManagementScreen()),
    );

void main() {
  testWidgets('StoreManagementScreen renders fetched store + edit icon',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('门店管理'), findsOneWidget);
    expect(find.text('云间小厨·静安店'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsWidgets);
  });

  testWidgets('logo avatar is wrapped in a GestureDetector (tappable)',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Assert a CircleAvatar is present.
    expect(find.byType(CircleAvatar), findsWidgets);

    // Assert it has a GestureDetector ancestor.
    final wrapped = find.ancestor(
      of: find.byType(CircleAvatar).first,
      matching: find.byType(GestureDetector),
    );
    expect(wrapped, findsWidgets);
  });
}
