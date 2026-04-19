import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/menu_card.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../shared/widgets/search_input.dart';
import '../../../theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _TopBar(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search ─────────────────────────────────────────────────
            const SearchInput(hintText: 'Search menus, items, or status...'),
            const SizedBox(height: 32),

            // ── Section header ─────────────────────────────────────────
            const _SectionHeader(title: 'Curated Menus', total: '3 Total'),
            const SizedBox(height: 16),

            // ── Menu cards ─────────────────────────────────────────────
            ...MockData.menus.map((menu) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MenuCard(
                    menu: menu,
                    onTap: () => context.go(AppRoutes.menuManage),
                  ),
                )),
          ],
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
              // no-op — already on menus tab; Task 31 will wire properly
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

// ─────────────────────────────────────────────────────────────────────────────
// Top App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withAlpha(204), // 80% opacity like Stitch
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              // ── Leading: search icon + store name ───────────────────
              Icon(Icons.search, color: AppColors.primaryDark),
              const SizedBox(width: 12),
              Text(
                '云间小厨',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // ── Trailing: circular store avatar ─────────────────────
              const _StoreAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Store avatar — circular, tap = no-op placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // placeholder — no-op for now
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

// ─────────────────────────────────────────────────────────────────────────────
// Section header: large title + right-aligned total count
// ─────────────────────────────────────────────────────────────────────────────

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
