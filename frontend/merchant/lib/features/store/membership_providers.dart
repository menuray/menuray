import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/membership.dart';
import '../../shared/models/store_invite.dart';
import '../../shared/models/store_member.dart';
import '../auth/auth_providers.dart';
import 'membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(ref.watch(supabaseClientProvider)),
);

/// All memberships for the current user. Consumed by the router redirect
/// (to decide whether to show the Store Picker) and by the picker screen.
final membershipsProvider = FutureProvider<List<Membership>>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(membershipRepositoryProvider).listMyMemberships();
});

final storeMembersProvider =
    FutureProvider.family<List<StoreMember>, String>((ref, storeId) async {
  return ref.watch(membershipRepositoryProvider).listStoreMembers(storeId);
});

final storeInvitesProvider =
    FutureProvider.family<List<StoreInvite>, String>((ref, storeId) async {
  return ref.watch(membershipRepositoryProvider).listStoreInvites(storeId);
});
