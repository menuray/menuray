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

  @override
  String get homeLoading => 'Loading…';

  @override
  String get homeSearchHint => 'Search menus, items, or status...';

  @override
  String get homeMenusTitle => 'Curated Menus';

  @override
  String homeMenusTotal(int count) {
    return '$count Total';
  }

  @override
  String get homeMenusTotalPlaceholder => '— Total';

  @override
  String homeMenusLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get homeMenusEmpty =>
      'No menus yet. Tap the \"New menu\" button to start.';

  @override
  String get homeFabNewMenu => 'New menu';

  @override
  String get homeTabMenus => 'Menus';

  @override
  String get homeTabData => 'Data';

  @override
  String get homeTabMine => 'Mine';

  @override
  String get homeSearchInputDefaultHint => 'Search menus, dishes, or status…';

  @override
  String get statusPublished => 'Published';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusSoldOut => 'Sold out';

  @override
  String menuCardViews(int count) {
    return '$count visits';
  }

  @override
  String get menuCardToday => 'Today';

  @override
  String get menuCardYesterday => 'Yesterday';

  @override
  String menuCardDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String menuCardWeeksAgo(int weeks) {
    return '$weeks weeks ago';
  }

  @override
  String menuCardMonthsAgo(int months) {
    return '$months months ago';
  }

  @override
  String menuManageLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String menuManageSoldOutUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get menuManageUpdatedAgo => 'Updated 3 days ago';

  @override
  String get menuManageViewsLabel => 'Views';

  @override
  String get menuManageSoldOutSection => 'Sold-out items';

  @override
  String get menuManageTimeSlotSection => 'Service hours';

  @override
  String get menuManageActionEditContent => 'Edit content';

  @override
  String get menuManageActionSoldOut => 'Sold out';

  @override
  String get menuManageActionPriceAdjust => 'Adjust price';

  @override
  String get menuManageActionShare => 'Share';

  @override
  String get menuManageActionStatistics => 'Data';

  @override
  String get menuManageTimeSlotLunch => 'Lunch';

  @override
  String get menuManageTimeSlotLunchHours => '11:00–14:00';

  @override
  String get menuManageTimeSlotDinner => 'Dinner';

  @override
  String get menuManageTimeSlotDinnerHours => '17:00–22:00';

  @override
  String get menuManageTimeSlotAllDay => 'All day';

  @override
  String get menuManageTimeSlotAllDayHours => 'Open during business hours';

  @override
  String get menuManageTimeSlotSeasonal => 'Seasonal';

  @override
  String get menuManageTimeSlotSeasonalHours => 'Custom dates';
}
