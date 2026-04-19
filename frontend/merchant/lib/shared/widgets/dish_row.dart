import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../../theme/app_colors.dart';

class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.dish, this.onTap});

  final Dish dish;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lowConfidence = dish.confidence == DishConfidence.low;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: lowConfidence ? AppColors.accent : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: Text(dish.name, style: const TextStyle(fontSize: 16))),
          if (dish.imageUrl != null) const _MiniIcon(Icons.image),
          if (dish.nameEn != null) const _MiniIcon(Icons.translate),
          Text('¥${dish.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (lowConfidence) ...[
            const SizedBox(width: 8),
            const Icon(Icons.help_outline, size: 18, color: AppColors.accent),
          ],
        ]),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(icon, size: 16, color: AppColors.secondary),
      );
}
