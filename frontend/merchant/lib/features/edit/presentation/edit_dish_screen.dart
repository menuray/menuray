import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EditDishScreen extends StatefulWidget {
  const EditDishScreen({super.key, required this.dishId});

  final String dishId;

  @override
  State<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends State<EditDishScreen> {
  // Controllers – initialised in initState, disposed in dispose
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _enCtrl;

  // Spice level: 0=不辣, 1=微辣, 2=中辣, 3=重辣, 4=特辣
  int _spice = 2; // 中辣

  // Tag chips
  bool _isSignature = true;
  bool _isRecommended = true;
  bool _isVegetarian = false;

  // Allergen chips
  bool _hasPeanut = true;
  bool _hasDairy = false;
  bool _hasSeafood = false;
  bool _hasGluten = false;
  bool _hasEgg = false;

  @override
  void initState() {
    super.initState();
    final dish = MockData.hotDishes.dishes[0]; // 宫保鸡丁
    _nameCtrl = TextEditingController(text: dish.name);
    _priceCtrl = TextEditingController(text: dish.price.toInt().toString());
    _descCtrl = TextEditingController(text: dish.description ?? '');
    _enCtrl = TextEditingController(text: dish.nameEn ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  void _cancel() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.organize);
    }
  }

  void _save() => context.go(AppRoutes.organize);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: TextButton(
          onPressed: _cancel,
          child: Text(
            '取消',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        centerTitle: true,
        title: const Text('编辑菜品'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
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
              hasPeanut: _hasPeanut,
              onPeanutChanged: (v) => setState(() => _hasPeanut = v),
              hasDairy: _hasDairy,
              onDairyChanged: (v) => setState(() => _hasDairy = v),
              hasSeafood: _hasSeafood,
              onSeafoodChanged: (v) => setState(() => _hasSeafood = v),
              hasGluten: _hasGluten,
              onGlutenChanged: (v) => setState(() => _hasGluten = v),
              hasEgg: _hasEgg,
              onEggChanged: (v) => setState(() => _hasEgg = v),
            ),
          ],
        ),
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
              label: '拍照',
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            _ImageActionButton(
              icon: Icons.photo_library_outlined,
              label: '相册',
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            _ImageActionButton(
              icon: Icons.auto_awesome,
              label: 'AI 生成',
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormSection(
              label: '名称',
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: '菜品名称'),
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              label: '价格',
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
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _FormSection(
          label: '描述',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '请描述菜品特点…'),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.auto_awesome, size: 14, color: cs.tertiary),
                  label: Text(
                    'AI 扩写',
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
                _SectionLabel('本地化'),
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.translate, size: 16, color: cs.primary),
                  label: Text(
                    '一键翻译',
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
              lang: '中文',
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
              lang: 'EN',
              child: TextField(
                controller: enCtrl,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'English name',
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
              label: '标签',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('招牌'),
                    selected: isSignature,
                    onSelected: onSignatureChanged,
                  ),
                  FilterChip(
                    label: const Text('推荐'),
                    selected: isRecommended,
                    onSelected: onRecommendedChanged,
                  ),
                  FilterChip(
                    label: const Text('素食'),
                    selected: isVegetarian,
                    onSelected: onVegetarianChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: '过敏原',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('花生'),
                    selected: hasPeanut,
                    onSelected: onPeanutChanged,
                  ),
                  FilterChip(
                    label: const Text('乳制品'),
                    selected: hasDairy,
                    onSelected: onDairyChanged,
                  ),
                  FilterChip(
                    label: const Text('海鲜'),
                    selected: hasSeafood,
                    onSelected: onSeafoodChanged,
                  ),
                  FilterChip(
                    label: const Text('麸质'),
                    selected: hasGluten,
                    onSelected: onGlutenChanged,
                  ),
                  FilterChip(
                    label: const Text('鸡蛋'),
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

  static const _labels = ['不辣', '微辣', '中辣', '重辣', '特辣'];

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      label: '辣度',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: _SpiceSegment(
                    index: i,
                    selectedIndex: selectedIndex,
                    label: _labels[i],
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
