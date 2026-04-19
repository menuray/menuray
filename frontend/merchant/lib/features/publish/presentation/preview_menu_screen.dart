import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/models/dish.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen (StatefulWidget for segment toggles)
// ---------------------------------------------------------------------------

class PreviewMenuScreen extends StatefulWidget {
  const PreviewMenuScreen({super.key});

  @override
  State<PreviewMenuScreen> createState() => _PreviewMenuScreenState();
}

class _PreviewMenuScreenState extends State<PreviewMenuScreen> {
  /// 0 = 手机, 1 = 平板
  int _deviceIdx = 0;

  /// 0 = 中文, 1 = EN
  int _langIdx = 0;

  void _onPublish() => context.go(AppRoutes.published);
  void _onBack() => context.go(AppRoutes.customTheme);
  void _onReturnEdit() => context.go(AppRoutes.organize);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.primaryDark,
          onPressed: _onBack,
        ),
        title: const Text(
          '预览',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onPublish,
            child: const Text(
              '发布',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFECE7DC)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Segment controls ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SegmentControl(
                    options: const ['手机', '平板'],
                    icons: const [Icons.smartphone, Icons.tablet_mac],
                    selectedIndex: _deviceIdx,
                    onSelected: (i) => setState(() => _deviceIdx = i),
                  ),
                  _SegmentControl(
                    options: const ['中文', 'EN'],
                    selectedIndex: _langIdx,
                    onSelected: (i) => setState(() => _langIdx = i),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Phone mock frame ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: _PhoneMockFrame(showEnglish: _langIdx == 1),
                ),
              ),
            ),
            // ── Bottom action bar ─────────────────────────────────────────
            _BottomActionBar(
              onReturnEdit: _onReturnEdit,
              onPublish: _onPublish,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segment control widget
// ---------------------------------------------------------------------------

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
  });

  final List<String> options;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBE8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icons != null) ...[
                    Icon(
                      icons![i],
                      size: 16,
                      color: selected ? AppColors.primaryDark : const Color(0xFF404945),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.primaryDark : const Color(0xFF404945),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone mock frame containing a fake menu page
// ---------------------------------------------------------------------------

class _PhoneMockFrame extends StatelessWidget {
  const _PhoneMockFrame({required this.showEnglish});

  final bool showEnglish;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 620,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: const Color(0xFF2C2C28), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: _FakeMenuPage(showEnglish: showEnglish),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fake menu page rendered inside the phone frame
// ---------------------------------------------------------------------------

class _FakeMenuPage extends StatelessWidget {
  const _FakeMenuPage({required this.showEnglish});

  final bool showEnglish;

  @override
  Widget build(BuildContext context) {
    final dishes = MockData.hotDishes.dishes;

    return Container(
      color: const Color(0xFFFDF9F2),
      child: Column(
        children: [
          // Fake status bar
          const _FakeStatusBar(),
          // Store header
          _FakeStoreHeader(showEnglish: showEnglish),
          // Category nav strip
          _FakeCategoryNav(showEnglish: showEnglish),
          // Dish cards list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 60),
              itemCount: dishes.length,
              itemBuilder: (_, i) => _FakeDishCard(
                dish: dishes[i],
                showEnglish: showEnglish,
              ),
            ),
          ),
          // Footer
          const _FakeFooter(),
        ],
      ),
    );
  }
}

// Fake status bar (9:41 + icons)
class _FakeStatusBar extends StatelessWidget {
  const _FakeStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: const Color(0xFF1C1C18),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 12),
              SizedBox(width: 3),
              Icon(Icons.wifi, color: Colors.white, size: 12),
              SizedBox(width: 3),
              Icon(Icons.battery_full, color: Colors.white, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// Store header with gradient + name + logo placeholder
class _FakeStoreHeader extends StatelessWidget {
  const _FakeStoreHeader({required this.showEnglish});

  final bool showEnglish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C18), Color(0x99000000)],
        ),
        color: Color(0xFF154539),
      ),
      child: Stack(
        children: [
          // Background colour
          Container(color: AppColors.primaryDark),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '云间小厨',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showEnglish
                            ? 'Sichuan · 11:00 - 22:00'
                            : '川菜 · 11:00 - 22:00',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Logo placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Category nav strip
class _FakeCategoryNav extends StatelessWidget {
  const _FakeCategoryNav({required this.showEnglish});

  final bool showEnglish;

  @override
  Widget build(BuildContext context) {
    final categories = showEnglish
        ? const ['Cold', 'Hot', 'Staple', 'Soup', 'Drink']
        : const ['凉菜', '热菜', '主食', '汤品', '饮品'];

    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECE7DC))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final selected = i == 1; // 热菜 selected by default
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Text(
                categories[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppColors.primaryDark : const Color(0xFF717975),
                  decoration: selected
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: AppColors.primaryDark,
                  decorationThickness: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Individual dish card inside the phone mock
class _FakeDishCard extends StatelessWidget {
  const _FakeDishCard({required this.dish, required this.showEnglish});

  final Dish dish;
  final bool showEnglish;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Stack(
            children: [
              Container(
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6E2DB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.restaurant_menu, color: Color(0xFF404945), size: 28),
                ),
              ),
              // Tags
              if (dish.isSignature)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF754C14).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      showEnglish ? "Chef's Special" : '招牌',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (dish.spice == SpiceLevel.hot)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA1A1A).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.white, size: 9),
                        const SizedBox(width: 2),
                        Text(
                          showEnglish ? 'Spicy' : '辣',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showEnglish && dish.nameEn != null ? dish.nameEn! : dish.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C18),
                  ),
                ),
                if (!showEnglish && dish.nameEn != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    dish.nameEn!,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF717975)),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '¥${dish.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Footer inside the phone frame
class _FakeFooter extends StatelessWidget {
  const _FakeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFFF7F3EC),
      child: const Text(
        '由 MenuRay 提供',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: Color(0xFF717975),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar (merchant controls)
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.onReturnEdit,
    required this.onPublish,
  });

  final VoidCallback onReturnEdit;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFFECE7DC))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回编辑 secondary button
          Expanded(
            child: OutlinedButton(
              onPressed: onReturnEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                backgroundColor: const Color(0xFFF1EDE6),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '返回编辑',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 发布菜单 primary button
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                onPressed: onPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '发布菜单',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
