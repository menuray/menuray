import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/features/store/presentation/settings_screen.dart';
import 'package:menuray_merchant/l10n/app_localizations.dart';
import 'package:menuray_merchant/router/app_router.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_harness.dart';

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;

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
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeStoreRepository implements StoreRepository {
  @override
  Future<Store> fetchById(String storeId) async =>
      const Store(id: 's1', name: '云间小厨·静安店', isCurrent: true);

  @override
  Future<void> updateStore({
    required String storeId,
    required String name,
    String? address,
    String? logoUrl,
  }) async {}
}

void main() {
  testWidgets('SettingsScreen renders fetched store name and menu tile',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
        ],
        child: zhMaterialApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('店铺信息'), findsOneWidget);
    expect(find.text('云间小厨·静安店'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
  });

  testWidgets('logout taps signOut then navigates to login', (tester) async {
    final auth = _FakeAuthRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (ctx, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (ctx, state) => const Scaffold(body: Text('LOGIN_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (ctx, state) => const Scaffold(body: Text('HOME_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.statistics,
          builder: (ctx, state) => const Scaffold(body: Text('STATS_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.storeManage,
          builder: (ctx, state) => const Scaffold(body: Text('STORE_MARKER')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('退出登录'), 100);
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('LOGIN_MARKER'), findsOneWidget);
  });
}
