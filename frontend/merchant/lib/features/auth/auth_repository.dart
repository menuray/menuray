import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  GoTrueClient get _auth => _client.auth;

  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<void> sendOtp(String phone) =>
      _auth.signInWithOtp(phone: phone);

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      _auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<AuthResponse> signInSeed() => _auth.signInWithPassword(
        email: 'seed@menuray.com',
        password: 'demo1234',
      );

  Future<void> signOut() => _auth.signOut();
}
