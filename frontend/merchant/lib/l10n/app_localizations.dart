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

  /// No description provided for @editDishTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit dish'**
  String get editDishTitle;

  /// No description provided for @editDishSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get editDishSaving;

  /// No description provided for @editDishSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String editDishSaveFailed(String error);

  /// No description provided for @editDishLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String editDishLoadFailed(String error);

  /// No description provided for @editDishPhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get editDishPhotoCamera;

  /// No description provided for @editDishPhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get editDishPhotoGallery;

  /// No description provided for @editDishPhotoAiGenerate.
  ///
  /// In en, this message translates to:
  /// **'AI generate'**
  String get editDishPhotoAiGenerate;

  /// No description provided for @editDishFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editDishFieldName;

  /// No description provided for @editDishFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'Dish name'**
  String get editDishFieldNameHint;

  /// No description provided for @editDishFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get editDishFieldPrice;

  /// No description provided for @editDishFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get editDishFieldDescription;

  /// No description provided for @editDishFieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the dish…'**
  String get editDishFieldDescriptionHint;

  /// No description provided for @editDishAiExpand.
  ///
  /// In en, this message translates to:
  /// **'AI expand'**
  String get editDishAiExpand;

  /// No description provided for @editDishLocalizationSection.
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get editDishLocalizationSection;

  /// No description provided for @editDishTranslateAll.
  ///
  /// In en, this message translates to:
  /// **'Translate all'**
  String get editDishTranslateAll;

  /// No description provided for @editDishLangChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get editDishLangChinese;

  /// No description provided for @editDishLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get editDishLangEnglish;

  /// No description provided for @editDishEnNameHint.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get editDishEnNameHint;

  /// No description provided for @editDishSpiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Spice'**
  String get editDishSpiceLabel;

  /// No description provided for @editDishSpiceNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get editDishSpiceNone;

  /// No description provided for @editDishSpiceMild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get editDishSpiceMild;

  /// No description provided for @editDishSpiceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get editDishSpiceMedium;

  /// No description provided for @editDishSpiceHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get editDishSpiceHot;

  /// No description provided for @editDishTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get editDishTagsLabel;

  /// No description provided for @editDishTagSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get editDishTagSignature;

  /// No description provided for @editDishTagRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get editDishTagRecommended;

  /// No description provided for @editDishTagVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get editDishTagVegetarian;

  /// No description provided for @editDishAllergensLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get editDishAllergensLabel;

  /// No description provided for @editDishAllergenPeanut.
  ///
  /// In en, this message translates to:
  /// **'Peanut'**
  String get editDishAllergenPeanut;

  /// No description provided for @editDishAllergenDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get editDishAllergenDairy;

  /// No description provided for @editDishAllergenSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get editDishAllergenSeafood;

  /// No description provided for @editDishAllergenGluten.
  ///
  /// In en, this message translates to:
  /// **'Gluten'**
  String get editDishAllergenGluten;

  /// No description provided for @editDishAllergenEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get editDishAllergenEgg;

  /// No description provided for @organizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize menu'**
  String get organizeTitle;

  /// No description provided for @organizeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String organizeLoadFailed(String error);

  /// No description provided for @organizeReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Reorder failed: {error}'**
  String organizeReorderFailed(String error);

  /// No description provided for @organizeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get organizeEmpty;

  /// No description provided for @organizeCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String organizeCategoryCount(int count);

  /// No description provided for @organizeFabAdd.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get organizeFabAdd;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewTitle;

  /// No description provided for @previewPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get previewPublish;

  /// No description provided for @previewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String previewLoadFailed(String error);

  /// No description provided for @previewDevicePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get previewDevicePhone;

  /// No description provided for @previewDeviceTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get previewDeviceTablet;

  /// No description provided for @previewLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get previewLanguageChinese;

  /// No description provided for @previewLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get previewLanguageEnglish;

  /// No description provided for @previewEmptyDishes.
  ///
  /// In en, this message translates to:
  /// **'No dishes yet'**
  String get previewEmptyDishes;

  /// No description provided for @previewStoreSubtitleCn.
  ///
  /// In en, this message translates to:
  /// **'Sichuan · 11:00 - 22:00'**
  String get previewStoreSubtitleCn;

  /// No description provided for @previewStoreSubtitleEn.
  ///
  /// In en, this message translates to:
  /// **'Sichuan · 11:00 - 22:00'**
  String get previewStoreSubtitleEn;

  /// No description provided for @previewSampleCategoriesCn.
  ///
  /// In en, this message translates to:
  /// **'凉菜,热菜,主食,汤品,饮品'**
  String get previewSampleCategoriesCn;

  /// No description provided for @previewSampleCategoriesEn.
  ///
  /// In en, this message translates to:
  /// **'Cold,Hot,Staple,Soup,Drink'**
  String get previewSampleCategoriesEn;

  /// No description provided for @previewDishChefSpecial.
  ///
  /// In en, this message translates to:
  /// **'Chef\'s Special'**
  String get previewDishChefSpecial;

  /// No description provided for @previewDishChefSpecialCn.
  ///
  /// In en, this message translates to:
  /// **'招牌'**
  String get previewDishChefSpecialCn;

  /// No description provided for @previewDishSpicy.
  ///
  /// In en, this message translates to:
  /// **'Spicy'**
  String get previewDishSpicy;

  /// No description provided for @previewDishSpicyCn.
  ///
  /// In en, this message translates to:
  /// **'辣'**
  String get previewDishSpicyCn;

  /// No description provided for @previewFooterPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by MenuRay'**
  String get previewFooterPoweredBy;

  /// No description provided for @previewReturnEdit.
  ///
  /// In en, this message translates to:
  /// **'Return to edit'**
  String get previewReturnEdit;

  /// No description provided for @previewPublishMenu.
  ///
  /// In en, this message translates to:
  /// **'Publish menu'**
  String get previewPublishMenu;

  /// No description provided for @publishedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String publishedLoadFailed(String error);

  /// No description provided for @publishedUnpublished.
  ///
  /// In en, this message translates to:
  /// **'Menu not published'**
  String get publishedUnpublished;

  /// No description provided for @publishedSuccessHeading.
  ///
  /// In en, this message translates to:
  /// **'Menu published!'**
  String get publishedSuccessHeading;

  /// No description provided for @publishedFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Guests scan the QR — no app install needed'**
  String get publishedFooterHint;

  /// No description provided for @publishedCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy shareable link'**
  String get publishedCopyLink;

  /// No description provided for @publishedExportQr.
  ///
  /// In en, this message translates to:
  /// **'Save QR code'**
  String get publishedExportQr;

  /// No description provided for @publishedExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get publishedExportPdf;

  /// No description provided for @publishedExportSocial.
  ///
  /// In en, this message translates to:
  /// **'Export social image'**
  String get publishedExportSocial;

  /// No description provided for @publishedSocialWeChat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get publishedSocialWeChat;

  /// No description provided for @publishedSocialCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get publishedSocialCopy;

  /// No description provided for @publishedSocialMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get publishedSocialMore;

  /// No description provided for @publishedReturnHome.
  ///
  /// In en, this message translates to:
  /// **'Back to menus'**
  String get publishedReturnHome;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable or permission denied'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailable;

  /// No description provided for @cameraTapToCapture.
  ///
  /// In en, this message translates to:
  /// **'Tap to capture'**
  String get cameraTapToCapture;

  /// No description provided for @cameraFinish.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String cameraFinish(int count);

  /// No description provided for @selectPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose menu photos'**
  String get selectPhotosTitle;

  /// No description provided for @selectPhotosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos selected'**
  String get selectPhotosEmpty;

  /// No description provided for @selectPhotosNext.
  ///
  /// In en, this message translates to:
  /// **'Next ({count})'**
  String selectPhotosNext(int count);

  /// No description provided for @correctImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct image ({current} / {total})'**
  String correctImageTitle(int current, int total);

  /// No description provided for @correctImageAutoCorrect.
  ///
  /// In en, this message translates to:
  /// **'Auto correct'**
  String get correctImageAutoCorrect;

  /// No description provided for @correctImageRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get correctImageRotate;

  /// No description provided for @correctImageCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get correctImageCrop;

  /// No description provided for @correctImageEnhance.
  ///
  /// In en, this message translates to:
  /// **'Enhance'**
  String get correctImageEnhance;

  /// No description provided for @correctImageUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get correctImageUndo;

  /// No description provided for @correctImageSmartCorrecting.
  ///
  /// In en, this message translates to:
  /// **'Smart correcting'**
  String get correctImageSmartCorrecting;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Import menu'**
  String get processingTitle;

  /// No description provided for @processingUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photos…'**
  String get processingUploading;

  /// No description provided for @processingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for server response…'**
  String get processingWaiting;

  /// No description provided for @processingOcr.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get processingOcr;

  /// No description provided for @processingStructuring.
  ///
  /// In en, this message translates to:
  /// **'Organizing menu…'**
  String get processingStructuring;

  /// No description provided for @processingQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued…'**
  String get processingQueued;

  /// No description provided for @processingRedirecting.
  ///
  /// In en, this message translates to:
  /// **'Redirecting…'**
  String get processingRedirecting;

  /// No description provided for @processingNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos selected'**
  String get processingNoPhotos;

  /// No description provided for @processingUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get processingUnknownError;

  /// No description provided for @processingParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parsing failed'**
  String get processingParseFailed;

  /// No description provided for @settingsLoadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get settingsLoadFailedShort;

  /// No description provided for @settingsPlanPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get settingsPlanPro;

  /// No description provided for @settingsTileStore.
  ///
  /// In en, this message translates to:
  /// **'Store info'**
  String get settingsTileStore;

  /// No description provided for @settingsTileSubAccounts.
  ///
  /// In en, this message translates to:
  /// **'Sub-accounts'**
  String get settingsTileSubAccounts;

  /// No description provided for @settingsTileSubAccountsTrailing.
  ///
  /// In en, this message translates to:
  /// **'3'**
  String get settingsTileSubAccountsTrailing;

  /// No description provided for @settingsTileSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription / upgrade'**
  String get settingsTileSubscription;

  /// No description provided for @settingsTileSubscriptionTrailing.
  ///
  /// In en, this message translates to:
  /// **'2026-12 expires'**
  String get settingsTileSubscriptionTrailing;

  /// No description provided for @settingsTileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsTileNotifications;

  /// No description provided for @settingsTileHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & feedback'**
  String get settingsTileHelp;

  /// No description provided for @settingsTileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsTileAbout;

  /// No description provided for @settingsTileAboutTrailing.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0'**
  String get settingsTileAboutTrailing;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsLanguageFollowSystem;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @storeManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get storeManageTitle;

  /// No description provided for @storeManageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String storeManageLoadFailed(String error);

  /// No description provided for @storeManageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String storeManageSaveFailed(String error);

  /// No description provided for @storeManageAddStoreDisabled.
  ///
  /// In en, this message translates to:
  /// **'Multi-store coming soon'**
  String get storeManageAddStoreDisabled;

  /// No description provided for @storeManageAddStore.
  ///
  /// In en, this message translates to:
  /// **'New store'**
  String get storeManageAddStore;

  /// No description provided for @storeManageBottomCaption.
  ///
  /// In en, this message translates to:
  /// **'Multi-store management coming soon'**
  String get storeManageBottomCaption;

  /// No description provided for @storeManageEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit store'**
  String get storeManageEditTooltip;

  /// No description provided for @storeManageEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit store'**
  String get storeManageEditTitle;

  /// No description provided for @storeManageFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get storeManageFieldName;

  /// No description provided for @storeManageFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get storeManageFieldAddress;

  /// No description provided for @storeManageMenuSetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} menu sets'**
  String storeManageMenuSetsCount(int count);

  /// No description provided for @storeManageWeeklyVisits.
  ///
  /// In en, this message translates to:
  /// **'{visits} visits this week'**
  String storeManageWeeklyVisits(String visits);

  /// No description provided for @storeManageCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get storeManageCurrentBadge;

  /// No description provided for @storeManageMoreEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get storeManageMoreEnter;

  /// No description provided for @storeManageMoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get storeManageMoreSettings;

  /// No description provided for @storeManageMoreCopyMenu.
  ///
  /// In en, this message translates to:
  /// **'Copy menu'**
  String get storeManageMoreCopyMenu;

  /// No description provided for @aiOptimizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enhance menu'**
  String get aiOptimizeTitle;

  /// No description provided for @aiOptimizeAutoImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto imagery'**
  String get aiOptimizeAutoImageTitle;

  /// No description provided for @aiOptimizeAutoImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate images for 12 dishes without photos'**
  String get aiOptimizeAutoImageSubtitle;

  /// No description provided for @aiOptimizeDescExpandTitle.
  ///
  /// In en, this message translates to:
  /// **'Expand descriptions'**
  String get aiOptimizeDescExpandTitle;

  /// No description provided for @aiOptimizeDescExpandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write descriptions for 8 dishes without one'**
  String get aiOptimizeDescExpandSubtitle;

  /// No description provided for @aiOptimizeMultiLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-language'**
  String get aiOptimizeMultiLangTitle;

  /// No description provided for @aiOptimizeMultiLangSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Translate the menu to {language}'**
  String aiOptimizeMultiLangSubtitle(String language);

  /// No description provided for @aiOptimizeLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get aiOptimizeLangEnglish;

  /// No description provided for @aiOptimizeLangJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get aiOptimizeLangJapanese;

  /// No description provided for @aiOptimizeLangKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get aiOptimizeLangKorean;

  /// No description provided for @aiOptimizeLangFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get aiOptimizeLangFrench;

  /// No description provided for @aiOptimizeEstimatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Estimated '**
  String get aiOptimizeEstimatePrefix;

  /// No description provided for @aiOptimizeEstimateDuration.
  ///
  /// In en, this message translates to:
  /// **'1 m 20 s'**
  String get aiOptimizeEstimateDuration;

  /// No description provided for @aiOptimizeEstimateMiddle.
  ///
  /// In en, this message translates to:
  /// **', enhancing '**
  String get aiOptimizeEstimateMiddle;

  /// No description provided for @aiOptimizeEstimateCount.
  ///
  /// In en, this message translates to:
  /// **'23 dishes'**
  String get aiOptimizeEstimateCount;

  /// No description provided for @aiOptimizeCta.
  ///
  /// In en, this message translates to:
  /// **'Start enhancing'**
  String get aiOptimizeCta;

  /// No description provided for @selectTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose template'**
  String get selectTemplateTitle;

  /// No description provided for @selectTemplateUse.
  ///
  /// In en, this message translates to:
  /// **'Use this template'**
  String get selectTemplateUse;

  /// No description provided for @selectTemplateTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get selectTemplateTabAll;

  /// No description provided for @selectTemplateTabChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get selectTemplateTabChinese;

  /// No description provided for @selectTemplateTabWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get selectTemplateTabWestern;

  /// No description provided for @selectTemplateTabJpKr.
  ///
  /// In en, this message translates to:
  /// **'JP / KR'**
  String get selectTemplateTabJpKr;

  /// No description provided for @selectTemplateTabCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get selectTemplateTabCasual;

  /// No description provided for @selectTemplateTabCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe & desserts'**
  String get selectTemplateTabCafe;

  /// No description provided for @selectTemplateNameModern.
  ///
  /// In en, this message translates to:
  /// **'Inkblot'**
  String get selectTemplateNameModern;

  /// No description provided for @selectTemplateNameWarmGlow.
  ///
  /// In en, this message translates to:
  /// **'Warm Glow'**
  String get selectTemplateNameWarmGlow;

  /// No description provided for @selectTemplateNameMinimalWhite.
  ///
  /// In en, this message translates to:
  /// **'Minimal White'**
  String get selectTemplateNameMinimalWhite;

  /// No description provided for @selectTemplateNameWafu.
  ///
  /// In en, this message translates to:
  /// **'Wafu'**
  String get selectTemplateNameWafu;

  /// No description provided for @selectTemplateStyleModern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get selectTemplateStyleModern;

  /// No description provided for @selectTemplateStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get selectTemplateStyleClassic;

  /// No description provided for @selectTemplateCategoryChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get selectTemplateCategoryChinese;

  /// No description provided for @selectTemplateCategoryWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get selectTemplateCategoryWestern;

  /// No description provided for @selectTemplateCategoryCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get selectTemplateCategoryCasual;

  /// No description provided for @selectTemplateCategoryJpKr.
  ///
  /// In en, this message translates to:
  /// **'JP / KR'**
  String get selectTemplateCategoryJpKr;

  /// No description provided for @customThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme customization'**
  String get customThemeTitle;

  /// No description provided for @customThemeCta.
  ///
  /// In en, this message translates to:
  /// **'Save and preview'**
  String get customThemeCta;

  /// No description provided for @customThemeLogoLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo upload'**
  String get customThemeLogoLabel;

  /// No description provided for @customThemeLogoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get customThemeLogoUploaded;

  /// No description provided for @customThemeLogoReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get customThemeLogoReplace;

  /// No description provided for @customThemeColorPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get customThemeColorPrimary;

  /// No description provided for @customThemeColorAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get customThemeColorAccent;

  /// No description provided for @customThemeFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get customThemeFontLabel;

  /// No description provided for @customThemeFontModern.
  ///
  /// In en, this message translates to:
  /// **'Modern sans'**
  String get customThemeFontModern;

  /// No description provided for @customThemeFontSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get customThemeFontSerif;

  /// No description provided for @customThemeFontHandwritten.
  ///
  /// In en, this message translates to:
  /// **'Handwritten'**
  String get customThemeFontHandwritten;

  /// No description provided for @customThemeFontRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded'**
  String get customThemeFontRounded;

  /// No description provided for @customThemeRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get customThemeRadiusLabel;

  /// No description provided for @customThemeRadiusSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get customThemeRadiusSquare;

  /// No description provided for @customThemeRadiusSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get customThemeRadiusSoft;

  /// No description provided for @customThemeRadiusRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get customThemeRadiusRound;

  /// No description provided for @customThemePreviewStoreName.
  ///
  /// In en, this message translates to:
  /// **'Cloud Kitchen'**
  String get customThemePreviewStoreName;

  /// No description provided for @customThemePreviewStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fine Chinese'**
  String get customThemePreviewStoreSubtitle;

  /// No description provided for @customThemePreviewDishBraised.
  ///
  /// In en, this message translates to:
  /// **'Braised pork'**
  String get customThemePreviewDishBraised;

  /// No description provided for @customThemePreviewDishSteamed.
  ///
  /// In en, this message translates to:
  /// **'Steamed fish'**
  String get customThemePreviewDishSteamed;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get statisticsTitle;

  /// No description provided for @statisticsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get statisticsExport;

  /// No description provided for @statisticsRangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statisticsRangeToday;

  /// No description provided for @statisticsRangeSevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get statisticsRangeSevenDays;

  /// No description provided for @statisticsRangeThirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get statisticsRangeThirtyDays;

  /// No description provided for @statisticsRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get statisticsRangeCustom;

  /// No description provided for @statisticsOverviewVisits.
  ///
  /// In en, this message translates to:
  /// **'Total visits'**
  String get statisticsOverviewVisits;

  /// No description provided for @statisticsOverviewUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique visitors'**
  String get statisticsOverviewUnique;

  /// No description provided for @statisticsOverviewAvgStay.
  ///
  /// In en, this message translates to:
  /// **'Avg. stay'**
  String get statisticsOverviewAvgStay;

  /// No description provided for @statisticsTrendUp12.
  ///
  /// In en, this message translates to:
  /// **'↑12%'**
  String get statisticsTrendUp12;

  /// No description provided for @statisticsDailyVisits.
  ///
  /// In en, this message translates to:
  /// **'Daily visits'**
  String get statisticsDailyVisits;

  /// No description provided for @statisticsLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Past 7 days'**
  String get statisticsLastSevenDays;

  /// No description provided for @statisticsDishRanking.
  ///
  /// In en, this message translates to:
  /// **'Dish popularity'**
  String get statisticsDishRanking;

  /// No description provided for @statisticsDishTop5.
  ///
  /// In en, this message translates to:
  /// **'TOP 5'**
  String get statisticsDishTop5;

  /// No description provided for @statisticsPieTitle.
  ///
  /// In en, this message translates to:
  /// **'Category breakdown'**
  String get statisticsPieTitle;

  /// No description provided for @statisticsPieSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share of views by category'**
  String get statisticsPieSubtitle;

  /// No description provided for @statisticsPieCold.
  ///
  /// In en, this message translates to:
  /// **'Cold'**
  String get statisticsPieCold;

  /// No description provided for @statisticsPieHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get statisticsPieHot;

  /// No description provided for @statisticsTimesUnit.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get statisticsTimesUnit;

  /// No description provided for @statisticsChartDayPrefix.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statisticsChartDayPrefix;
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
