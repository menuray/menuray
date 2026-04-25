import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/store_creation_repository.dart';

final storeCreationRepositoryProvider = Provider<StoreCreationRepository>(
  (ref) => StoreCreationRepository(ref.watch(supabaseClientProvider)),
);
