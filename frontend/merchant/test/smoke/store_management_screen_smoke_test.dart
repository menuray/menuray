import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/features/store/membership_providers.dart';
import 'package:menuray_merchant/features/store/membership_repository.dart';
import 'package:menuray_merchant/features/store/presentation/store_management_screen.dart';
import 'package:menuray_merchant/shared/models/membership.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:menuray_merchant/shared/models/store_invite.dart';
import 'package:menuray_merchant/shared/models/store_member.dart';
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

class _FakeMembershipRepository implements MembershipRepository {
  @override
  Future<List<Membership>> listMyMemberships() async => [
        Membership(
          id: 'mem-1',
          role: 'owner',
          store: const Store(id: 's1', name: '云间小厨·静安店', address: '上海·静安'),
        ),
      ];

  @override
  Future<List<StoreMember>> listStoreMembers(String storeId) async => const [];

  @override
  Future<List<StoreInvite>> listStoreInvites(String storeId) async => const [];

  @override
  Future<StoreInvite> createInvite({
    required String storeId,
    required String email,
    required String role,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> revokeInvite(String inviteId) async {}

  @override
  Future<void> updateMemberRole({
    required String memberId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(String memberId) async {}
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
        membershipRepositoryProvider
            .overrideWithValue(_FakeMembershipRepository()),
        storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
        testActiveStoreOverride(storeId: 's1'),
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

  testWidgets('team button is rendered per store card', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('team-link-s1')), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsWidgets);
  });
}
