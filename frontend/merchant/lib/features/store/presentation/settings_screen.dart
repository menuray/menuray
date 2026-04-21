import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/store.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_providers.dart';
import '../../home/home_providers.dart';
import '../../settings/locale_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final storeAsync = ref.watch(currentStoreProvider);
    final currentLocale = ref.watch(localeNotifierProvider);
    final languageTrailing = _languageLabel(l, currentLocale);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _ProfileHeader(storeAsync: storeAsync),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  _SettingsGroup(
                    items: [
                      _SettingsTile(
                        icon: Icons.store,
                        iconBgColor: const Color(0x0D154539),
                        iconColor: AppColors.primaryDark,
                        label: l.settingsTileStore,
                        onTap: () => context.go(AppRoutes.storeManage),
                      ),
                      _SettingsTile(
                        icon: Icons.people,
                        iconBgColor: const Color(0x0D154539),
                        iconColor: AppColors.primaryDark,
                        label: l.settingsTileSubAccounts,
                        trailing: l.settingsTileSubAccountsTrailing,
                        onTap: () => context.go(AppRoutes.storeManage),
                      ),
                      _SettingsTile(
                        icon: Icons.card_membership,
                        iconBgColor: const Color(0x1A754C14),
                        iconColor: const Color(0xFF754C14),
                        label: l.settingsTileSubscription,
                        trailing: l.settingsTileSubscriptionTrailing,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    items: [
                      _SettingsTile(
                        icon: Icons.language,
                        iconBgColor: const Color(0xFFEBE8E1),
                        iconColor: const Color(0xFF404945),
                        label: l.settingsLanguage,
                        trailing: languageTrailing,
                        onTap: () => _showLanguageSheet(context, ref),
                      ),
                      _SettingsTile(
                        icon: Icons.notifications,
                        iconBgColor: const Color(0xFFEBE8E1),
                        iconColor: const Color(0xFF404945),
                        label: l.settingsTileNotifications,
                      ),
                      _SettingsTile(
                        icon: Icons.help_outline,
                        iconBgColor: const Color(0xFFEBE8E1),
                        iconColor: const Color(0xFF404945),
                        label: l.settingsTileHelp,
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        iconBgColor: const Color(0xFFEBE8E1),
                        iconColor: const Color(0xFF404945),
                        label: l.settingsTileAbout,
                        trailing: l.settingsTileAboutTrailing,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _LogoutButton(
                    onTap: () async {
                      final l = AppLocalizations.of(context)!;
                      try {
                        await ref.read(authRepositoryProvider).signOut();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.logoutFailedSnackbar)),
                          );
                        }
                      }
                      if (context.mounted) context.go(AppRoutes.login);
                    },
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

  String _languageLabel(AppLocalizations l, Locale? current) {
    if (current == null) return l.settingsLanguageFollowSystem;
    switch (current.languageCode) {
      case 'zh':
        return l.settingsLanguageChinese;
      case 'en':
        return l.settingsLanguageEnglish;
      default:
        return l.settingsLanguageFollowSystem;
    }
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(localeNotifierProvider);
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: RadioGroup<String?>(
          groupValue: current?.languageCode,
          onChanged: (value) {
            final Locale? locale = value == null ? null : Locale(value);
            ref.read(localeNotifierProvider.notifier).set(locale);
            Navigator.pop(sheetCtx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                value: null,
                title: Text(l.settingsLanguageFollowSystem),
              ),
              RadioListTile<String?>(
                value: 'zh',
                title: Text(l.settingsLanguageChinese),
              ),
              RadioListTile<String?>(
                value: 'en',
                title: Text(l.settingsLanguageEnglish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.storeAsync});

  final AsyncValue<Store> storeAsync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 24),
      child: Row(
        children: [
          _Avatar(storeAsync: storeAsync),
          const SizedBox(width: 20),
          // Name + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                storeAsync.when(
                  data: (store) => Text(
                    store.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  loading: () => Text(
                    l.homeLoading,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  error: (_, _) => Text(
                    l.settingsLoadFailedShort,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const _PlanBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.storeAsync});

  final AsyncValue<Store> storeAsync;

  @override
  Widget build(BuildContext context) {
    final logoUrl = storeAsync.asData?.value.logoUrl;
    return Container(
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
        child: logoUrl != null && logoUrl.isNotEmpty
            ? Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: AppColors.primary,
        child: const Icon(Icons.storefront, color: Colors.white, size: 40),
      );
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
        children: [
          const Icon(Icons.star, color: Color(0xFF2B1700), size: 14),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.settingsPlanPro,
            style: const TextStyle(
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
    this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              children: [
                const Icon(Icons.logout, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.settingsLogout,
                  style: const TextStyle(
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
