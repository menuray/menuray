import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                        // ── Logo + Brand ──────────────────────────────────
                        _LogoSection(),
                        const SizedBox(height: 48),

                        // ── Form ─────────────────────────────────────────
                        _PhoneField(),
                        const SizedBox(height: 24),
                        _CodeField(),
                        const SizedBox(height: 24 + 16), // mt-4 equivalent

                        // ── Actions ───────────────────────────────────────
                        PrimaryButton(
                          label: '登录',
                          onPressed: () => context.go(AppRoutes.home),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            '新用户？立即注册',
                            style: TextStyle(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Footer (pinned at bottom) ──────────────────────────────
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo + Brand section
// ─────────────────────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo icon container — 墨绿 rounded square with menu-page representation
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer, // primary-container == 墨绿
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: _MenuPageIcon(),
          ),
        ),
        const SizedBox(height: 24),

        // Wordmark
        Text(
          'Happy Menu',
          style: TextStyle(
            color: AppColors.primaryContainer,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Slogan
        Text(
          '拍一张照，5 分钟生成电子菜单',
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

// Inline menu-page icon drawn with Stack + Containers
class _MenuPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main page rectangle —暖米白 background
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface, // 暖米白
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withAlpha(30),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // Menu text lines
                Positioned(
                  top: 16,
                  left: 8,
                  right: 8,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 28,
                  left: 8,
                  right: 16,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 8,
                  right: 8,
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

          // Curled corner — 琥珀金 (accent) rotated square at top-right
          Positioned(
            top: -4,
            right: -4,
            child: Transform.rotate(
              angle: 0.21, // ~12 degrees in radians
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent, // 琥珀金
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

// ─────────────────────────────────────────────────────────────────────────────
// Phone input field
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.phone,
      style: TextStyle(color: AppColors.ink),
      decoration: InputDecoration(
        hintText: '请输入手机号',
        hintStyle: TextStyle(color: AppColors.secondary.withAlpha(153)),
        prefixIcon: Icon(Icons.smartphone, color: AppColors.secondary),
        filled: true,
        fillColor: const Color(0xFFE6E2DB), // surface-container-highest
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
          borderSide: BorderSide(color: AppColors.primaryContainer, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification code input field — error state shown
// ─────────────────────────────────────────────────────────────────────────────

class _CodeField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.centerRight,
          children: [
            // Code TextField
            TextField(
              controller: TextEditingController(text: '1234'),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.error),
              decoration: InputDecoration(
                hintText: '请输入验证码',
                hintStyle: TextStyle(color: AppColors.secondary.withAlpha(153)),
                prefixIcon: Icon(Icons.lock, color: AppColors.secondary),
                filled: true,
                fillColor: const Color(0xFFE6E2DB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: AppColors.error.withAlpha(127), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: AppColors.error.withAlpha(127), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.error, width: 1),
                ),
                // Extra right padding to make room for the countdown button
                contentPadding: const EdgeInsets.only(
                    top: 16, bottom: 16, left: 16, right: 108),
              ),
            ),

            // Countdown button (disabled)
            Positioned(
              right: 8,
              child: OutlinedButton(
                onPressed: null, // disabled
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F3EC), // surface-container-low
                  disabledForegroundColor:
                      AppColors.secondary.withAlpha(204),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(80, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '59s 重发',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),

        // Error message row
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 16),
            const SizedBox(width: 4),
            Text(
              '验证码错误，请重新输入',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — pinned at bottom
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          Text(
            '由 Happy Menu 提供',
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
                  '用户协议',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        AppColors.secondary.withAlpha(127),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Small dot separator
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
                  '隐私政策',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        AppColors.secondary.withAlpha(127),
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
