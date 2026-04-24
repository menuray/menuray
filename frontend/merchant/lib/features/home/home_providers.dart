import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/menu.dart';
import '../../shared/models/store.dart';
import '../auth/auth_providers.dart';
import '../store/active_store_provider.dart';
import 'menu_repository.dart';
import 'store_repository.dart';

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(supabaseClientProvider)),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(supabaseClientProvider)),
);

/// The currently-active store, resolved via activeStoreProvider. Throws if
/// no active store is set — call sites should be under a router guard that
/// redirects to /store-picker or /login first.
final currentStoreProvider = FutureProvider<Store>((ref) async {
  final ctx = ref.watch(activeStoreProvider);
  if (ctx == null) {
    throw StateError('No active store selected');
  }
  return ref.watch(storeRepositoryProvider).fetchById(ctx.storeId);
});

final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final store = await ref.watch(currentStoreProvider.future);
  return ref.watch(menuRepositoryProvider).listMenusForStore(store.id);
});

/// DEPRECATED: temporary shim retained until store_management_screen migrates
/// to membershipsProvider directly (Task 15). Returns the single active store
/// as a 1-element list so the existing screen compiles.
final ownerStoresProvider = FutureProvider<List<Store>>((ref) async {
  final s = await ref.watch(currentStoreProvider.future);
  return [s];
});
