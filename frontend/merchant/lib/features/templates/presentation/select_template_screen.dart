import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/templates/data/template_repository.dart';
import 'package:menuray_merchant/features/templates/primary_swatches.dart';
import 'package:menuray_merchant/features/templates/presentation/widgets/swatch_tile.dart';
import 'package:menuray_merchant/features/templates/presentation/widgets/template_card.dart';
import 'package:menuray_merchant/l10n/app_localizations.dart';
import 'package:menuray_merchant/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectTemplateScreen extends ConsumerStatefulWidget {
  const SelectTemplateScreen({super.key, required this.menuId});

  final String menuId;

  @override
  ConsumerState<SelectTemplateScreen> createState() =>
      _SelectTemplateScreenState();
}

class _SelectTemplateScreenState extends ConsumerState<SelectTemplateScreen> {
  String _templateId = 'minimal';
  String? _primaryColor; // null = reset/default
  bool _saving = false;
  bool _initialized = false;

  Future<void> _loadInitial() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('menus')
          .select('template_id, theme_overrides')
          .eq('id', widget.menuId)
          .maybeSingle();
      if (row == null || !mounted) return;
      final templateId = (row['template_id'] as String?) ?? 'minimal';
      final overrides = row['theme_overrides'] as Map<String, dynamic>?;
      final pc = overrides?['primary_color'] as String?;
      setState(() {
        _templateId = templateId;
        _primaryColor = pc;
      });
    } catch (_) {
      // Supabase may be unavailable (e.g., in tests); keep default state.
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ref.read(menuRepositoryProvider).updateMenu(
            menuId: widget.menuId,
            templateId: _templateId,
            themeOverrides: _primaryColor == null
                ? <String, dynamic>{}
                : {'primary_color': _primaryColor},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.appearanceSaveSuccess)));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.appearanceSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final templatesAsync = ref.watch(templateListProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());

    return Scaffold(
      appBar: AppBar(title: Text(l.appearanceTitle)),
      body: templatesAsync.when(
        data: (templates) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.templateSectionTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 3 / 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: templates
                  .map(
                    (t) => TemplateCard(
                      template: t,
                      isSelected: _templateId == t.id,
                      onTap: () => setState(() => _templateId = t.id),
                      comingSoonLabel: l.comingSoon,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            Text(
              l.colorSectionTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kPrimarySwatchHex
                  .map(
                    (hex) => SwatchTile(
                      hex: hex,
                      isSelected:
                          _primaryColor?.toLowerCase() == hex.toLowerCase(),
                      onTap: () => setState(() => _primaryColor = hex),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _primaryColor == null
                    ? null
                    : () => setState(() => _primaryColor = null),
                child: Text(l.resetToDefault),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l.appearanceSave),
            ),
            const SizedBox(height: 24),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.appearanceSaveFailed)),
      ),
    );
  }
}
