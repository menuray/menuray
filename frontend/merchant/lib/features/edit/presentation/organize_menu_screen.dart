import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/models/category.dart';
import '../../../shared/widgets/dish_row.dart';

class OrganizeMenuScreen extends StatelessWidget {
  const OrganizeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = MockData.lunchMenu.categories;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.processing),
        ),
        title: const Text('整理菜单'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.selectTemplate),
            child: const Text('下一步'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          for (final category in categories) ...[
            _CategorySection(
              category: category,
              onDishTap: () => context.go(AppRoutes.editDish),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.onDishTap,
  });

  final DishCategory category;
  final VoidCallback onDishTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(category: category),
        for (final dish in category.dishes)
          DishRow(dish: dish, onTap: onDishTap),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final DishCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            category.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${category.dishes.length} 项',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
