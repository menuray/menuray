import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, required this.actionLabel, required this.onAction, this.icon});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.restaurant, size: 96, color: AppColors.divider),
            const SizedBox(height: 24),
            Text(message, style: const TextStyle(fontSize: 16, color: AppColors.secondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryButton(label: actionLabel, onPressed: onAction, fullWidth: false),
          ],
        ),
      ),
    );
  }
}
