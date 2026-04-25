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
import '../data/store_creation_repository.dart';
import '../membership_providers.dart';
import '../store_creation_providers.dart';

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
                  itemCount: memberships.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i < memberships.length) {
                      return _StoreCard(memberships[i]);
                    }
                    return const _NewStoreTile();
                  },
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

class _NewStoreTile extends ConsumerWidget {
  const _NewStoreTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return Card(
      key: const Key('store-picker-new-store-tile'),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.add_business)),
        title: Text(t.storePickerNewStore),
        subtitle: Text(t.storePickerNewStoreGrowthOnly),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openSheet(context, ref),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: const _NewStoreSheet(),
      ),
    );
  }
}

class _NewStoreSheet extends ConsumerStatefulWidget {
  const _NewStoreSheet();

  @override
  ConsumerState<_NewStoreSheet> createState() => _NewStoreSheetState();
}

class _NewStoreSheetState extends ConsumerState<_NewStoreSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _localeCtrl = TextEditingController(text: 'en');
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _localeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    final t = AppLocalizations.of(context)!;
    final repo = ref.read(storeCreationRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);

    setState(() => _submitting = true);
    try {
      final res = await repo.createStore(
        name: _nameCtrl.text.trim(),
        currency: _currencyCtrl.text.trim().isEmpty
            ? 'USD'
            : _currencyCtrl.text.trim().toUpperCase(),
        sourceLocale:
            _localeCtrl.text.trim().isEmpty ? 'en' : _localeCtrl.text.trim(),
      );
      // Ensure the new store appears in the picker + auto-select it.
      ref.invalidate(membershipsProvider);
      await ref.read(activeStoreProvider.notifier).setStore(
            StoreContext(storeId: res.storeId, role: 'owner'),
          );
      if (!mounted) return;
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.storeCreateSuccess)));
      router.go(AppRoutes.home);
    } on MultiStoreRequiresGrowthError {
      if (!mounted) return;
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(t.aiOverQuotaSnackbar),
          action: SnackBarAction(
            label: t.aiOverQuotaUpgradeAction,
            onPressed: () => router.go(AppRoutes.upgrade),
          ),
        ));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.storeCreateGenericError)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.storeFormTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t.storeFormName,
                hintText: t.storeFormNameHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? t.commonOperationFailed
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyCtrl,
              decoration: InputDecoration(
                labelText: t.storeFormCurrency,
                border: const OutlineInputBorder(),
              ),
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _localeCtrl,
              decoration: InputDecoration(
                labelText: t.storeFormSourceLocale,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting ? t.storeFormCreating : t.storeFormCreate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
