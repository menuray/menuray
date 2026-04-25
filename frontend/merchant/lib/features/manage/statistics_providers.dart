import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../store/active_store_provider.dart';
import 'statistics_repository.dart';

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => StatisticsRepository(ref.watch(supabaseClientProvider)),
);

final statisticsProvider = FutureProvider.autoDispose
    .family<StatisticsData, StatisticsRange>((ref, range) async {
  final ctx = ref.watch(activeStoreProvider);
  if (ctx == null) throw StateError('No active store');
  return ref
      .watch(statisticsRepositoryProvider)
      .fetch(storeId: ctx.storeId, range: range);
});
