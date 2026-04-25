import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/menu_repository.dart';
import 'package:menuray_merchant/features/publish/presentation/published_screen.dart';
import 'package:menuray_merchant/shared/models/menu.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      throw UnimplementedError();
  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<List<Menu>> listMenusForStore(String storeId) async => [];

  @override
  Future<Menu> fetchMenu(String menuId) async => Menu(
        id: menuId,
        name: '午市套餐 2025 春',
        status: MenuStatus.published,
        updatedAt: DateTime(2026, 4, 16),
        slug: 'yunjian-lunch',
      );

  @override
  Future<void> setDishSoldOut({
    required String dishId,
    required bool soldOut,
  }) async {}

  @override
  Future<void> reorderDishes(List<({String dishId, int position})> pairs) async {}

  @override
  Future<void> updateMenu({
    required String menuId,
    String? templateId,
    Map<String, dynamic>? themeOverrides,
  }) async {}
}

const _testStore = Store(
  id: 'store-1',
  name: '云尖小厨',
);

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
          currentStoreProvider.overrideWith((ref) async => _testStore),
        ],
        child: zhMaterialApp(home: const PublishedScreen(menuId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders real QR + URL fragment + share/copy buttons', (tester) async {
    await pumpScreen(tester);

    // Real qr_flutter widget — replaces the prior fake-painter grid.
    expect(find.byType(QrImageView), findsWidgets);

    // URL caption uses the full host from AppConfig.
    expect(find.textContaining('yunjian-lunch'), findsWidgets);
    expect(find.textContaining('menu.menuray.com'), findsWidgets);

    // Three pre-existing labelled buttons stay present (publishedExportQr,
    // publishedExportSocial, plus the WeChat / Copy / More social row).
    expect(find.text('保存二维码'), findsOneWidget);
    expect(find.text('导出朋友圈图'), findsOneWidget);
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
  });

  testWidgets('tap copy-link populates clipboard + shows snackbar', (tester) async {
    final clipboardCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = (call.arguments as Map).cast<String, Object?>();
        clipboardCalls.add(args['text'] as String);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpScreen(tester);

    // The link row label exposes the localized "复制访问链接" string. Scroll
    // it into the viewport before tapping (default 800x600 surface places
    // the link row below the fold).
    final linkLabel = find.text('复制访问链接');
    await tester.ensureVisible(linkLabel);
    await tester.pumpAndSettle();
    await tester.tap(linkLabel);
    await tester.pump();

    expect(clipboardCalls, contains('https://menu.menuray.com/yunjian-lunch'));
    expect(find.text('已复制访问链接'), findsOneWidget);
  });
}
