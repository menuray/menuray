import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/store.dart';
import '../../../shared/validation.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StoreManagementScreen extends ConsumerStatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  ConsumerState<StoreManagementScreen> createState() =>
      _StoreManagementScreenState();
}

class _StoreManagementScreenState extends ConsumerState<StoreManagementScreen> {
  /// Pending-save Store. While non-null, the first card renders this in place
  /// of the fetched value. Cleared on success OR failure.
  Store? _optimistic;

  Future<void> _pickAndUploadLogo(Store store) async {
    final l = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    final ext = p.extension(file.name).toLowerCase().replaceFirst('.', '');
    if (ext != 'png' && ext != 'svg') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.logoUploadBadFormat)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.logoUploadInProgress),
        duration: const Duration(seconds: 3),
      ),
    );

    final supabase = Supabase.instance.client;
    final storagePath = '${store.id}/logo.$ext';
    try {
      final bytes = await file.readAsBytes();
      await supabase.storage.from('store-logos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl =
          supabase.storage.from('store-logos').getPublicUrl(storagePath);
      final cacheBusted =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(storeRepositoryProvider).updateStore(
            storeId: store.id,
            name: store.name,
            address: store.address,
            logoUrl: cacheBusted,
          );
      ref.invalidate(currentStoreProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.logoUploadSuccess)));
    } on StorageException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == '413'
          ? l.logoUploadTooLarge
          : e.statusCode == '415'
              ? l.logoUploadBadFormat
              : l.logoUploadFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.logoUploadFailed)));
    }
  }

  Future<void> _edit(Store original) async {
    final result = await showDialog<_StoreEdit>(
      context: context,
      builder: (_) => _EditDialog(initial: original),
    );
    if (result == null) return;

    final pending = Store(
      id: original.id,
      name: result.name,
      address: result.address,
      logoUrl: original.logoUrl,
      menuCount: original.menuCount,
      weeklyVisits: original.weeklyVisits,
      isCurrent: original.isCurrent,
    );
    setState(() => _optimistic = pending);

    try {
      await ref.read(storeRepositoryProvider).updateStore(
            storeId: original.id,
            name: result.name,
            address: result.address,
          );
      ref.invalidate(currentStoreProvider);
      if (mounted) setState(() => _optimistic = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimistic = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.storeManageSaveFailed('$e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(ownerStoresProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => context.go(AppRoutes.settings),
        ),
        title: Text(
          l.storeManageTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
        actions: [
          Tooltip(
            message: l.storeManageAddStoreDisabled,
            child: TextButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.storeManageAddStore),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: l.storeManageLoadFailed('$e'),
          onRetry: () => ref.invalidate(currentStoreProvider),
        ),
        data: (stores) {
          final display = <Store>[
            if (_optimistic != null)
              _optimistic!
            else if (stores.isNotEmpty)
              stores.first,
            ...stores.skip(1),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in display) ...[
                  _StoreCard(
                    store: s,
                    onEdit: () => _edit(s),
                    onLogoTap: () => _pickAndUploadLogo(s),
                  ),
                  const SizedBox(height: 16),
                ],
                const _BottomCaption(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store card
// ---------------------------------------------------------------------------

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, this.onEdit, this.onLogoTap});

  final Store store;
  final VoidCallback? onEdit;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final isCurrent = store.isCurrent;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: AppColors.primaryDark, width: 1.5)
            : Border.all(color: const Color(0x1AC0C8C4), width: 1),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? AppColors.primaryDark.withValues(alpha: 0.08)
                : const Color(0x081C1C18),
            blurRadius: isCurrent ? 20 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoreCardHeader(
              store: store,
              onEdit: onEdit,
              onLogoTap: onLogoTap,
            ),
            const SizedBox(height: 8),
            _StoreAddress(address: store.address),
            const SizedBox(height: 16),
            _StoreStats(store: store),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card header
// ---------------------------------------------------------------------------

class _StoreCardHeader extends StatelessWidget {
  const _StoreCardHeader({required this.store, this.onEdit, this.onLogoTap});

  final Store store;
  final VoidCallback? onEdit;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Tooltip(
          message: l.logoTapHint,
          child: GestureDetector(
            onTap: onLogoTap,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
              backgroundImage: store.logoUrl != null
                  ? NetworkImage(store.logoUrl!)
                  : null,
              child: store.logoUrl == null
                  ? Text(
                      store.name.isNotEmpty
                          ? store.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            store.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: store.isCurrent ? AppColors.primaryDark : AppColors.ink,
            ),
          ),
        ),
        if (store.isCurrent) ...[
          const _CurrentBadge(),
          const SizedBox(width: 8),
        ],
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.secondary, size: 20),
            tooltip: l.storeManageEditTooltip,
            onPressed: onEdit,
          ),
        _StoreMoreMenu(store: store),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "当前店" badge
// ---------------------------------------------------------------------------

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // tertiary-container from design — warm amber container
        color: const Color(0xFF754C14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppLocalizations.of(context)!.storeManageCurrentBadge,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8BF7D),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popup more menu
// ---------------------------------------------------------------------------

class _StoreMoreMenu extends StatelessWidget {
  const _StoreMoreMenu({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.secondary),
      onSelected: (_) {},
      itemBuilder: (context) => [
        PopupMenuItem(value: 'enter', child: Text(l.storeManageMoreEnter)),
        PopupMenuItem(value: 'settings', child: Text(l.storeManageMoreSettings)),
        PopupMenuItem(value: 'copy', child: Text(l.storeManageMoreCopyMenu)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Address row
// ---------------------------------------------------------------------------

class _StoreAddress extends StatelessWidget {
  const _StoreAddress({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    if (address == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on,
          size: 14,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            address!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StoreStats extends StatelessWidget {
  const _StoreStats({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        _StatChip(label: l.storeManageMenuSetsCount(store.menuCount)),
        const SizedBox(width: 12),
        const _Divider(),
        const SizedBox(width: 12),
        _StatChip(label: l.storeManageWeeklyVisits(_formatVisits(store.weeklyVisits))),
      ],
    );
  }

  static String _formatVisits(int n) {
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      if (remainder == 0) return '$thousands,000';
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return n.toString();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      color: const Color(0x33C0C8C4),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom caption
// ---------------------------------------------------------------------------

class _BottomCaption extends StatelessWidget {
  const _BottomCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.storeManageBottomCaption,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit dialog
// ---------------------------------------------------------------------------

class _StoreEdit {
  final String name;
  final String? address;
  const _StoreEdit({required this.name, this.address});
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.initial});

  final Store initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _addressCtrl = TextEditingController(text: widget.initial.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState?.validate() != true) return;
    final name = _nameCtrl.text.trim();
    final addressRaw = _addressCtrl.text.trim();
    Navigator.of(context).pop(
      _StoreEdit(
        name: name,
        address: addressRaw.isNotEmpty ? addressRaw : null,
      ),
    );
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.storeManageEditTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('store-name-field'),
              controller: _nameCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final loc = AppLocalizations.of(context)!;
                return validateRequired(v, loc) ??
                    validateMaxLength(v, loc, max: 60);
              },
              decoration: InputDecoration(labelText: l.storeManageFieldName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(labelText: l.storeManageFieldAddress),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _onCancel, child: Text(l.commonCancel)),
        TextButton(
          key: const Key('store-save-button'),
          onPressed: _onSave,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }
}
