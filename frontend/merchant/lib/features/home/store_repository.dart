import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/store.dart';

class StoreRepository {
  StoreRepository(this._client);

  final SupabaseClient _client;

  Future<Store> currentStore() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No authenticated user when querying store');
    }
    final row = await _client
        .from('stores')
        .select()
        .eq('owner_id', userId)
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
