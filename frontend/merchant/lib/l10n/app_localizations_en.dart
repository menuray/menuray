// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNext => 'Next';

  @override
  String get commonOperationFailed => 'Operation failed';

  @override
  String get authSlogan =>
      'Snap a photo of any paper menu, get a shareable digital menu in minutes.';

  @override
  String get authPhoneHint => 'Enter phone number';

  @override
  String get authOtpHint => 'Enter verification code';

  @override
  String get authSendOtp => 'Send code';

  @override
  String get authSendingOtp => 'Sending…';

  @override
  String authResendOtp(int seconds) {
    return '${seconds}s resend';
  }

  @override
  String get authOtpSent => 'Verification code sent';

  @override
  String get authEnterPhone => 'Please enter phone number';

  @override
  String get authEnterPhoneAndOtp =>
      'Please enter phone number and verification code';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSigningIn => 'Signing in…';

  @override
  String get authRegisterHint => 'New here? Sign up';

  @override
  String get authSeedLoginDev => 'Dev: seed account login';

  @override
  String get authFooterPoweredBy => 'Powered by MenuRay';

  @override
  String get authFooterTerms => 'Terms of Service';

  @override
  String get authFooterPrivacy => 'Privacy Policy';
}
