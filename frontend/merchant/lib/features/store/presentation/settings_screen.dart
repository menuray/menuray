import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const _ProfileHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  const _SettingsGroup(
                    items: [
                      _SettingsTile(
                        icon: Icons.store,
                        iconBgColor: Color(0x0D154539),
                        iconColor: AppColors.primaryDark,
                        label: '店铺信息',
                      ),
                      _SettingsTile(
                        icon: Icons.people,
                        iconBgColor: Color(0x0D154539),
                        iconColor: AppColors.primaryDark,
                        label: '子账号管理',
                        trailing: '3 人',
                      ),
                      _SettingsTile(
                        icon: Icons.card_membership,
                        iconBgColor: Color(0x1A754C14),
                        iconColor: Color(0xFF754C14),
                        label: '订阅 / 套餐升级',
                        trailing: '2026-12 到期',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SettingsGroup(
                    items: [
                      _SettingsTile(
                        icon: Icons.notifications,
                        iconBgColor: Color(0xFFEBE8E1),
                        iconColor: Color(0xFF404945),
                        label: '通知设置',
                      ),
                      _SettingsTile(
                        icon: Icons.help_outline,
                        iconBgColor: Color(0xFFEBE8E1),
                        iconColor: Color(0xFF404945),
                        label: '帮助与反馈',
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        iconBgColor: Color(0xFFEBE8E1),
                        iconColor: Color(0xFF404945),
                        label: '关于',
                        trailing: 'v1.0.0',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _LogoutButton(
                    onTap: () => context.go(AppRoutes.login),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MerchantBottomNav(
        current: MerchantTab.mine,
        onTap: (tab) {
          switch (tab) {
            case MerchantTab.menus:
              context.go(AppRoutes.home);
            case MerchantTab.data:
              context.go(AppRoutes.statistics);
            case MerchantTab.mine:
              // no-op — already on mine tab
              break;
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 24),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/sample/store_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary,
                  child: const Icon(Icons.storefront, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Name + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MockData.currentStore.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const _PlanBadge(),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.star, color: Color(0xFF2B1700), size: 14),
          SizedBox(width: 4),
          Text(
            '专业版',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B1700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Group
// ---------------------------------------------------------------------------

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});
  final List<_SettingsTile> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 64,
                endIndent: 0,
                color: Color(0xFFECE7DC),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right, color: AppColors.secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logout Button
// ---------------------------------------------------------------------------

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0x4DFFDAD6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout, color: AppColors.error, size: 20),
                SizedBox(width: 8),
                Text(
                  '退出登录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
