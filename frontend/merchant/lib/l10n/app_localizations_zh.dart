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
}
