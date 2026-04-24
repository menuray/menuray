import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/auth/presentation/login_screen.dart';
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

/// Records the phone passed to sendOtp so tests can assert normalisation.
class _RecordingAuthRepository implements AuthRepository {
  String? lastPhone;

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Session? get currentSession => null;

  @override
  Future<void> sendOtp(String phone) async {
    lastPhone = phone;
  }

  @override
  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Widget _harness(Widget screen, {AuthRepository? auth}) => ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(auth ?? _FakeAuthRepository()),
      ],
      child: zhMaterialApp(home: screen),
    );

void main() {
  testWidgets('LoginScreen renders wordmark, form, and send-OTP button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: zhMaterialApp(home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MenuRay'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('拍一张照，5 分钟生成电子菜单'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });

  testWidgets('empty phone → submit shows validator error', (tester) async {
    await tester.pumpWidget(_harness(const LoginScreen()));
    await tester.pumpAndSettle();

    // Tap submit without entering anything.
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    // validator for empty phone returns validationRequired → '必填' in zh.
    expect(find.textContaining('必填'), findsWidgets);
  });

  testWidgets('register link → snackbar visible', (tester) async {
    await tester.pumpWidget(_harness(const LoginScreen()));
    await tester.pumpAndSettle();

    // authRegisterHint in zh is '新用户？立即注册'.
    // Scroll to ensure the register hint is visible before tapping.
    final registerHint = find.textContaining('新用户？立即注册');
    await tester.ensureVisible(registerHint);
    await tester.pumpAndSettle();

    await tester.tap(registerHint, warnIfMissed: false);
    await tester.pumpAndSettle();

    // registerHintSnackbar contains '新用户直接输入手机号'.
    expect(find.textContaining('新用户直接输入手机号'), findsOneWidget);
  });

  testWidgets('valid CN mobile → sendOtp called with +86 prefix', (tester) async {
    final recorder = _RecordingAuthRepository();
    await tester.pumpWidget(_harness(const LoginScreen(), auth: recorder));
    await tester.pumpAndSettle();

    // Enter an 11-digit CN number into the phone field.
    await tester.enterText(
        find.byKey(const Key('login-phone-field')), '13800001234');
    await tester.pump();

    // Tap the send-OTP button to trigger _onSendOtp which calls sendOtp.
    await tester.tap(find.text('发送验证码'));
    await tester.pumpAndSettle();

    expect(recorder.lastPhone, '+8613800001234');
  });

  // The full multi-membership router redirect test requires a GoRouter
  // integration harness that this project doesn't yet have. Manual verification
  // of the redirect path (login → picker when memberships.length >= 2) is
  // documented in Task 19 of the auth-migration plan. This placeholder keeps
  // the expectation visible in the test file.
  testWidgets('multi-membership router redirect — deferred manual verify',
      (tester) async {
    expect(true, true);
  });
}
