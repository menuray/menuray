import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'primary_button.dart';

/// Centered error icon, message, and optional retry button.
/// Visual style matches EmptyState (padding 32, icon 96, 16px gaps).
/// Callers pass localized strings — widget imports no AppLocalizations.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 96, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: retryLabel ?? 'Retry',
                onPressed: onRetry!,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
