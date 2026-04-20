import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/models/store.dart';
import '../../../shared/widgets/menu_card.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../shared/widgets/search_input.dart';
import '../../../theme/app_colors.dart';
import '../home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const SearchInput(hintText: 'Search menus, items, or status...'),
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'Curated Menus',
                total: menusAsync.maybeWhen(
                  data: (list) => '${list.length} Total',
                  orElse: () => '— Total',
                ),
              ),
              const SizedBox(height: 16),
              _MenuList(menusAsync: menusAsync),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.camera),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          '新建菜单',
          style: TextStyle(fontWeight: FontWeight.w700),
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
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.storeAsync});

  final AsyncValue<Store> storeAsync;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final name = storeAsync.maybeWhen(
      data: (s) => s.name,
      orElse: () => '加载中…',
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
  const _MenuList({required this.menusAsync});

  final AsyncValue<List<Menu>> menusAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return menusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _ErrorBlock(
        message: '加载失败：$err',
        onRetry: () => ref.invalidate(menusProvider),
      ),
      data: (menus) {
        if (menus.isEmpty) return const _EmptyBlock();
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
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.menu_book, color: AppColors.secondary, size: 40),
          const SizedBox(height: 12),
          Text('还没有菜单，点右下角"新建菜单"开始',
              style: TextStyle(color: AppColors.secondary, fontSize: 14)),
        ],
      ),
    );
  }
}
