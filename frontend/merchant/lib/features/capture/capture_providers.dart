import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'capture_repository.dart';

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(supabaseClientProvider)),
);

final parseRunStreamProvider =
    StreamProvider.family<ParseRunSnapshot, String>((ref, runId) {
  ref.watch(authStateProvider);
  return ref.watch(captureRepositoryProvider).streamParseRun(runId: runId);
});
