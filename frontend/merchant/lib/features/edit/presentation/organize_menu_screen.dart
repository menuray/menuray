import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/dish.dart';
import '../../../shared/widgets/dish_row.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../home/home_providers.dart';
import '../../manage/menu_management_provider.dart';

class OrganizeMenuScreen extends ConsumerStatefulWidget {
  const OrganizeMenuScreen({super.key, required this.menuId});

  final String menuId;

  @override
  ConsumerState<OrganizeMenuScreen> createState() =>
      _OrganizeMenuScreenState();
}

class _OrganizeMenuScreenState extends ConsumerState<OrganizeMenuScreen> {
  // categoryId → optimistic ordered dish-list. Cleared after successful
  // write + invalidate.
  final Map<String, List<Dish>> _optimisticOrder = {};

  Future<void> _reorder(DishCategory cat, int oldIndex, int newIndex) async {
    final current =
        List<Dish>.from(_optimisticOrder[cat.id] ?? cat.dishes);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    setState(() => _optimisticOrder[cat.id] = current);

    final pairs = <({String dishId, int position})>[
      for (var i = 0; i < current.length; i++)
        (dishId: current[i].id, position: i),
    ];
    try {
      await ref.read(menuRepositoryProvider).reorderDishes(pairs);
      ref.invalidate(menuByIdProvider(widget.menuId));
      if (mounted) setState(() => _optimisticOrder.remove(cat.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimisticOrder.remove(cat.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.organizeReorderFailed('$e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(menuByIdProvider(widget.menuId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(l.organizeTitle),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.previewFor(widget.menuId)),
            child: Text(l.commonNext),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(label: l.loadingDefault),
        error: (e, _) => ErrorView(
          message: l.errorGenericMessage,
          retryLabel: l.errorRetry,
          onRetry: () => ref.invalidate(menuByIdProvider(widget.menuId)),
        ),
        data: (menu) {
          final cats = menu.categories;
          if (cats.isEmpty) {
            return Center(
              child: Text(l.organizeEmpty, style: const TextStyle(color: Colors.grey)),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              for (final cat in cats) ...[
                _CategoryHeader(category: cat),
                _CategoryDishList(
                  category: cat,
                  dishes: _optimisticOrder[cat.id] ?? cat.dishes,
                  onReorder: (o, n) => _reorder(cat, o, n),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        icon: const Icon(Icons.add),
        label: Text(l.organizeFabAdd),
      ),
    );
  }
}

class _CategoryDishList extends StatelessWidget {
  const _CategoryDishList({
    required this.category,
    required this.dishes,
    required this.onReorder,
  });

  final DishCategory category;
  final List<Dish> dishes;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: true,
      onReorder: onReorder,
      itemCount: dishes.length,
      itemBuilder: (ctx, i) {
        final d = dishes[i];
        return DishRow(
          key: ValueKey('${category.id}-${d.id}'),
          dish: d,
          onTap: () => context.go(AppRoutes.editDishFor(d.id)),
        );
      },
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
              AppLocalizations.of(context)!.organizeCategoryCount(category.dishes.length),
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

