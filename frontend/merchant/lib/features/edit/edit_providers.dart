import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/dish.dart';
import '../auth/auth_providers.dart';
import 'dish_repository.dart';

final dishRepositoryProvider = Provider<DishRepository>(
  (ref) => DishRepository(ref.watch(supabaseClientProvider)),
);

final dishByIdProvider =
    FutureProvider.family<Dish, String>((ref, dishId) async {
  ref.watch(authStateProvider);
  return ref.watch(dishRepositoryProvider).fetchDish(dishId);
});
