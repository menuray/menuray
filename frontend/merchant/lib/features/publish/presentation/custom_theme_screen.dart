import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kPrimaryColors = [
  AppColors.primary,          // 墨绿 (selected by default)
  AppColors.accent,           // 琥珀金
  Colors.blue,
  Colors.purple,
  Colors.red,
  Colors.orange,
  Colors.teal,
  Colors.pink,
];

const _kAccentColors = [
  AppColors.accent,           // 琥珀 (selected by default)
  AppColors.primary,          // 墨绿
  Colors.blue,
  Colors.purple,
  Colors.red,
  Colors.orange,
  Colors.teal,
  Colors.pink,
];

List<String> _fontLabels(AppLocalizations l) => [
      l.customThemeFontModern,
      l.customThemeFontSerif,
      l.customThemeFontHandwritten,
      l.customThemeFontRounded,
    ];

List<String> _radiusLabels(AppLocalizations l) => [
      l.customThemeRadiusSquare,
      l.customThemeRadiusSoft,
      l.customThemeRadiusRound,
    ];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  int _primaryIdx = 0;
  int _accentIdx = 0;
  int _fontIdx = 0;    // 现代黑体
  int _radiusIdx = 1;  // 微圆

  void _onSave() => context.go(AppRoutes.preview);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.selectTemplate),
        ),
        title: Text(l.customThemeTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Live preview ──────────────────────────────────────────────
            _PhoneMock(primaryColor: _kPrimaryColors[_primaryIdx]),
            // ── Controls ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    _SectionCard(
                      child: _LogoSection(),
                    ),
                    const SizedBox(height: 12),
                    // Colors
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ColorRow(
                            label: l.customThemeColorPrimary,
                            colors: _kPrimaryColors,
                            selectedIndex: _primaryIdx,
                            onSelected: (i) => setState(() => _primaryIdx = i),
                          ),
                          const SizedBox(height: 20),
                          _ColorRow(
                            label: l.customThemeColorAccent,
                            colors: _kAccentColors,
                            selectedIndex: _accentIdx,
                            onSelected: (i) => setState(() => _accentIdx = i),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Font & Radius
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChipRow(
                            label: l.customThemeFontLabel,
                            options: _fontLabels(l),
                            selectedIndex: _fontIdx,
                            onSelected: (i) => setState(() => _fontIdx = i),
                          ),
                          const SizedBox(height: 20),
                          _ChipRow(
                            label: l.customThemeRadiusLabel,
                            options: _radiusLabels(l),
                            selectedIndex: _radiusIdx,
                            onSelected: (i) => setState(() => _radiusIdx = i),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // ── CTA ───────────────────────────────────────────────────────
            _BottomCta(onPressed: _onSave),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone mock (live preview)
// ---------------------------------------------------------------------------

class _PhoneMock extends StatelessWidget {
  const _PhoneMock({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E2DB), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          children: [
            // Store header band
            Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.restaurant, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.customThemePreviewStoreName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.customThemePreviewStoreSubtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Fake dish cards
            Expanded(
              child: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return Container(
                    color: const Color(0xFFF7F3EC),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _FakeDishCard(
                          primaryColor: primaryColor,
                          name: l.customThemePreviewDishBraised,
                          price: '¥48',
                        ),
                        const SizedBox(width: 8),
                        _FakeDishCard(
                          primaryColor: primaryColor,
                          name: l.customThemePreviewDishSteamed,
                          price: '¥68',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeDishCard extends StatelessWidget {
  const _FakeDishCard({
    required this.primaryColor,
    required this.name,
    required this.price,
  });

  final Color primaryColor;
  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E2DB),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(price, style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card container
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Logo upload section
// ---------------------------------------------------------------------------

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l.customThemeLogoLabel,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C18)),
        ),
        const Spacer(),
        // Avatar placeholder
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFE6E2DB),
          child: Icon(Icons.store, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 8),
        Text(
          l.customThemeLogoUploaded,
          style: const TextStyle(fontSize: 12, color: Color(0xFF404945)),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l.customThemeLogoReplace, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Color swatch row
// ---------------------------------------------------------------------------

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C18)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...List.generate(colors.length, (i) {
              final selected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? colors[i].withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: selected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
            // "+" custom color button
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE8E1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC0C8C4), width: 1),
                ),
                child: const Icon(Icons.add, color: Color(0xFF404945), size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chip row (font / radius)
// ---------------------------------------------------------------------------

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C18)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(options.length, (i) {
            final selected = i == selectedIndex;
            return GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFEBE8E1),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF404945),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
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
        label: AppLocalizations.of(context)!.customThemeCta,
        onPressed: onPressed,
      ),
    );
  }
}
