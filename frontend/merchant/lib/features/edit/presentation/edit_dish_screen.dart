import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/dish.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../edit_providers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EditDishScreen extends ConsumerStatefulWidget {
  const EditDishScreen({super.key, required this.dishId});

  final String dishId;

  @override
  ConsumerState<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends ConsumerState<EditDishScreen> {
  // Controllers – populated lazily from the first dish fetch via _hydrate().
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _enCtrl = TextEditingController();

  bool _controllersPopulated = false;
  String? _menuIdForNav; // captured after first fetch for Cancel/Save routing
  bool _menuIdFetchStarted = false;

  // Spice level: 0=不辣, 1=微辣, 2=中辣, 3=重辣
  int _spice = 0;

  // Tag chips
  bool _isSignature = false;
  bool _isRecommended = false;
  bool _isVegetarian = false;

  // Allergens — set of codes (peanut/dairy/seafood/gluten/egg)
  final Set<String> _allergens = {};

  bool _saving = false;

  // Wire spice index (0..3) ↔ DB enum string ('none' | 'mild' | 'medium' | 'hot').
  static const List<String> _spiceEnum = ['none', 'mild', 'medium', 'hot'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Dish d) {
    if (_controllersPopulated) return;
    _nameCtrl.text = d.name;
    _priceCtrl.text = d.price.toStringAsFixed(0);
    _descCtrl.text = d.description ?? '';
    _enCtrl.text = d.nameEn ?? '';
    _spice = SpiceLevel.values.indexOf(d.spice);
    _isSignature = d.isSignature;
    _isRecommended = d.isRecommended;
    _isVegetarian = d.isVegetarian;
    _allergens
      ..clear()
      ..addAll(d.allergens);
    _controllersPopulated = true;
  }

  void _maybeFetchMenuId() {
    if (_menuIdForNav != null || _menuIdFetchStarted) return;
    _menuIdFetchStarted = true;
    ref
        .read(dishRepositoryProvider)
        .fetchMenuIdForDish(widget.dishId)
        .then((id) {
      if (!mounted) return;
      setState(() => _menuIdForNav = id);
    }).catchError((_) {
      // Ignore — falls back to AppRoutes.home in _navBack.
    });
  }

  void _navBack() {
    if (_menuIdForNav != null) {
      context.go(AppRoutes.organizeFor(_menuIdForNav!));
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(dishRepositoryProvider);
      final store = await ref.read(currentStoreProvider.future);
      await repo.updateDish(
        dishId: widget.dishId,
        sourceName: _nameCtrl.text.trim(),
        sourceDescription:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        spiceLevel: _spiceEnum[_spice],
        isSignature: _isSignature,
        isRecommended: _isRecommended,
        isVegetarian: _isVegetarian,
        allergens: _allergens.toList(growable: false),
      );
      final en = _enCtrl.text.trim();
      if (en.isNotEmpty) {
        await repo.upsertEnTranslation(
          dishId: widget.dishId,
          storeId: store.id,
          name: en,
        );
      }
      ref.invalidate(dishByIdProvider(widget.dishId));
      if (!mounted) return;
      _navBack();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.editDishSaveFailed('$e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dishByIdProvider(widget.dishId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: _ErrorBody(
          message: AppLocalizations.of(context)!.editDishLoadFailed('$err'),
          onRetry: () => ref.invalidate(dishByIdProvider(widget.dishId)),
        ),
      ),
      data: (dish) {
        _hydrate(dish);
        _maybeFetchMenuId();
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: TextButton(
          onPressed: _saving ? null : _navBack,
          child: Text(
            l.commonCancel,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        centerTitle: true,
        title: Text(l.editDishTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? l.editDishSaving : l.commonSave,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DishImageSection(),
            const SizedBox(height: 20),
            _BasicInfoSection(nameCtrl: _nameCtrl, priceCtrl: _priceCtrl),
            const SizedBox(height: 20),
            _DescriptionSection(descCtrl: _descCtrl),
            const SizedBox(height: 20),
            _TranslationCard(nameCtrl: _nameCtrl, enCtrl: _enCtrl),
            const SizedBox(height: 20),
            _TagsAndDetailsSection(
              spice: _spice,
              onSpiceChanged: (v) => setState(() => _spice = v),
              isSignature: _isSignature,
              onSignatureChanged: (v) => setState(() => _isSignature = v),
              isRecommended: _isRecommended,
              onRecommendedChanged: (v) => setState(() => _isRecommended = v),
              isVegetarian: _isVegetarian,
              onVegetarianChanged: (v) => setState(() => _isVegetarian = v),
              hasPeanut: _allergens.contains('peanut'),
              onPeanutChanged: (v) => setState(() {
                v ? _allergens.add('peanut') : _allergens.remove('peanut');
              }),
              hasDairy: _allergens.contains('dairy'),
              onDairyChanged: (v) => setState(() {
                v ? _allergens.add('dairy') : _allergens.remove('dairy');
              }),
              hasSeafood: _allergens.contains('seafood'),
              onSeafoodChanged: (v) => setState(() {
                v ? _allergens.add('seafood') : _allergens.remove('seafood');
              }),
              hasGluten: _allergens.contains('gluten'),
              onGlutenChanged: (v) => setState(() {
                v ? _allergens.add('gluten') : _allergens.remove('gluten');
              }),
              hasEgg: _allergens.contains('egg'),
              onEggChanged: (v) => setState(() {
                v ? _allergens.add('egg') : _allergens.remove('egg');
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body (mirrors menu_management_screen._ErrorBody)
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
          ),
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

// ---------------------------------------------------------------------------
// Dish image section
// ---------------------------------------------------------------------------

class _DishImageSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/sample/dish_kungpao.png',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context2, err, stack) => Container(
              height: 200,
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.restaurant, size: 64, color: cs.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ImageActionButton(
              icon: Icons.photo_camera_outlined,
              label: l.editDishPhotoCamera,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            _ImageActionButton(
              icon: Icons.photo_library_outlined,
              label: l.editDishPhotoGallery,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            _ImageActionButton(
              icon: Icons.auto_awesome,
              label: l.editDishPhotoAiGenerate,
              onPressed: () {},
              highlighted: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (highlighted) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: cs.tertiary),
        label: Text(label, style: TextStyle(color: cs.tertiary, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.tertiary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Basic info (name + price)
// ---------------------------------------------------------------------------

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({
    required this.nameCtrl,
    required this.priceCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormSection(
              label: l.editDishFieldName,
              child: TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: l.editDishFieldNameHint),
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              label: l.editDishFieldPrice,
              child: TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixText: '¥ ',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Description
// ---------------------------------------------------------------------------

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.descCtrl});

  final TextEditingController descCtrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _FormSection(
          label: l.editDishFieldDescription,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(hintText: l.editDishFieldDescriptionHint),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.auto_awesome, size: 14, color: cs.tertiary),
                  label: Text(
                    l.editDishAiExpand,
                    style: TextStyle(fontSize: 12, color: cs.tertiary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Translation card
// ---------------------------------------------------------------------------

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.nameCtrl,
    required this.enCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController enCtrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(l.editDishLocalizationSection),
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.translate, size: 16, color: cs.primary),
                  label: Text(
                    l.editDishTranslateAll,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ZH row – read-only, shows current name field value
            _LangRow(
              lang: l.editDishLangChinese,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: nameCtrl,
                builder: (context2, value, _) => Text(
                  value.text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // EN row – editable
            _LangRow(
              lang: l.editDishLangEnglish,
              child: TextField(
                controller: enCtrl,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: l.editDishEnNameHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({required this.lang, required this.child});

  final String lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            lang,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags & details section (spice, tags, allergens)
// ---------------------------------------------------------------------------

class _TagsAndDetailsSection extends StatelessWidget {
  const _TagsAndDetailsSection({
    required this.spice,
    required this.onSpiceChanged,
    required this.isSignature,
    required this.onSignatureChanged,
    required this.isRecommended,
    required this.onRecommendedChanged,
    required this.isVegetarian,
    required this.onVegetarianChanged,
    required this.hasPeanut,
    required this.onPeanutChanged,
    required this.hasDairy,
    required this.onDairyChanged,
    required this.hasSeafood,
    required this.onSeafoodChanged,
    required this.hasGluten,
    required this.onGlutenChanged,
    required this.hasEgg,
    required this.onEggChanged,
  });

  final int spice;
  final ValueChanged<int> onSpiceChanged;
  final bool isSignature;
  final ValueChanged<bool> onSignatureChanged;
  final bool isRecommended;
  final ValueChanged<bool> onRecommendedChanged;
  final bool isVegetarian;
  final ValueChanged<bool> onVegetarianChanged;
  final bool hasPeanut;
  final ValueChanged<bool> onPeanutChanged;
  final bool hasDairy;
  final ValueChanged<bool> onDairyChanged;
  final bool hasSeafood;
  final ValueChanged<bool> onSeafoodChanged;
  final bool hasGluten;
  final ValueChanged<bool> onGlutenChanged;
  final bool hasEgg;
  final ValueChanged<bool> onEggChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpiceLevelSection(
              selectedIndex: spice,
              onChanged: onSpiceChanged,
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: l.editDishTagsLabel,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: Text(l.editDishTagSignature),
                    selected: isSignature,
                    onSelected: onSignatureChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishTagRecommended),
                    selected: isRecommended,
                    onSelected: onRecommendedChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishTagVegetarian),
                    selected: isVegetarian,
                    onSelected: onVegetarianChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: l.editDishAllergensLabel,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: Text(l.editDishAllergenPeanut),
                    selected: hasPeanut,
                    onSelected: onPeanutChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishAllergenDairy),
                    selected: hasDairy,
                    onSelected: onDairyChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishAllergenSeafood),
                    selected: hasSeafood,
                    onSelected: onSeafoodChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishAllergenGluten),
                    selected: hasGluten,
                    onSelected: onGlutenChanged,
                  ),
                  FilterChip(
                    label: Text(l.editDishAllergenEgg),
                    selected: hasEgg,
                    onSelected: onEggChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spice level selector
// ---------------------------------------------------------------------------

class _SpiceLevelSection extends StatelessWidget {
  const _SpiceLevelSection({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  // 4 segments matching SpiceLevel enum (none, mild, medium, hot). Pulled
  // via AppLocalizations so the labels translate.
  List<String> _labels(AppLocalizations l) => [
        l.editDishSpiceNone,
        l.editDishSpiceMild,
        l.editDishSpiceMedium,
        l.editDishSpiceHot,
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = _labels(l);
    return _FormSection(
      label: l.editDishSpiceLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: _SpiceSegment(
                    index: i,
                    selectedIndex: selectedIndex,
                    label: labels[i],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SpiceSegment extends StatelessWidget {
  const _SpiceSegment({
    required this.index,
    required this.selectedIndex,
    required this.label,
  });

  final int index;
  final int selectedIndex;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 32,
            decoration: BoxDecoration(
              color: isSelected ? cs.error : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? cs.onError : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _FormSection extends StatelessWidget {
  const _FormSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}
