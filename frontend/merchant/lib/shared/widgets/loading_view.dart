import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Centered progress indicator with an optional label below.
/// Use inside AsyncValue.when's loading branch for consistency.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
