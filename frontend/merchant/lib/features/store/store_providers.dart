import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/store.dart';
import '../home/home_providers.dart';

/// One store per owner (schema: stores.owner_id UNIQUE). This wraps the
/// single currentStore into a List so store_management can keep its
/// list-of-cards UI without pretending to fetch multiple.
final ownerStoresProvider = FutureProvider<List<Store>>((ref) async {
  final s = await ref.watch(currentStoreProvider.future);
  return [s];
});
