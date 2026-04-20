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
}
