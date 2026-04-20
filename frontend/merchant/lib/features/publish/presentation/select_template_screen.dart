import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _TemplateData {
  const _TemplateData({
    required this.name,
    required this.style,
    required this.category,
    required this.thumbnailColor,
    this.styleIsPrimary = true,
  });

  final String name;
  final String style;
  final String category;
  final Color thumbnailColor;
  /// If true, style badge uses primary color; otherwise uses accent (tertiary).
  final bool styleIsPrimary;
}

List<_TemplateData> _templates(AppLocalizations l) => [
      _TemplateData(
        name: l.selectTemplateNameModern,
        style: l.selectTemplateStyleModern,
        category: l.selectTemplateCategoryChinese,
        thumbnailColor: AppColors.primary,
        styleIsPrimary: true,
      ),
      _TemplateData(
        name: l.selectTemplateNameWarmGlow,
        style: l.selectTemplateStyleClassic,
        category: l.selectTemplateCategoryWestern,
        thumbnailColor: AppColors.accent,
        styleIsPrimary: false,
      ),
      _TemplateData(
        name: l.selectTemplateNameMinimalWhite,
        style: l.selectTemplateStyleModern,
        category: l.selectTemplateCategoryCasual,
        thumbnailColor: AppColors.secondary,
        styleIsPrimary: true,
      ),
      _TemplateData(
        name: l.selectTemplateNameWafu,
        style: l.selectTemplateStyleClassic,
        category: l.selectTemplateCategoryJpKr,
        thumbnailColor: AppColors.surface,
        styleIsPrimary: false,
      ),
    ];

List<String> _tabs(AppLocalizations l) => [
      l.selectTemplateTabAll,
      l.selectTemplateTabChinese,
      l.selectTemplateTabWestern,
      l.selectTemplateTabJpKr,
      l.selectTemplateTabCasual,
      l.selectTemplateTabCafe,
    ];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SelectTemplateScreen extends StatefulWidget {
  const SelectTemplateScreen({super.key});

  @override
  State<SelectTemplateScreen> createState() => _SelectTemplateScreenState();
}

class _SelectTemplateScreenState extends State<SelectTemplateScreen> {
  int _selectedTab = 0;
  int _selectedTemplate = 0;

  void _onUseTemplate() => context.go(AppRoutes.customTheme);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tabs = _tabs(l);
    final templates = _templates(l);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.organize),
        ),
        title: Text(l.selectTemplateTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TabBar(
              tabs: tabs,
              selectedIndex: _selectedTab,
              onTabSelected: (i) => setState(() => _selectedTab = i),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
                children: List.generate(templates.length, (i) {
                  return _TemplateCard(
                    data: templates[i],
                    selected: _selectedTemplate == i,
                    onTap: () => setState(() => _selectedTemplate = i),
                  );
                }),
              ),
            ),
            _BottomCta(onPressed: _onUseTemplate),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tabs.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onTabSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : const Color(0xFFEBE8E1),
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF404945),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template card
// ---------------------------------------------------------------------------

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _TemplateData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.05),
              blurRadius: selected ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _Thumbnail(color: data.thumbnailColor),
                    if (selected) const _SelectedBadge(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _CardFooter(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 15),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.data});

  final _TemplateData data;

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        data.styleIsPrimary ? AppColors.primary : const Color(0xFF5A3500);
    final badgeBg = data.styleIsPrimary
        ? AppColors.primary.withValues(alpha: 0.10)
        : const Color(0xFF5A3500).withValues(alpha: 0.10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C18),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.style,
                  style: TextStyle(
                    fontSize: 11,
                    color: badgeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.category,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF404945),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom CTA
// ---------------------------------------------------------------------------

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.95),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: PrimaryButton(
        label: AppLocalizations.of(context)!.selectTemplateUse,
        onPressed: onPressed,
      ),
    );
  }
}
