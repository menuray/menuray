import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/models/store.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/menu_card.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../shared/widgets/search_input.dart';
import '../../../theme/app_colors.dart';
import '../home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final storeAsync = ref.watch(currentStoreProvider);
    final menusAsync = ref.watch(menusProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _TopBar(storeAsync: storeAsync),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentStoreProvider);
          await ref.read(menusProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchInput(hintText: l.homeSearchHint),
              const SizedBox(height: 32),
              _SectionHeader(
                title: l.homeMenusTitle,
                total: menusAsync.maybeWhen(
                  data: (list) => l.homeMenusTotal(list.length),
                  orElse: () => l.homeMenusTotalPlaceholder,
                ),
              ),
              const SizedBox(height: 16),
              _MenuList(menusAsync: menusAsync, onEmptyAction: () => _showSourceSheet(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSourceSheet(context),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          l.homeFabNewMenu,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: MerchantBottomNav(
        current: MerchantTab.menus,
        onTap: (tab) {
          switch (tab) {
            case MerchantTab.menus:
              break;
            case MerchantTab.data:
              context.go(AppRoutes.statistics);
            case MerchantTab.mine:
              context.go(AppRoutes.settings);
          }
        },
      ),
    );
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.homeSourceSheetTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.homeSourceCamera),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.go(AppRoutes.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.homeSourceGallery),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.go(AppRoutes.selectPhotos);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.storeAsync});

  final AsyncValue<Store> storeAsync;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = storeAsync.maybeWhen(
      data: (s) => s.name,
      orElse: () => l.homeLoading,
    );
    return Container(
      color: AppColors.surface.withAlpha(204),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.primaryDark),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              const _StoreAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.divider,
        child: ClipOval(
          child: Image.asset(
            'assets/sample/store_avatar.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Icon(
              Icons.store,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.total});

  final String title;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        Text(
          total,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MenuList extends ConsumerWidget {
  const _MenuList({required this.menusAsync, required this.onEmptyAction});

  final AsyncValue<List<Menu>> menusAsync;
  final VoidCallback onEmptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return menusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _ErrorBlock(
        message: AppLocalizations.of(context)!.homeMenusLoadFailed('$err'),
        onRetry: () => ref.invalidate(menusProvider),
      ),
      data: (menus) {
        if (menus.isEmpty) {
          final l = AppLocalizations.of(context)!;
          return EmptyState(
            icon: Icons.restaurant_menu,
            message: l.emptyHomeMenusMessage,
            actionLabel: l.emptyHomeMenusAction,
            onAction: onEmptyAction,
          );
        }
        return Column(
          children: menus
              .map(
                (menu) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MenuCard(
                    menu: menu,
                    onTap: () => context.go(AppRoutes.menuManageFor(menu.id)),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink, fontSize: 14)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }
}

