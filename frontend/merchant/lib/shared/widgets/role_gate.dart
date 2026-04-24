import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/store/active_store_provider.dart';

/// Hides its child unless the active StoreContext's role is in [allowed].
/// Falls back to [fallback] (defaults to empty widget) when hidden.
class RoleGate extends ConsumerWidget {
  final Set<String> allowed;
  final Widget child;
  final Widget? fallback;

  const RoleGate({
    required this.allowed,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeStoreProvider)?.role;
    final show = role != null && allowed.contains(role);
    return show ? child : (fallback ?? const SizedBox.shrink());
  }
}
