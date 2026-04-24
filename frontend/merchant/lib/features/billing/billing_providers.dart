import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../home/home_providers.dart';
import 'billing_repository.dart';
import 'tier.dart';

final currentTierProvider = FutureProvider<Tier>((ref) async {
  // Reads the active store's denormalised tier column. Throws if no active
  // store (caller should be inside a router-guarded route).
  final store = await ref.watch(currentStoreProvider.future);
  return TierX.fromString(store.tier);
});

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(supabaseClientProvider)),
);
