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
  String get homeSourceSheetTitle => 'Add a menu';

  @override
  String get homeSourceCamera => 'Take photo';

  @override
  String get homeSourceGallery => 'Choose from album';

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

  @override
  String get editDishTitle => 'Edit dish';

  @override
  String get editDishSaving => 'Saving…';

  @override
  String editDishSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String editDishLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get editDishPhotoCamera => 'Camera';

  @override
  String get editDishPhotoGallery => 'Gallery';

  @override
  String get editDishPhotoAiGenerate => 'AI generate';

  @override
  String get editDishFieldName => 'Name';

  @override
  String get editDishFieldNameHint => 'Dish name';

  @override
  String get editDishFieldPrice => 'Price';

  @override
  String get editDishFieldDescription => 'Description';

  @override
  String get editDishFieldDescriptionHint => 'Describe the dish…';

  @override
  String get editDishAiExpand => 'AI expand';

  @override
  String get editDishLocalizationSection => 'Localization';

  @override
  String get editDishTranslateAll => 'Translate all';

  @override
  String get editDishLangChinese => '中文';

  @override
  String get editDishLangEnglish => 'EN';

  @override
  String get editDishEnNameHint => 'English name';

  @override
  String get editDishSpiceLabel => 'Spice';

  @override
  String get editDishSpiceNone => 'None';

  @override
  String get editDishSpiceMild => 'Mild';

  @override
  String get editDishSpiceMedium => 'Medium';

  @override
  String get editDishSpiceHot => 'Hot';

  @override
  String get editDishTagsLabel => 'Tags';

  @override
  String get editDishTagSignature => 'Signature';

  @override
  String get editDishTagRecommended => 'Recommended';

  @override
  String get editDishTagVegetarian => 'Vegetarian';

  @override
  String get editDishAllergensLabel => 'Allergens';

  @override
  String get editDishAllergenPeanut => 'Peanut';

  @override
  String get editDishAllergenDairy => 'Dairy';

  @override
  String get editDishAllergenSeafood => 'Seafood';

  @override
  String get editDishAllergenGluten => 'Gluten';

  @override
  String get editDishAllergenEgg => 'Egg';

  @override
  String get organizeTitle => 'Organize menu';

  @override
  String organizeLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String organizeReorderFailed(String error) {
    return 'Reorder failed: $error';
  }

  @override
  String get organizeEmpty => 'No categories yet';

  @override
  String organizeCategoryCount(int count) {
    return '$count items';
  }

  @override
  String get organizeFabAdd => 'New';

  @override
  String get previewTitle => 'Preview';

  @override
  String get previewPublish => 'Publish';

  @override
  String previewLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get previewDevicePhone => 'Phone';

  @override
  String get previewDeviceTablet => 'Tablet';

  @override
  String get previewLanguageChinese => '中文';

  @override
  String get previewLanguageEnglish => 'EN';

  @override
  String get previewEmptyDishes => 'No dishes yet';

  @override
  String get previewStoreSubtitleCn => 'Sichuan · 11:00 - 22:00';

  @override
  String get previewStoreSubtitleEn => 'Sichuan · 11:00 - 22:00';

  @override
  String get previewSampleCategoriesCn => '凉菜,热菜,主食,汤品,饮品';

  @override
  String get previewSampleCategoriesEn => 'Cold,Hot,Staple,Soup,Drink';

  @override
  String get previewDishChefSpecial => 'Chef\'s Special';

  @override
  String get previewDishChefSpecialCn => '招牌';

  @override
  String get previewDishSpicy => 'Spicy';

  @override
  String get previewDishSpicyCn => '辣';

  @override
  String get previewFooterPoweredBy => 'Powered by MenuRay';

  @override
  String get previewReturnEdit => 'Return to edit';

  @override
  String get previewPublishMenu => 'Publish menu';

  @override
  String publishedLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get publishedUnpublished => 'Menu not published';

  @override
  String get publishedSuccessHeading => 'Menu published!';

  @override
  String get publishedFooterHint =>
      'Guests scan the QR — no app install needed';

  @override
  String get publishedCopyLink => 'Copy shareable link';

  @override
  String get publishedExportQr => 'Save QR code';

  @override
  String get publishedExportPdf => 'Export PDF';

  @override
  String get publishedExportSocial => 'Export social image';

  @override
  String get publishedSocialWeChat => 'WeChat';

  @override
  String get publishedSocialCopy => 'Copy';

  @override
  String get publishedSocialMore => 'More';

  @override
  String get publishedReturnHome => 'Back to menus';

  @override
  String get cameraPermissionDenied =>
      'Camera unavailable or permission denied';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get cameraTapToCapture => 'Tap to capture';

  @override
  String cameraFinish(int count) {
    return 'Done ($count)';
  }

  @override
  String get selectPhotosTitle => 'Choose menu photos';

  @override
  String get selectPhotosEmpty => 'No photos selected';

  @override
  String selectPhotosNext(int count) {
    return 'Next ($count)';
  }

  @override
  String correctImageTitle(int current, int total) {
    return 'Correct image ($current / $total)';
  }

  @override
  String get correctImageAutoCorrect => 'Auto correct';

  @override
  String get correctImageRotate => 'Rotate';

  @override
  String get correctImageCrop => 'Crop';

  @override
  String get correctImageEnhance => 'Enhance';

  @override
  String get correctImageUndo => 'Undo';

  @override
  String get correctImageSmartCorrecting => 'Smart correcting';

  @override
  String get correctImageApply => 'Apply';

  @override
  String get correctImageDecodeFailed => 'Unable to process image';

  @override
  String get correctImageProcessing => 'Processing…';

  @override
  String get processingTitle => 'Import menu';

  @override
  String get processingUploading => 'Uploading photos…';

  @override
  String get processingWaiting => 'Waiting for server response…';

  @override
  String get processingOcr => 'Recognizing…';

  @override
  String get processingStructuring => 'Organizing menu…';

  @override
  String get processingQueued => 'Queued…';

  @override
  String get processingRedirecting => 'Redirecting…';

  @override
  String get processingNoPhotos => 'No photos selected';

  @override
  String get processingUnknownError => 'Unknown error';

  @override
  String get processingParseFailed => 'Parsing failed';

  @override
  String get settingsLoadFailedShort => 'Failed to load';

  @override
  String get settingsPlanPro => 'Pro';

  @override
  String get settingsTileStore => 'Store info';

  @override
  String get settingsTileSubAccounts => 'Sub-accounts';

  @override
  String get settingsTileSubAccountsTrailing => '3';

  @override
  String get settingsTileSubscription => 'Subscription / upgrade';

  @override
  String get settingsTileSubscriptionTrailing => '2026-12 expires';

  @override
  String get settingsTileNotifications => 'Notifications';

  @override
  String get settingsTileHelp => 'Help & feedback';

  @override
  String get settingsTileAbout => 'About';

  @override
  String get settingsTileAboutTrailing => 'v1.0.0';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageFollowSystem => 'Follow system';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get storeManageTitle => 'Stores';

  @override
  String storeManageLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String storeManageSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get storeManageAddStoreDisabled => 'Multi-store coming soon';

  @override
  String get storeManageAddStore => 'New store';

  @override
  String get storeManageBottomCaption => 'Multi-store management coming soon';

  @override
  String get storeManageEditTooltip => 'Edit store';

  @override
  String get storeManageEditTitle => 'Edit store';

  @override
  String get storeManageFieldName => 'Name';

  @override
  String get storeManageFieldAddress => 'Address';

  @override
  String storeManageMenuSetsCount(int count) {
    return '$count menu sets';
  }

  @override
  String storeManageWeeklyVisits(String visits) {
    return '$visits visits this week';
  }

  @override
  String get storeManageCurrentBadge => 'Current';

  @override
  String get storeManageMoreEnter => 'Enter';

  @override
  String get storeManageMoreSettings => 'Settings';

  @override
  String get storeManageMoreCopyMenu => 'Copy menu';

  @override
  String get aiOptimizeTitle => 'Enhance menu';

  @override
  String get aiOptimizeAutoImageTitle => 'Auto imagery';

  @override
  String get aiOptimizeAutoImageSubtitle =>
      'Generate images for 12 dishes without photos';

  @override
  String get aiOptimizeDescExpandTitle => 'Expand descriptions';

  @override
  String get aiOptimizeDescExpandSubtitle =>
      'Write descriptions for 8 dishes without one';

  @override
  String get aiOptimizeMultiLangTitle => 'Multi-language';

  @override
  String aiOptimizeMultiLangSubtitle(String language) {
    return 'Translate the menu to $language';
  }

  @override
  String get aiOptimizeLangEnglish => 'English';

  @override
  String get aiOptimizeLangJapanese => 'Japanese';

  @override
  String get aiOptimizeLangKorean => 'Korean';

  @override
  String get aiOptimizeLangFrench => 'French';

  @override
  String get aiOptimizeEstimatePrefix => 'Estimated ';

  @override
  String get aiOptimizeEstimateDuration => '1 m 20 s';

  @override
  String get aiOptimizeEstimateMiddle => ', enhancing ';

  @override
  String get aiOptimizeEstimateCount => '23 dishes';

  @override
  String get aiOptimizeCta => 'Start enhancing';

  @override
  String get selectTemplateTitle => 'Choose template';

  @override
  String get selectTemplateUse => 'Use this template';

  @override
  String get selectTemplateTabAll => 'All';

  @override
  String get selectTemplateTabChinese => 'Chinese';

  @override
  String get selectTemplateTabWestern => 'Western';

  @override
  String get selectTemplateTabJpKr => 'JP / KR';

  @override
  String get selectTemplateTabCasual => 'Casual';

  @override
  String get selectTemplateTabCafe => 'Cafe & desserts';

  @override
  String get selectTemplateNameModern => 'Inkblot';

  @override
  String get selectTemplateNameWarmGlow => 'Warm Glow';

  @override
  String get selectTemplateNameMinimalWhite => 'Minimal White';

  @override
  String get selectTemplateNameWafu => 'Wafu';

  @override
  String get selectTemplateStyleModern => 'Modern';

  @override
  String get selectTemplateStyleClassic => 'Classic';

  @override
  String get selectTemplateCategoryChinese => 'Chinese';

  @override
  String get selectTemplateCategoryWestern => 'Western';

  @override
  String get selectTemplateCategoryCasual => 'Casual';

  @override
  String get selectTemplateCategoryJpKr => 'JP / KR';

  @override
  String get customThemeTitle => 'Theme customization';

  @override
  String get customThemeCta => 'Save and preview';

  @override
  String get customThemeLogoLabel => 'Logo upload';

  @override
  String get customThemeLogoUploaded => 'Uploaded';

  @override
  String get customThemeLogoReplace => 'Replace';

  @override
  String get customThemeColorPrimary => 'Primary';

  @override
  String get customThemeColorAccent => 'Accent';

  @override
  String get customThemeFontLabel => 'Font';

  @override
  String get customThemeFontModern => 'Modern sans';

  @override
  String get customThemeFontSerif => 'Serif';

  @override
  String get customThemeFontHandwritten => 'Handwritten';

  @override
  String get customThemeFontRounded => 'Rounded';

  @override
  String get customThemeRadiusLabel => 'Corner radius';

  @override
  String get customThemeRadiusSquare => 'Square';

  @override
  String get customThemeRadiusSoft => 'Soft';

  @override
  String get customThemeRadiusRound => 'Round';

  @override
  String get customThemePreviewStoreName => 'Cloud Kitchen';

  @override
  String get customThemePreviewStoreSubtitle => 'Fine Chinese';

  @override
  String get customThemePreviewDishBraised => 'Braised pork';

  @override
  String get customThemePreviewDishSteamed => 'Steamed fish';

  @override
  String get statisticsTitle => 'Data';

  @override
  String get statisticsExport => 'Export';

  @override
  String get statisticsRangeToday => 'Today';

  @override
  String get statisticsRangeSevenDays => '7 days';

  @override
  String get statisticsRangeThirtyDays => '30 days';

  @override
  String get statisticsRangeCustom => 'Custom';

  @override
  String get statisticsOverviewVisits => 'Total visits';

  @override
  String get statisticsOverviewUnique => 'Unique visitors';

  @override
  String get statisticsOverviewAvgStay => 'Avg. stay';

  @override
  String get statisticsTrendUp12 => '↑12%';

  @override
  String get statisticsDailyVisits => 'Daily visits';

  @override
  String get statisticsLastSevenDays => 'Past 7 days';

  @override
  String get statisticsDishRanking => 'Dish popularity';

  @override
  String get statisticsDishTop5 => 'TOP 5';

  @override
  String get statisticsPieTitle => 'Category breakdown';

  @override
  String get statisticsPieSubtitle => 'Share of views by category';

  @override
  String get statisticsPieCold => 'Cold';

  @override
  String get statisticsPieHot => 'Hot';

  @override
  String get statisticsTimesUnit => 'times';

  @override
  String get statisticsChartDayPrefix => 'Day';
}
