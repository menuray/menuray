import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/store/membership_providers.dart';
import 'package:menuray_merchant/features/store/membership_repository.dart';
import 'package:menuray_merchant/features/store/presentation/store_picker_screen.dart';
import 'package:menuray_merchant/shared/models/membership.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:menuray_merchant/shared/models/store_invite.dart';
import 'package:menuray_merchant/shared/models/store_member.dart';

import '../support/test_harness.dart';

class _FakeMembershipRepository implements MembershipRepository {
  _FakeMembershipRepository(this._rows);
  final List<Membership> _rows;
  @override Future<List<Membership>> listMyMemberships() async => _rows;
  @override Future<List<StoreMember>> listStoreMembers(String storeId) async => const [];
  @override Future<List<StoreInvite>> listStoreInvites(String storeId) async => const [];
  @override Future<StoreInvite> createInvite({required String storeId, required String email, required String role}) =>
      throw UnimplementedError();
  @override Future<void> revokeInvite(String inviteId) async {}
  @override Future<void> updateMemberRole({required String memberId, required String role}) async {}
  @override Future<void> removeMember(String memberId) async {}
}

Membership _mem(String id, String role, String storeId, String storeName) =>
    Membership(id: id, role: role,
        store: Store(id: storeId, name: storeName));

void main() {
  testWidgets('renders subtitle + card per membership', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipRepositoryProvider.overrideWithValue(
            _FakeMembershipRepository([
              _mem('m1', 'owner',   's1', '云间小厨'),
              _mem('m2', 'manager', 's2', 'Grand Cafe'),
            ]),
          ),
        ],
        child: zhMaterialApp(home: const StorePickerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('你可访问'), findsOneWidget);
    expect(find.text('云间小厨'), findsOneWidget);
    expect(find.text('Grand Cafe'), findsOneWidget);
    expect(find.text('所有者'), findsOneWidget);
    expect(find.text('管理员'), findsOneWidget);
  });

  testWidgets('empty memberships → banner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipRepositoryProvider.overrideWithValue(_FakeMembershipRepository(const [])),
        ],
        child: zhMaterialApp(home: const StorePickerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无活跃门店'), findsOneWidget);
  });
}
