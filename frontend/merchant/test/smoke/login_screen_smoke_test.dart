import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/auth/presentation/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

void main() {
  testWidgets('LoginScreen renders wordmark, form, and send-OTP button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MenuRay'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('拍一张照，5 分钟生成电子菜单'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });
}
