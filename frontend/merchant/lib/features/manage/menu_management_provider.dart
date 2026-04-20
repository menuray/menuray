import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/menu.dart';
import '../auth/auth_providers.dart';
import '../home/home_providers.dart';

final menuByIdProvider =
    FutureProvider.family<Menu, String>((ref, menuId) async {
  ref.watch(authStateProvider); // re-evaluate on auth change
  return ref.watch(menuRepositoryProvider).fetchMenu(menuId);
});
