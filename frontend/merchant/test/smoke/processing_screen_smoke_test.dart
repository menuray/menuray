import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/capture/capture_providers.dart';
import 'package:menuray_merchant/features/capture/capture_repository.dart';
import 'package:menuray_merchant/features/capture/presentation/processing_screen.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_harness.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Session? get currentSession => null;
  @override
  Future<void> sendOtp(String phone) async {}
  @override
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      throw UnimplementedError();
  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeStoreRepository implements StoreRepository {
  @override
  Future<Store> fetchById(String storeId) async => const Store(
        id: 's1',
        name: '云间小厨',
        isCurrent: true,
      );
  @override
  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {}
}

class _FakeCaptureRepository implements CaptureRepository {
  @override
  Future<String> uploadPhoto({
    required XFile file,
    required String storeId,
    required String runId,
    required int index,
  }) async =>
      '$storeId/$runId/$index.jpg';

  @override
  Future<void> createParseRun({
    required String id,
    required String storeId,
    required List<String> paths,
  }) async {}

  @override
  Future<ParseRunStatus> invokeParseMenu({required String runId}) async =>
      ParseRunStatus.pending;

  @override
  Stream<ParseRunSnapshot> streamParseRun({required String runId}) async* {
    yield ParseRunSnapshot(id: runId, status: ParseRunStatus.pending);
    // Test ends before other states emit — that's fine; we only assert one render.
  }
}

void main() {
  testWidgets('ProcessingScreen renders the import-menu shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
          captureRepositoryProvider.overrideWithValue(_FakeCaptureRepository()),
        ],
        child: zhMaterialApp(home: const ProcessingScreen()),
      ),
    );
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 100)); // let _start() settle

    expect(find.text('导入菜单'), findsOneWidget);
  });
}
