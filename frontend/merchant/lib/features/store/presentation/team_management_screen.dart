import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/store_invite.dart';
import '../../../shared/models/store_member.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../active_store_provider.dart';
import '../membership_providers.dart';

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({required this.storeId, super.key});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final active = ref.watch(activeStoreProvider);
    final canInvite = active?.canWrite ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.teamScreenTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: t.teamTabMembers),
              Tab(text: t.teamTabInvites),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersTab(storeId: storeId),
            _InvitesTab(storeId: storeId),
          ],
        ),
        floatingActionButton: canInvite
            ? FloatingActionButton.extended(
                key: const Key('team-invite-fab'),
                icon: const Icon(Icons.person_add),
                label: Text(t.teamInviteCta),
                onPressed: () => _showInviteSheet(context, ref),
              )
            : null,
      ),
    );
  }

  Future<void> _showInviteSheet(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController();
    String role = 'manager';

    final inv = await showModalBottomSheet<StoreInvite?>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(c).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.teamInviteCta,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const Key('invite-email-field'),
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: t.teamInviteEmailHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('invite-role-dropdown'),
                initialValue: role,
                decoration: InputDecoration(
                  labelText: t.teamInviteRoleLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'manager', child: Text(t.roleManager)),
                  DropdownMenuItem(value: 'staff', child: Text(t.roleStaff)),
                ],
                onChanged: (v) => setState(() => role = v ?? 'manager'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('invite-send-button'),
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  try {
                    final out = await ref
                        .read(membershipRepositoryProvider)
                        .createInvite(
                            storeId: storeId, email: email, role: role);
                    if (ctx.mounted) Navigator.pop(ctx, out);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                child: Text(t.teamInviteSend),
              ),
            ],
          ),
        ),
      ),
    );

    if (inv != null && context.mounted) {
      await _showCopyLinkDialog(context, inv);
      ref.invalidate(storeInvitesProvider(storeId));
    }
  }

  Future<void> _showCopyLinkDialog(BuildContext context, StoreInvite inv) async {
    final t = AppLocalizations.of(context)!;
    final url = AppConfig.customerInviteUrl(inv.token);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.teamInviteSentSnackbar(inv.email ?? '')),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(c).showSnackBar(
                SnackBar(content: Text(t.teamInviteLinkCopied)),
              );
              Navigator.pop(c);
            },
            child: Text(t.teamInviteCopyLink),
          ),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storeMembersProvider(storeId));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) =>
              _MemberTile(member: rows[i], storeId: storeId),
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.storeId});
  final StoreMember member;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final active = ref.watch(activeStoreProvider);
    final canManage = active?.canManageTeam ?? false;
    final roleLabel = switch (member.role) {
      'owner' => t.roleOwner,
      'manager' => t.roleManager,
      _ => t.roleStaff,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: member.avatarUrl != null
            ? NetworkImage(member.avatarUrl!)
            : null,
        child:
            member.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(member.displayName ?? member.email ?? member.userId),
      subtitle: Text(roleLabel),
      trailing: canManage && member.role != 'owner'
          ? IconButton(
              key: Key('member-remove-${member.id}'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmRemove(context, ref),
            )
          : null,
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(t.teamMemberRemoveConfirm(
            member.displayName ?? member.email ?? '')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.teamMemberRemove)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(membershipRepositoryProvider).removeMember(member.id);
        ref.invalidate(storeMembersProvider(storeId));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString().contains('last owner')
                    ? t.teamMemberLastOwnerError
                    : e.toString())),
          );
        }
      }
    }
  }
}

class _InvitesTab extends ConsumerWidget {
  const _InvitesTab({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(storeInvitesProvider(storeId));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final inv = rows[i];
            return ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(inv.email ?? inv.phone ?? ''),
              subtitle: Text(inv.role),
              trailing: inv.isExpired
                  ? Text(t.teamInviteExpiredBadge,
                      style: const TextStyle(color: Colors.red))
                  : TextButton(
                      key: Key('invite-revoke-${inv.id}'),
                      onPressed: () async {
                        await ref
                            .read(membershipRepositoryProvider)
                            .revokeInvite(inv.id);
                        ref.invalidate(storeInvitesProvider(storeId));
                      },
                      child: Text(t.teamInviteRevoke),
                    ),
            );
          },
        );
      },
    );
  }
}
