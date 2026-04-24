import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/membership.dart';
import '../../shared/models/store_invite.dart';
import '../../shared/models/store_member.dart';

class MembershipRepository {
  MembershipRepository(this._client);

  final SupabaseClient _client;

  Future<List<Membership>> listMyMemberships() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No authenticated user when listing memberships');
    }
    final rows = await _client
        .from('store_members')
        .select('id, role, accepted_at, store:stores(id, name, address, logo_url)')
        .eq('user_id', userId)
        .not('accepted_at', 'is', null);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(membershipFromSupabase)
        .toList(growable: false);
  }

  Future<List<StoreMember>> listStoreMembers(String storeId) async {
    final rows = await _client
        .from('store_members')
        .select('id, user_id, role, accepted_at')
        .eq('store_id', storeId)
        .not('accepted_at', 'is', null)
        .order('accepted_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(storeMemberFromSupabase)
        .toList(growable: false);
  }

  Future<List<StoreInvite>> listStoreInvites(String storeId) async {
    final rows = await _client
        .from('store_invites')
        .select('id, store_id, email, phone, role, token, expires_at, accepted_at')
        .eq('store_id', storeId)
        .isFilter('accepted_at', null)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(storeInviteFromSupabase)
        .toList(growable: false);
  }

  Future<StoreInvite> createInvite({
    required String storeId,
    required String email,
    required String role,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('store_invites')
        .insert({
          'store_id': storeId,
          'email': email,
          'role': role,
          'invited_by': userId,
        })
        .select('id, store_id, email, phone, role, token, expires_at, accepted_at')
        .single();
    return storeInviteFromSupabase(row);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.from('store_invites').delete().eq('id', inviteId);
  }

  Future<void> updateMemberRole({
    required String memberId,
    required String role,
  }) async {
    await _client.from('store_members').update({'role': role}).eq('id', memberId);
  }

  Future<void> removeMember(String memberId) async {
    await _client.from('store_members').delete().eq('id', memberId);
  }
}
