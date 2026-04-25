import 'package:supabase_flutter/supabase_flutter.dart';

class StoreCreationResult {
  const StoreCreationResult({required this.storeId});
  final String storeId;
}

/// Thrown when the create-store Edge Function returns 403 because the caller
/// is not on the Growth tier. The UI redirects to /upgrade.
class MultiStoreRequiresGrowthError implements Exception {
  const MultiStoreRequiresGrowthError();
  @override
  String toString() => 'MultiStoreRequiresGrowthError';
}

class StoreCreationRepository {
  StoreCreationRepository(this._client);
  final SupabaseClient _client;

  Future<StoreCreationResult> createStore({
    required String name,
    String currency = 'USD',
    String sourceLocale = 'en',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'create-store',
        body: {
          'name': name,
          'currency': currency,
          'source_locale': sourceLocale,
        },
      );
      final data = res.data;
      if (data is Map && data['storeId'] is String) {
        return StoreCreationResult(storeId: data['storeId'] as String);
      }
      throw StateError('create-store returned unexpected shape: $data');
    } on FunctionException catch (e) {
      if (e.status == 403) {
        final detail = e.details;
        if (detail is Map && detail['error'] == 'multi_store_requires_growth') {
          throw const MultiStoreRequiresGrowthError();
        }
      }
      rethrow;
    }
  }
}
