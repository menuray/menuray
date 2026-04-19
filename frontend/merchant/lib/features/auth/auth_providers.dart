import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/supabase/supabase_client.dart';
import 'auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => supabase);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentSessionProvider = Provider<Session?>((ref) {
  final async = ref.watch(authStateProvider);
  final sessionFromStream = async.valueOrNull?.session;
  if (sessionFromStream != null) return sessionFromStream;
  return ref.watch(authRepositoryProvider).currentSession;
});
