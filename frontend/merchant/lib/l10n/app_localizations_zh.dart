// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRetry => '重试';

  @override
  String get commonNext => '下一步';

  @override
  String get commonOperationFailed => '操作失败';

  @override
  String get authSlogan => '拍一张照，5 分钟生成电子菜单';

  @override
  String get authPhoneHint => '请输入手机号';

  @override
  String get authOtpHint => '请输入验证码';

  @override
  String get authSendOtp => '发送验证码';

  @override
  String get authSendingOtp => '发送中…';

  @override
  String authResendOtp(int seconds) {
    return '${seconds}s 重发';
  }

  @override
  String get authOtpSent => '验证码已发送';

  @override
  String get authEnterPhone => '请输入手机号';

  @override
  String get authEnterPhoneAndOtp => '请输入手机号和验证码';

  @override
  String get authSignIn => '登录';

  @override
  String get authSigningIn => '登录中…';

  @override
  String get authRegisterHint => '新用户？立即注册';

  @override
  String get authSeedLoginDev => '开发：种子账户登录';

  @override
  String get authFooterPoweredBy => '由 MenuRay 提供';

  @override
  String get authFooterTerms => '用户协议';

  @override
  String get authFooterPrivacy => '隐私政策';

  @override
  String get homeLoading => '加载中…';

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
    return '加载失败：$error';
  }

  @override
  String get homeMenusEmpty => '还没有菜单，点右下角\"新建菜单\"开始';

  @override
  String get homeFabNewMenu => '新建菜单';

  @override
  String get homeSourceSheetTitle => '新建菜单';

  @override
  String get homeSourceCamera => '拍照';

  @override
  String get homeSourceGallery => '从相册选择';

  @override
  String get homeTabMenus => 'Menus';

  @override
  String get homeTabData => 'Data';

  @override
  String get homeTabMine => 'Mine';

  @override
  String get homeSearchInputDefaultHint => '搜索菜单、菜品或状态…';

  @override
  String get statusPublished => '已发布';

  @override
  String get statusDraft => '草稿';

  @override
  String get statusSoldOut => '已售罄';

  @override
  String menuCardViews(int count) {
    return '$count 次访问';
  }

  @override
  String get menuCardToday => '今天';

  @override
  String get menuCardYesterday => '昨天';

  @override
  String menuCardDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String menuCardWeeksAgo(int weeks) {
    return '$weeks 周前';
  }

  @override
  String menuCardMonthsAgo(int months) {
    return '$months 个月前';
  }

  @override
  String menuManageLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String menuManageSoldOutUpdateFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String get menuManageUpdatedAgo => '更新于 3 天前';

  @override
  String get menuManageViewsLabel => '浏览量';

  @override
  String get menuManageSoldOutSection => '售罄管理';

  @override
  String get menuManageTimeSlotSection => '营业时段';

  @override
  String get menuManageActionEditContent => '编辑内容';

  @override
  String get menuManageActionSoldOut => '售罄管理';

  @override
  String get menuManageActionPriceAdjust => '调价';

  @override
  String get menuManageActionShare => '分享';

  @override
  String get menuManageActionStatistics => '数据';

  @override
  String get menuManageTimeSlotLunch => '午市';

  @override
  String get menuManageTimeSlotLunchHours => '11:00–14:00';

  @override
  String get menuManageTimeSlotDinner => '晚市';

  @override
  String get menuManageTimeSlotDinnerHours => '17:00–22:00';

  @override
  String get menuManageTimeSlotAllDay => '全天';

  @override
  String get menuManageTimeSlotAllDayHours => '营业时间内';

  @override
  String get menuManageTimeSlotSeasonal => '季节限定';

  @override
  String get menuManageTimeSlotSeasonalHours => '自定义日期';

  @override
  String get editDishTitle => '编辑菜品';

  @override
  String get editDishSaving => '保存中…';

  @override
  String editDishSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String editDishLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get editDishPhotoCamera => '拍照';

  @override
  String get editDishPhotoGallery => '相册';

  @override
  String get editDishPhotoAiGenerate => 'AI 生成';

  @override
  String get editDishFieldName => '名称';

  @override
  String get editDishFieldNameHint => '菜品名称';

  @override
  String get editDishFieldPrice => '价格';

  @override
  String get editDishFieldDescription => '描述';

  @override
  String get editDishFieldDescriptionHint => '请描述菜品特点…';

  @override
  String get editDishAiExpand => 'AI 扩写';

  @override
  String get editDishLocalizationSection => '本地化';

  @override
  String get editDishTranslateAll => '一键翻译';

  @override
  String get editDishLangChinese => '中文';

  @override
  String get editDishLangEnglish => 'EN';

  @override
  String get editDishEnNameHint => 'English name';

  @override
  String get editDishSpiceLabel => '辣度';

  @override
  String get editDishSpiceNone => '不辣';

  @override
  String get editDishSpiceMild => '微辣';

  @override
  String get editDishSpiceMedium => '中辣';

  @override
  String get editDishSpiceHot => '重辣';

  @override
  String get editDishTagsLabel => '标签';

  @override
  String get editDishTagSignature => '招牌';

  @override
  String get editDishTagRecommended => '推荐';

  @override
  String get editDishTagVegetarian => '素食';

  @override
  String get editDishAllergensLabel => '过敏原';

  @override
  String get editDishAllergenPeanut => '花生';

  @override
  String get editDishAllergenDairy => '乳制品';

  @override
  String get editDishAllergenSeafood => '海鲜';

  @override
  String get editDishAllergenGluten => '麸质';

  @override
  String get editDishAllergenEgg => '鸡蛋';

  @override
  String get organizeTitle => '整理菜单';

  @override
  String organizeLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String organizeReorderFailed(String error) {
    return '排序失败：$error';
  }

  @override
  String get organizeEmpty => '暂无分类';

  @override
  String organizeCategoryCount(int count) {
    return '$count 项';
  }

  @override
  String get organizeFabAdd => '新增';

  @override
  String get previewTitle => '预览';

  @override
  String get previewPublish => '发布';

  @override
  String previewLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get previewDevicePhone => '手机';

  @override
  String get previewDeviceTablet => '平板';

  @override
  String get previewLanguageChinese => '中文';

  @override
  String get previewLanguageEnglish => 'EN';

  @override
  String get previewEmptyDishes => '暂无菜品';

  @override
  String get previewStoreSubtitleCn => '川菜 · 11:00 - 22:00';

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
  String get previewFooterPoweredBy => '由 MenuRay 提供';

  @override
  String get previewReturnEdit => '返回编辑';

  @override
  String get previewPublishMenu => '发布菜单';

  @override
  String publishedLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get publishedUnpublished => '菜单未发布';

  @override
  String get publishedSuccessHeading => '菜单已发布！';

  @override
  String get publishedFooterHint => '访客扫码即可查看，无需安装 App';

  @override
  String get publishedCopyLink => '复制访问链接';

  @override
  String get publishedExportQr => '保存二维码';

  @override
  String get publishedExportPdf => '导出 PDF';

  @override
  String get publishedExportSocial => '导出朋友圈图';

  @override
  String get publishedSocialWeChat => '微信';

  @override
  String get publishedSocialCopy => '复制';

  @override
  String get publishedSocialMore => '更多';

  @override
  String get publishedReturnHome => '返回菜单首页';

  @override
  String get cameraPermissionDenied => '相机不可用或权限被拒绝';

  @override
  String get cameraUnavailable => '相机不可用';

  @override
  String get cameraTapToCapture => '点击开始拍摄';

  @override
  String cameraFinish(int count) {
    return '完成 ($count)';
  }

  @override
  String get selectPhotosTitle => '选择菜单图片';

  @override
  String get selectPhotosEmpty => '未选择照片';

  @override
  String selectPhotosNext(int count) {
    return '下一步 ($count)';
  }

  @override
  String correctImageTitle(int current, int total) {
    return '校正图片 ($current / $total)';
  }

  @override
  String get correctImageAutoCorrect => '自动校正';

  @override
  String get correctImageRotate => '旋转';

  @override
  String get correctImageCrop => '裁剪';

  @override
  String get correctImageEnhance => '对比度增强';

  @override
  String get correctImageUndo => '撤销';

  @override
  String get correctImageSmartCorrecting => '智能校正中';

  @override
  String get correctImageApply => '应用';

  @override
  String get correctImageDecodeFailed => '无法处理该图片';

  @override
  String get correctImageProcessing => '处理中…';

  @override
  String get processingTitle => '导入菜单';

  @override
  String get processingUploading => '正在上传图片…';

  @override
  String get processingWaiting => '等待服务器响应…';

  @override
  String get processingOcr => '识别中…';

  @override
  String get processingStructuring => '整理菜单…';

  @override
  String get processingQueued => '排队中…';

  @override
  String get processingRedirecting => '跳转中…';

  @override
  String get processingNoPhotos => '未选择照片';

  @override
  String get processingUnknownError => '未知错误';

  @override
  String get processingParseFailed => '解析失败';

  @override
  String get settingsLoadFailedShort => '加载失败';

  @override
  String get settingsPlanPro => '专业版';

  @override
  String get settingsTileStore => '店铺信息';

  @override
  String get settingsTileSubAccounts => '子账号管理';

  @override
  String get settingsTileSubAccountsTrailing => '3 人';

  @override
  String get settingsTileSubscription => '订阅 / 套餐升级';

  @override
  String get settingsTileSubscriptionTrailing => '2026-12 到期';

  @override
  String get settingsTileNotifications => '通知设置';

  @override
  String get settingsTileHelp => '帮助与反馈';

  @override
  String get settingsTileAbout => '关于';

  @override
  String get settingsTileAboutTrailing => 'v1.0.0';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageFollowSystem => '跟随系统';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get storeManageTitle => '门店管理';

  @override
  String storeManageLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String storeManageSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get storeManageAddStoreDisabled => '多店管理敬请期待';

  @override
  String get storeManageAddStore => '新增门店';

  @override
  String get storeManageBottomCaption => '多店管理敬请期待';

  @override
  String get storeManageEditTooltip => '编辑门店';

  @override
  String get storeManageEditTitle => '编辑门店';

  @override
  String get storeManageFieldName => '名称';

  @override
  String get storeManageFieldAddress => '地址';

  @override
  String storeManageMenuSetsCount(int count) {
    return '$count 套菜单';
  }

  @override
  String storeManageWeeklyVisits(String visits) {
    return '本周 $visits 访问';
  }

  @override
  String get storeManageCurrentBadge => '当前';

  @override
  String get storeManageMoreEnter => '进入';

  @override
  String get storeManageMoreSettings => '设置';

  @override
  String get storeManageMoreCopyMenu => '复制菜单';

  @override
  String get aiOptimizeTitle => '一键优化菜单';

  @override
  String get aiOptimizeAutoImageTitle => '自动配图';

  @override
  String get aiOptimizeAutoImageSubtitle => '给缺图的 12 道菜生成图片';

  @override
  String get aiOptimizeDescExpandTitle => '描述扩写';

  @override
  String get aiOptimizeDescExpandSubtitle => '给无描述的 8 道菜生成介绍';

  @override
  String get aiOptimizeMultiLangTitle => '多语言翻译';

  @override
  String aiOptimizeMultiLangSubtitle(String language) {
    return '把菜单翻译为 $language';
  }

  @override
  String get aiOptimizeLangEnglish => '英语';

  @override
  String get aiOptimizeLangJapanese => '日语';

  @override
  String get aiOptimizeLangKorean => '韩语';

  @override
  String get aiOptimizeLangFrench => '法语';

  @override
  String get aiOptimizeEstimatePrefix => '预计耗时 ';

  @override
  String get aiOptimizeEstimateDuration => '1 分 20 秒';

  @override
  String get aiOptimizeEstimateMiddle => '，将增强 ';

  @override
  String get aiOptimizeEstimateCount => '23 道菜';

  @override
  String get aiOptimizeCta => '开始增强';

  @override
  String get selectTemplateTitle => '选择模板';

  @override
  String get selectTemplateUse => '使用此模板';

  @override
  String get selectTemplateTabAll => '全部';

  @override
  String get selectTemplateTabChinese => '中餐';

  @override
  String get selectTemplateTabWestern => '西餐';

  @override
  String get selectTemplateTabJpKr => '日韩';

  @override
  String get selectTemplateTabCasual => '简餐';

  @override
  String get selectTemplateTabCafe => '咖啡甜品';

  @override
  String get selectTemplateNameModern => '墨意';

  @override
  String get selectTemplateNameWarmGlow => '暖光';

  @override
  String get selectTemplateNameMinimalWhite => '极简白';

  @override
  String get selectTemplateNameWafu => '和风';

  @override
  String get selectTemplateStyleModern => '现代';

  @override
  String get selectTemplateStyleClassic => '经典';

  @override
  String get selectTemplateCategoryChinese => '中餐';

  @override
  String get selectTemplateCategoryWestern => '西餐';

  @override
  String get selectTemplateCategoryCasual => '简餐';

  @override
  String get selectTemplateCategoryJpKr => '日韩';

  @override
  String get customThemeTitle => '主题定制';

  @override
  String get customThemeCta => '保存并预览';

  @override
  String get customThemeLogoLabel => 'Logo 上传';

  @override
  String get customThemeLogoUploaded => '已上传';

  @override
  String get customThemeLogoReplace => '更换';

  @override
  String get customThemeColorPrimary => '主色';

  @override
  String get customThemeColorAccent => '辅色';

  @override
  String get customThemeFontLabel => '字体';

  @override
  String get customThemeFontModern => '现代黑体';

  @override
  String get customThemeFontSerif => '衬线';

  @override
  String get customThemeFontHandwritten => '手写';

  @override
  String get customThemeFontRounded => '圆润';

  @override
  String get customThemeRadiusLabel => '圆角';

  @override
  String get customThemeRadiusSquare => '直角';

  @override
  String get customThemeRadiusSoft => '微圆';

  @override
  String get customThemeRadiusRound => '圆润';

  @override
  String get customThemePreviewStoreName => '云间小厨';

  @override
  String get customThemePreviewStoreSubtitle => '精致中餐';

  @override
  String get customThemePreviewDishBraised => '红烧肉';

  @override
  String get customThemePreviewDishSteamed => '清蒸鱼';

  @override
  String get statisticsTitle => '数据';

  @override
  String get statisticsExport => '导出';

  @override
  String get statisticsRangeToday => '今日';

  @override
  String get statisticsRangeSevenDays => '7 天';

  @override
  String get statisticsRangeThirtyDays => '30 天';

  @override
  String get statisticsRangeCustom => '自定义';

  @override
  String get statisticsOverviewVisits => '总访问量';

  @override
  String get statisticsOverviewUnique => '独立访客';

  @override
  String get statisticsOverviewAvgStay => '平均停留';

  @override
  String get statisticsTrendUp12 => '↑12%';

  @override
  String get statisticsDailyVisits => '每日访问量';

  @override
  String get statisticsLastSevenDays => '过去 7 天';

  @override
  String get statisticsDishRanking => '菜品热度排行';

  @override
  String get statisticsDishTop5 => 'TOP 5';

  @override
  String get statisticsPieTitle => '类别热度';

  @override
  String get statisticsPieSubtitle => '按类别统计浏览占比';

  @override
  String get statisticsPieCold => '凉菜';

  @override
  String get statisticsPieHot => '热菜';

  @override
  String get statisticsTimesUnit => '次';

  @override
  String get statisticsChartDayPrefix => 'Day';

  @override
  String get appearanceTitle => '外观';

  @override
  String get templateSectionTitle => '模板';

  @override
  String get colorSectionTitle => '主色';

  @override
  String get comingSoon => '即将推出';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get appearanceSave => '保存';

  @override
  String get appearanceSaveSuccess => '外观已保存';

  @override
  String get appearanceSaveFailed => '保存失败';

  @override
  String get menuManageAppearance => '外观';

  @override
  String get logoTapHint => '点击更换 Logo';

  @override
  String get logoUploadInProgress => 'Logo 上传中…';

  @override
  String get logoUploadSuccess => 'Logo 已更新';

  @override
  String get logoUploadFailed => 'Logo 上传失败';

  @override
  String get logoUploadTooLarge => 'Logo 不能超过 2 MB';

  @override
  String get logoUploadBadFormat => 'Logo 仅支持 PNG 或 SVG 格式';

  @override
  String get validationRequired => '必填';

  @override
  String validationRequiredFieldNamed(String field) {
    return '$field必填';
  }

  @override
  String get validationPhoneInvalid => '请输入有效手机号（11位中国手机号或 +国际号码）';

  @override
  String get validationPriceInvalid => '请输入数字';

  @override
  String get validationPriceNegative => '价格不能为负';

  @override
  String get validationPriceTooPrecise => '最多保留 2 位小数';

  @override
  String validationMaxLength(int max) {
    return '最多$max个字符';
  }

  @override
  String get logoutFailedSnackbar => '退出登录出错，但已返回登录页。';

  @override
  String get registerHintSnackbar => '新用户直接输入手机号，我们会发送验证码并自动创建账号。';

  @override
  String get emptyOrganizeCategoriesMessage => '此菜单还没有分类';

  @override
  String get emptyOrganizeCategoriesAction => '新增分类';

  @override
  String get emptyHomeMenusMessage => '还没有菜单';

  @override
  String get emptyHomeMenusAction => '拍一张菜单照片';

  @override
  String get errorGenericMessage => '出错了';

  @override
  String get errorRetry => '重试';

  @override
  String get loadingDefault => '加载中…';

  @override
  String get teamScreenTitle => '团队';

  @override
  String get teamTabMembers => '成员';

  @override
  String get teamTabInvites => '待接受邀请';

  @override
  String get teamInviteCta => '邀请成员';

  @override
  String get teamInviteEmailHint => '邮箱地址';

  @override
  String get teamInviteRoleLabel => '角色';

  @override
  String get teamInviteSend => '发送邀请';

  @override
  String teamInviteSentSnackbar(String email) {
    return '已为 $email 生成邀请链接';
  }

  @override
  String get teamInviteCopyLink => '复制链接';

  @override
  String get teamInviteLinkCopied => '已复制链接';

  @override
  String get teamInviteRevoke => '撤回';

  @override
  String get teamInviteExpiredBadge => '已过期';

  @override
  String get teamMemberRemove => '移除';

  @override
  String teamMemberRemoveConfirm(String name) {
    return '确定从当前门店移除 $name 吗？';
  }

  @override
  String get teamMemberChangeRole => '调整角色';

  @override
  String get teamMemberTransferOwnership => '转交所有权';

  @override
  String get teamMemberLastOwnerError => '不能移除最后一位所有者，请先转交所有权。';

  @override
  String get roleOwner => '所有者';

  @override
  String get roleManager => '管理员';

  @override
  String get roleStaff => '员工';

  @override
  String get roleOwnerDesc => '完整权限，包含计费与所有权转交。';

  @override
  String get roleManagerDesc => '管理菜单、发布、邀请成员。';

  @override
  String get roleStaffDesc => '查看菜单、标记售罄。';

  @override
  String get storePickerTitle => '选择门店';

  @override
  String storePickerSubtitle(int count) {
    return '你可访问 $count 家门店。';
  }

  @override
  String get authNoMembershipsBanner => '当前账号暂无活跃门店，请联系管理员。';

  @override
  String get billingPlanFree => '免费版';

  @override
  String get billingPlanPro => 'Pro';

  @override
  String get billingPlanGrowth => 'Growth';

  @override
  String billingMenusCap(int count) {
    return '$count 个菜单';
  }

  @override
  String billingDishesPerMenuCap(int count) {
    return '每菜单 $count 道';
  }

  @override
  String billingReparsesCap(int count) {
    return '每月 $count 次再解析';
  }

  @override
  String billingQrViewsCap(int count) {
    return '每月 $count 次扫码';
  }

  @override
  String billingLanguagesCap(int count) {
    return '$count 个语言';
  }

  @override
  String get billingMultiStore => '多门店';

  @override
  String get billingCustomBranding => '去除 MenuRay 徽标';

  @override
  String get billingPriorityCsv => 'CSV 导出 + 优先支持';

  @override
  String get billingCurrentTag => '当前';

  @override
  String get billingMonthlyToggle => '月付';

  @override
  String get billingAnnualToggle => '年付（约 8.5 折）';

  @override
  String get billingCurrencyUsd => '美元';

  @override
  String get billingCurrencyCny => '人民币';

  @override
  String get billingSubscribePro => '订阅 Pro';

  @override
  String get billingSubscribeGrowth => '订阅 Growth';

  @override
  String get billingManageBilling => '管理订阅';

  @override
  String get billingUpgradeTitle => '升级订阅';

  @override
  String get billingCheckoutOpening => '正在打开 Stripe…';

  @override
  String get billingCheckoutFailed => '无法打开支付页，请重试。';

  @override
  String paywallMenuCapReached(String tier) {
    return '已达到 $tier 套餐菜单上限。';
  }

  @override
  String get paywallReparseQuotaReached => '本月 AI 再解析次数已用完。';

  @override
  String paywallTranslationCapReached(String tier) {
    return '$tier 套餐语言数上限。';
  }

  @override
  String get paywallCustomThemeLocked => '自定义主题需 Pro 以上';

  @override
  String get paywallMultiStoreLocked => '多门店需 Growth';
}
