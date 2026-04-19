import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum ChipVariant { published, draft, signature, recommended, spicy, soldOut }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.variant});

  final String label;
  final ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      ChipVariant.published => (AppColors.primary.withValues(alpha: 0.1), AppColors.primary),
      ChipVariant.draft => (AppColors.divider, AppColors.secondary),
      ChipVariant.signature => (AppColors.accent.withValues(alpha: 0.2), AppColors.accent),
      ChipVariant.recommended => (AppColors.success.withValues(alpha: 0.15), AppColors.success),
      ChipVariant.spicy => (AppColors.error.withValues(alpha: 0.1), AppColors.error),
      ChipVariant.soldOut => (AppColors.error, Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
