import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';

class AiOptimizeScreen extends StatefulWidget {
  const AiOptimizeScreen({super.key});

  @override
  State<AiOptimizeScreen> createState() => _AiOptimizeScreenState();
}

class _AiOptimizeScreenState extends State<AiOptimizeScreen> {
  bool _autoImage = true;
  bool _descExpand = true;
  bool _multiLang = true;
  int _selectedLangIdx = 0;

  List<String> _langOptions(AppLocalizations l) => [
        l.aiOptimizeLangEnglish,
        l.aiOptimizeLangJapanese,
        l.aiOptimizeLangKorean,
        l.aiOptimizeLangFrench,
      ];

  void _onStart() => context.go(AppRoutes.organize);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final langs = _langOptions(l);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.organize),
        ),
        title: Text(l.aiOptimizeTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _ToggleCard(
                    icon: Icons.image_outlined,
                    title: l.aiOptimizeAutoImageTitle,
                    subtitle: l.aiOptimizeAutoImageSubtitle,
                    value: _autoImage,
                    onChanged: (v) => setState(() => _autoImage = v),
                  ),
                  const SizedBox(height: 12),
                  _ToggleCard(
                    icon: Icons.edit_note,
                    title: l.aiOptimizeDescExpandTitle,
                    subtitle: l.aiOptimizeDescExpandSubtitle,
                    value: _descExpand,
                    onChanged: (v) => setState(() => _descExpand = v),
                  ),
                  const SizedBox(height: 12),
                  _TranslateCard(
                    value: _multiLang,
                    onChanged: (v) => setState(() => _multiLang = v),
                    selectedLang: langs[_selectedLangIdx],
                    langOptions: langs,
                    onLangChanged: (lang) {
                      if (lang == null) return;
                      final idx = langs.indexOf(lang);
                      if (idx >= 0) setState(() => _selectedLangIdx = idx);
                    },
                  ),
                  const SizedBox(height: 20),
                  const _EstimationBanner(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryButton(
                label: l.aiOptimizeCta,
                onPressed: _onStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslateCard extends StatelessWidget {
  const _TranslateCard({
    required this.value,
    required this.onChanged,
    required this.selectedLang,
    required this.langOptions,
    required this.onLangChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String selectedLang;
  final List<String> langOptions;
  final ValueChanged<String?> onLangChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(Icons.translate, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.aiOptimizeMultiLangTitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.aiOptimizeMultiLangSubtitle(selectedLang),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedLang,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              onChanged: onLangChanged,
              items: langOptions
                  .map(
                    (lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(lang),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimationBanner extends StatelessWidget {
  const _EstimationBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondaryContainer),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.schedule,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Builder(
              builder: (context) {
                final l = AppLocalizations.of(context)!;
                return RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                    children: [
                      TextSpan(text: l.aiOptimizeEstimatePrefix),
                      TextSpan(
                        text: l.aiOptimizeEstimateDuration,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(text: l.aiOptimizeEstimateMiddle),
                      TextSpan(
                        text: l.aiOptimizeEstimateCount,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
