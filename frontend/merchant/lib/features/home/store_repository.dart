import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/store.dart';

class StoreRepository {
  StoreRepository(this._client);

  final SupabaseClient _client;

  /// Fetches a store by its id. Access is gated by the new stores_member_select
  /// RLS policy (membership-based). Throws if not accessible.
  Future<Store> fetchById(String storeId) async {
    final row = await _client
        .from('stores')
        .select()
        .eq('id', storeId)
        .single();
    return storeFromSupabase(row);
  }

  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (address != null) payload['address'] = address;
    if (logoUrl != null) payload['logo_url'] = logoUrl;
    await _client.from('stores').update(payload).eq('id', storeId);
  }
}
