import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/billing/billing_providers.dart';
import '../../features/billing/tier.dart';

/// Hides its child unless the active store's tier is in [allowed].
class TierGate extends ConsumerWidget {
  final Set<Tier> allowed;
  final Widget child;
  final Widget? fallback;
  const TierGate({
    required this.allowed,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(currentTierProvider);
    final tier = tierAsync.valueOrNull;
    final show = tier != null && allowed.contains(tier);
    return show ? child : (fallback ?? const SizedBox.shrink());
  }
}
