import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/menu.dart';
import '../../shared/models/store.dart';
import '../auth/auth_providers.dart';
import 'menu_repository.dart';
import 'store_repository.dart';

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(supabaseClientProvider)),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(supabaseClientProvider)),
);

final currentStoreProvider = FutureProvider<Store>((ref) async {
  ref.watch(authStateProvider); // re-evaluate on auth change
  return ref.watch(storeRepositoryProvider).currentStore();
});

final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final store = await ref.watch(currentStoreProvider.future);
  return ref.watch(menuRepositoryProvider).listMenusForStore(store.id);
});
