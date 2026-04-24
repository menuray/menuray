import 'package:supabase_flutter/supabase_flutter.dart';

import 'tier.dart';

class BillingRepository {
  BillingRepository(this._client);
  final SupabaseClient _client;

  Future<String> createCheckoutSession({
    required Tier tier,
    required String currency, // 'USD' | 'CNY'
    required String period,   // 'monthly' | 'annual'
  }) async {
    final res = await _client.functions.invoke(
      'create-checkout-session',
      body: {'tier': tier.apiName, 'currency': currency, 'period': period},
    );
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw StateError('Checkout session response missing url');
  }

  Future<String> createPortalSession() async {
    final res = await _client.functions.invoke('create-portal-session');
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw StateError('Portal session response missing url');
  }
}
