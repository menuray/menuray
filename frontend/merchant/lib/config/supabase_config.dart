import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

const _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

const _localAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

String get supabaseUrl {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (!kIsWeb && Platform.isAndroid && kDebugMode) {
    return 'http://10.0.2.2:54321';
  }
  return 'http://localhost:54321';
}

String get supabaseAnonKey =>
    _envAnonKey.isNotEmpty ? _envAnonKey : _localAnonKey;
