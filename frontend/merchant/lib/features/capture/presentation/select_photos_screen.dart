import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

// Hardcoded selected photo indices (0-indexed within the 12-item grid)
const List<int> _selectedIndices = [0, 3, 6];

// Sample assets rotated through the 5 available images
const List<String> _sampleAssets = [
  'assets/sample/menu_lunch.png',
  'assets/sample/menu_dinner.png',
  'assets/sample/dish_kungpao.png',
  'assets/sample/dish_mapo.png',
  'assets/sample/store_avatar.png',
];

class SelectPhotosScreen extends StatelessWidget {
  const SelectPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text(
            '取消',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leadingWidth: 72,
        title: Text(
          '选择菜单图片',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _NextButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: const Column(
        children: [
          // Photo grid
          Expanded(child: _PhotoGrid()),
          // Bottom selected strip
          _SelectedStrip(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "下一步 (3)" action button — enabled since 3 photos selected
// ─────────────────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(AppRoutes.correctImage),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const StadiumBorder(),
      ),
      child: const Text(
        '下一步 (3)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo grid — 4 columns, 12 photos with selection badges
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final assetPath = _sampleAssets[index % _sampleAssets.length];
        final selectionOrder = _selectedIndices.indexOf(index);
        final isSelected = selectionOrder != -1;
        return _PhotoTile(
          assetPath: assetPath,
          selectionOrder: isSelected ? selectionOrder + 1 : null,
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.assetPath,
    required this.selectionOrder,
  });

  final String assetPath;
  final int? selectionOrder; // null = unselected; 1/2/3 = badge number

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionOrder != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, err, stack) => Container(
              color: const Color(0xFFE6E2DB),
              child: const Icon(Icons.image, color: Colors.white54),
            ),
          ),
        ),
        // Selection overlay tint
        if (isSelected)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              color: AppColors.primary.withAlpha(26), // ~10%
            ),
          ),
        // Selection badge
        if (isSelected)
          Positioned(
            top: 4,
            right: 4,
            child: _SelectionBadge(number: selectionOrder!),
          ),
      ],
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom selected strip — horizontal list of 3 selected thumbnails
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedStrip extends StatelessWidget {
  const _SelectedStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F3EC), // surface-container-low
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '拖动可调整顺序',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedIndices.length,
              separatorBuilder: (context, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final assetIndex = _selectedIndices[index];
                final assetPath = _sampleAssets[assetIndex % _sampleAssets.length];
                return _StripThumbnail(assetPath: assetPath);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StripThumbnail extends StatelessWidget {
  const _StripThumbnail({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Thumbnail image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, err, stack) => Container(
                color: const Color(0xFFE6E2DB),
                child: const Icon(Icons.image, color: Colors.white54),
              ),
            ),
          ),
        ),
        // Drag handle indicator at the bottom center
        Positioned(
          bottom: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153), // 60%
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Icon(
                Icons.drag_indicator,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
