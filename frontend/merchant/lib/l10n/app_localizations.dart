import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Generic Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get commonOperationFailed;

  /// No description provided for @authSlogan.
  ///
  /// In en, this message translates to:
  /// **'Snap a photo of any paper menu, get a shareable digital menu in minutes.'**
  String get authSlogan;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get authPhoneHint;

  /// No description provided for @authOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get authOtpHint;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendOtp;

  /// No description provided for @authSendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get authSendingOtp;

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s resend'**
  String authResendOtp(int seconds);

  /// No description provided for @authOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get authOtpSent;

  /// No description provided for @authEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get authEnterPhone;

  /// No description provided for @authEnterPhoneAndOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number and verification code'**
  String get authEnterPhoneAndOtp;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authSigningIn;

  /// No description provided for @authRegisterHint.
  ///
  /// In en, this message translates to:
  /// **'New here? Sign up'**
  String get authRegisterHint;

  /// No description provided for @authSeedLoginDev.
  ///
  /// In en, this message translates to:
  /// **'Dev: seed account login'**
  String get authSeedLoginDev;

  /// No description provided for @authFooterPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by MenuRay'**
  String get authFooterPoweredBy;

  /// No description provided for @authFooterTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authFooterTerms;

  /// No description provided for @authFooterPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authFooterPrivacy;

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get homeLoading;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search menus, items, or status...'**
  String get homeSearchHint;

  /// No description provided for @homeMenusTitle.
  ///
  /// In en, this message translates to:
  /// **'Curated Menus'**
  String get homeMenusTitle;

  /// No description provided for @homeMenusTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} Total'**
  String homeMenusTotal(int count);

  /// No description provided for @homeMenusTotalPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'— Total'**
  String get homeMenusTotalPlaceholder;

  /// No description provided for @homeMenusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String homeMenusLoadFailed(String error);

  /// No description provided for @homeMenusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No menus yet. Tap the \"New menu\" button to start.'**
  String get homeMenusEmpty;

  /// No description provided for @homeFabNewMenu.
  ///
  /// In en, this message translates to:
  /// **'New menu'**
  String get homeFabNewMenu;

  /// No description provided for @homeTabMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get homeTabMenus;

  /// No description provided for @homeTabData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get homeTabData;

  /// No description provided for @homeTabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get homeTabMine;

  /// No description provided for @homeSearchInputDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Search menus, dishes, or status…'**
  String get homeSearchInputDefaultHint;

  /// No description provided for @statusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get statusPublished;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get statusSoldOut;

  /// No description provided for @menuCardViews.
  ///
  /// In en, this message translates to:
  /// **'{count} visits'**
  String menuCardViews(int count);

  /// No description provided for @menuCardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get menuCardToday;

  /// No description provided for @menuCardYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get menuCardYesterday;

  /// No description provided for @menuCardDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String menuCardDaysAgo(int days);

  /// No description provided for @menuCardWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks} weeks ago'**
  String menuCardWeeksAgo(int weeks);

  /// No description provided for @menuCardMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{months} months ago'**
  String menuCardMonthsAgo(int months);

  /// No description provided for @menuManageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String menuManageLoadFailed(String error);

  /// No description provided for @menuManageSoldOutUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String menuManageSoldOutUpdateFailed(String error);

  /// No description provided for @menuManageUpdatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated 3 days ago'**
  String get menuManageUpdatedAgo;

  /// No description provided for @menuManageViewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get menuManageViewsLabel;

  /// No description provided for @menuManageSoldOutSection.
  ///
  /// In en, this message translates to:
  /// **'Sold-out items'**
  String get menuManageSoldOutSection;

  /// No description provided for @menuManageTimeSlotSection.
  ///
  /// In en, this message translates to:
  /// **'Service hours'**
  String get menuManageTimeSlotSection;

  /// No description provided for @menuManageActionEditContent.
  ///
  /// In en, this message translates to:
  /// **'Edit content'**
  String get menuManageActionEditContent;

  /// No description provided for @menuManageActionSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get menuManageActionSoldOut;

  /// No description provided for @menuManageActionPriceAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust price'**
  String get menuManageActionPriceAdjust;

  /// No description provided for @menuManageActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuManageActionShare;

  /// No description provided for @menuManageActionStatistics.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get menuManageActionStatistics;

  /// No description provided for @menuManageTimeSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get menuManageTimeSlotLunch;

  /// No description provided for @menuManageTimeSlotLunchHours.
  ///
  /// In en, this message translates to:
  /// **'11:00–14:00'**
  String get menuManageTimeSlotLunchHours;

  /// No description provided for @menuManageTimeSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get menuManageTimeSlotDinner;

  /// No description provided for @menuManageTimeSlotDinnerHours.
  ///
  /// In en, this message translates to:
  /// **'17:00–22:00'**
  String get menuManageTimeSlotDinnerHours;

  /// No description provided for @menuManageTimeSlotAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get menuManageTimeSlotAllDay;

  /// No description provided for @menuManageTimeSlotAllDayHours.
  ///
  /// In en, this message translates to:
  /// **'Open during business hours'**
  String get menuManageTimeSlotAllDayHours;

  /// No description provided for @menuManageTimeSlotSeasonal.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get menuManageTimeSlotSeasonal;

  /// No description provided for @menuManageTimeSlotSeasonalHours.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get menuManageTimeSlotSeasonalHours;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
