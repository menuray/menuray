import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/membership.dart';
import '../../../shared/models/store_context.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../active_store_provider.dart';
import '../membership_providers.dart';

class StorePickerScreen extends ConsumerWidget {
  const StorePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(membershipsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.storePickerTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (memberships) {
          if (memberships.isEmpty) {
            return Center(child: Text(t.authNoMembershipsBanner));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.storePickerSubtitle(memberships.length),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: memberships.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _StoreCard(memberships[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreCard extends ConsumerWidget {
  const _StoreCard(this.m);
  final Membership m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final roleLabel = switch (m.role) {
      'owner' => t.roleOwner,
      'manager' => t.roleManager,
      _ => t.roleStaff,
    };
    return Card(
      child: ListTile(
        key: Key('store-card-${m.store.id}'),
        leading: m.store.logoUrl != null
            ? CircleAvatar(backgroundImage: NetworkImage(m.store.logoUrl!))
            : const CircleAvatar(child: Icon(Icons.store)),
        title: Text(m.store.name),
        subtitle: Text(roleLabel),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await ref.read(activeStoreProvider.notifier).setStore(
                StoreContext(storeId: m.store.id, role: m.role),
              );
          if (context.mounted) context.go(AppRoutes.home);
        },
      ),
    );
  }
}
