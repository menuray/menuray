import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/validation.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';
import '../auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpController = TextEditingController();

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _sendingOtp = false;
  bool _verifying = false;
  String? _otpError;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdownSeconds -= 1;
        if (_countdownSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _onSendOtp() async {
    if (_formKey.currentState?.validate() != true) return;
    final phone = normalizePhone(_phoneController.text);
    setState(() => _sendingOtp = true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      _startCountdown();
      _showSnack(AppLocalizations.of(context)!.authOtpSent);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_messageOf(e));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final l = AppLocalizations.of(context)!;
    final phone = normalizePhone(_phoneController.text);
    final token = _otpController.text.trim();
    if (token.isEmpty) {
      setState(() => _otpError = l.authEnterPhoneAndOtp);
      return;
    }
    setState(() {
      _otpError = null;
      _verifying = true;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            phone: phone,
            token: token,
          );
      // Router guard handles redirect on auth state change.
    } catch (e) {
      if (!mounted) return;
      setState(() => _otpError = _messageOf(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _onSeedLogin() async {
    try {
      await ref.read(authRepositoryProvider).signInSeed();
    } catch (e) {
      if (!mounted) return;
      _showSnack(_messageOf(e));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _messageOf(Object e) {
    final s = e.toString();
    return s.isEmpty ? AppLocalizations.of(context)!.commonOperationFailed : s;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _LogoSection(),
                        const SizedBox(height: 48),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            key: const Key('login-phone-field'),
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (v) => validatePhoneOrChineseMobile(
                                v, AppLocalizations.of(context)!),
                            style: TextStyle(color: AppColors.ink),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.authPhoneHint,
                              hintStyle: TextStyle(
                                  color: AppColors.secondary.withValues(alpha: 0.6)),
                              prefixIcon:
                                  Icon(Icons.smartphone, color: AppColors.secondary),
                              filled: true,
                              fillColor: const Color(0xFFE6E2DB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: AppColors.primaryContainer, width: 1),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: AppColors.error, width: 1),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: AppColors.error, width: 1),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _CodeField(
                          controller: _otpController,
                          countdownSeconds: _countdownSeconds,
                          sending: _sendingOtp,
                          errorText: _otpError,
                          onSendOtp: _onSendOtp,
                        ),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          key: const Key('login-submit-button'),
                          label: _verifying ? l.authSigningIn : l.authSignIn,
                          onPressed: _verifying ? null : _submit,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {
                            _phoneFocusNode.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    AppLocalizations.of(context)!
                                        .registerHintSnackbar),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          child: Text(
                            l.authRegisterHint,
                            style: TextStyle(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (kDebugMode ||
                            const bool.fromEnvironment('SHOW_SEED_LOGIN')) ...[
                          const SizedBox(height: 24),
                          TextButton(
                            key: const ValueKey('seed-login-button'),
                            onPressed: _onSeedLogin,
                            child: Text(l.authSeedLoginDev),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(child: _MenuPageIcon()),
        ),
        const SizedBox(height: 24),
        Text(
          'MenuRay',
          style: TextStyle(
            color: AppColors.primaryContainer,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.authSlogan,
          style: TextStyle(
            color: AppColors.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _MenuPageIcon extends StatelessWidget {
  const _MenuPageIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16, left: 8, right: 8,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 28, left: 8, right: 16,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 40, left: 8, right: 8,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -4, right: -4,
            child: Transform.rotate(
              angle: 0.21,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.countdownSeconds,
    required this.sending,
    required this.errorText,
    required this.onSendOtp,
  });

  final TextEditingController controller;
  final int countdownSeconds;
  final bool sending;
  final String? errorText;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final borderColor = hasError ? AppColors.error.withAlpha(127) : Colors.transparent;
    final canTapSend = !sending && countdownSeconds == 0;
    final sendLabel = sending
        ? l.authSendingOtp
        : countdownSeconds > 0
            ? l.authResendOtp(countdownSeconds)
            : l.authSendOtp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: hasError ? AppColors.error : AppColors.ink),
              decoration: InputDecoration(
                hintText: l.authOtpHint,
                hintStyle:
                    TextStyle(color: AppColors.secondary.withAlpha(153)),
                prefixIcon: Icon(Icons.lock, color: AppColors.secondary),
                filled: true,
                fillColor: const Color(0xFFE6E2DB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: hasError ? AppColors.error : AppColors.primaryContainer,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.only(
                    top: 16, bottom: 16, left: 16, right: 128),
              ),
            ),
            Positioned(
              right: 8,
              child: OutlinedButton(
                onPressed: canTapSend ? onSendOtp : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F3EC),
                  foregroundColor: AppColors.primaryContainer,
                  disabledForegroundColor: AppColors.secondary.withAlpha(204),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(100, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  sendLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          Text(
            l.authFooterPoweredBy,
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {},
                child: Text(
                  l.authFooterTerms,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.secondary.withAlpha(127),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(127),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () {},
                child: Text(
                  l.authFooterPrivacy,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.secondary.withAlpha(127),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
