import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/store/membership_providers.dart';
import 'package:menuray_merchant/features/store/membership_repository.dart';
import 'package:menuray_merchant/features/store/presentation/team_management_screen.dart';
import 'package:menuray_merchant/shared/models/membership.dart';
import 'package:menuray_merchant/shared/models/store_invite.dart';
import 'package:menuray_merchant/shared/models/store_member.dart';

import '../support/test_harness.dart';

class _FakeRepo implements MembershipRepository {
  _FakeRepo(this.members, this.invites);
  List<StoreMember> members;
  List<StoreInvite> invites;

  @override
  Future<List<Membership>> listMyMemberships() async => const [];

  @override
  Future<List<StoreMember>> listStoreMembers(String storeId) async => members;

  @override
  Future<List<StoreInvite>> listStoreInvites(String storeId) async => invites;

  @override
  Future<StoreInvite> createInvite({
    required String storeId,
    required String email,
    required String role,
  }) async {
    final inv = StoreInvite(
      id: 'i-new',
      storeId: storeId,
      email: email,
      role: role,
      token: 'newtok',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
    invites = [...invites, inv];
    return inv;
  }

  @override
  Future<void> revokeInvite(String inviteId) async {}

  @override
  Future<void> updateMemberRole(
      {required String memberId, required String role}) async {}

  @override
  Future<void> removeMember(String memberId) async {}
}

void main() {
  testWidgets('owner sees FAB, members tab, invites tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipRepositoryProvider.overrideWithValue(_FakeRepo(
            [
              StoreMember(
                  id: 'm1',
                  userId: 'u1',
                  role: 'manager',
                  email: 'm@x',
                  acceptedAt: DateTime.now())
            ],
            [
              StoreInvite(
                  id: 'i1',
                  storeId: 'store-1',
                  email: 'p@x',
                  role: 'staff',
                  token: 't',
                  expiresAt:
                      DateTime.now().add(const Duration(days: 5)))
            ],
          )),
          testActiveStoreOverride(storeId: 'store-1', role: 'owner'),
        ],
        child: zhMaterialApp(
            home: const TeamManagementScreen(storeId: 'store-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('team-invite-fab')), findsOneWidget);
    expect(find.text('成员'), findsOneWidget);
    expect(find.text('待接受邀请'), findsOneWidget);
    expect(find.text('m@x'), findsOneWidget);
  });

  testWidgets('staff hides FAB', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipRepositoryProvider
              .overrideWithValue(_FakeRepo(const [], const [])),
          testActiveStoreOverride(storeId: 'store-1', role: 'staff'),
        ],
        child: zhMaterialApp(
            home: const TeamManagementScreen(storeId: 'store-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('team-invite-fab')), findsNothing);
  });
}
