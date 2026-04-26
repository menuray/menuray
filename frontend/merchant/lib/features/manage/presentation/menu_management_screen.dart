import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/_mappers.dart';
import '../../../shared/models/dish.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/role_gate.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../menu_management_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key, required this.menuId});

  final String menuId;

  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  // Local optimistic overlay: dishId → pending sold-out value (cleared on
  // either backend confirmation or error).
  final Map<String, bool> _optimisticSoldOut = {};

  // Optimistic overlay for the time-slot radio so the UI snaps before the
  // network round-trip. Cleared after the menus.time_slot PATCH resolves.
  MenuTimeSlot? _timeSlotOverride;

  Future<void> _setTimeSlot(MenuTimeSlot previous, MenuTimeSlot next) async {
    if (next == previous) return;
    setState(() => _timeSlotOverride = next);
    try {
      await ref.read(menuRepositoryProvider).updateMenu(
            menuId: widget.menuId,
            timeSlot: menuTimeSlotToApiString(next),
          );
      ref.invalidate(menuByIdProvider(widget.menuId));
      if (mounted) {
        setState(() => _timeSlotOverride = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _timeSlotOverride = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.menuTimeSlotSaveFailed),
        ),
      );
    }
  }

  Future<void> _toggleSoldOut(String dishId, bool next) async {
    setState(() => _optimisticSoldOut[dishId] = next);
    try {
      await ref
          .read(menuRepositoryProvider)
          .setDishSoldOut(dishId: dishId, soldOut: next);
      ref.invalidate(menuByIdProvider(widget.menuId));
      if (mounted) {
        setState(() => _optimisticSoldOut.remove(dishId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimisticSoldOut.remove(dishId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.menuManageSoldOutUpdateFailed('$e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final menuAsync = ref.watch(menuByIdProvider(widget.menuId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _AppBar(menuAsync: menuAsync),
      body: menuAsync.when(
        loading: () => LoadingView(label: l.loadingDefault),
        error: (err, _) => ErrorView(
          message: l.errorGenericMessage,
          retryLabel: l.errorRetry,
          onRetry: () => ref.invalidate(menuByIdProvider(widget.menuId)),
        ),
        data: (menu) => _buildContent(menu),
      ),
    );
  }

  Widget _buildContent(Menu menu) {
    final l = AppLocalizations.of(context)!;
    final timeSlot = _timeSlotOverride ?? menu.timeSlot;
    final dishes =
        menu.categories.expand((c) => c.dishes).toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoCard(),
          const SizedBox(height: 20),
          _QuickActionsRow(
            onEditContent: () => context.go(AppRoutes.organizeFor(widget.menuId)),
            onShare: () => context.go(AppRoutes.publishedFor(widget.menuId)),
            onStatistics: () => context.go(AppRoutes.statistics),
          ),
          const SizedBox(height: 24),
          _SectionHeader(icon: Icons.restaurant, title: l.menuManageSoldOutSection),
          const SizedBox(height: 12),
          _SoldOutSection(
            dishes: dishes,
            effectiveSoldOut: (d) =>
                _optimisticSoldOut[d.id] ?? d.soldOut,
            onToggle: _toggleSoldOut,
          ),
          const SizedBox(height: 24),
          _SectionHeader(icon: Icons.schedule, title: l.menuManageTimeSlotSection),
          const SizedBox(height: 12),
          _TimeSlotSection(
            selected: timeSlot,
            onChanged: (slot) => _setTimeSlot(menu.timeSlot, slot),
          ),
          const SizedBox(height: 24),
          _SectionHeader(icon: Icons.palette_outlined, title: l.menuManageAppearance),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 24,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.palette_outlined, color: AppColors.primary),
              title: Text(l.menuManageAppearance),
              trailing: const Icon(Icons.chevron_right, color: AppColors.secondary),
              onTap: () => context.push(AppRoutes.selectTemplateFor(widget.menuId)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.menuAsync});

  final AsyncValue<Menu> menuAsync;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final title = menuAsync.maybeWhen(
      data: (m) => m.name,
      orElse: () => AppLocalizations.of(context)!.homeLoading,
    );
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 16, color: AppColors.secondary),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.more_vert, color: AppColors.secondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info card  (content remains hardcoded — analytics wiring is a later pass)
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1C1C18),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _InfoCardContent()),
          SizedBox(width: 16),
          _QrThumbnail(),
        ],
      ),
    );
  }
}

class _InfoCardContent extends StatelessWidget {
  const _InfoCardContent();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusChip(label: l.statusPublished, variant: ChipVariant.published),
            const SizedBox(width: 10),
            Text(
              l.menuManageUpdatedAgo,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.menuManageViewsLabel,
          style: TextStyle(fontSize: 12, color: AppColors.secondary),
        ),
        const SizedBox(height: 2),
        const Text(
          '1,247',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _QrThumbnail extends StatelessWidget {
  const _QrThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E2DB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26000000)),
      ),
      child:
          const Icon(Icons.qr_code_2, size: 44, color: AppColors.primaryDark),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onEditContent,
    required this.onShare,
    required this.onStatistics,
  });

  final VoidCallback onEditContent;
  final VoidCallback onShare;
  final VoidCallback onStatistics;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
              icon: Icons.edit, label: l.menuManageActionEditContent, onTap: onEditContent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(icon: Icons.block, label: l.menuManageActionSoldOut),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(icon: Icons.attach_money, label: l.menuManageActionPriceAdjust),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RoleGate(
            allowed: const {'owner', 'manager'},
            child: _ActionButton(icon: Icons.share, label: l.menuManageActionShare, onTap: onShare),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
              icon: Icons.analytics, label: l.menuManageActionStatistics, onTap: onStatistics),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1C1C18),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sold-out section
// ---------------------------------------------------------------------------

class _SoldOutSection extends StatelessWidget {
  const _SoldOutSection({
    required this.dishes,
    required this.effectiveSoldOut,
    required this.onToggle,
  });

  final List<Dish> dishes;
  final bool Function(Dish) effectiveSoldOut;
  final Future<void> Function(String dishId, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final dish in dishes) ...[
            _SoldOutItem(
              dish: dish,
              isSoldOut: effectiveSoldOut(dish),
              onToggle: (v) => onToggle(dish.id, v),
            ),
            if (dish != dishes.last)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _SoldOutItem extends StatelessWidget {
  const _SoldOutItem({
    required this.dish,
    required this.isSoldOut,
    required this.onToggle,
  });

  final Dish dish;
  final bool isSoldOut;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSoldOut
                  ? const Color(0xFFE6E2DB)
                  : AppColors.primaryDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant,
              size: 24,
              color: isSoldOut ? AppColors.secondary : AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dish.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSoldOut ? AppColors.secondary : AppColors.ink,
              ),
            ),
          ),
          if (isSoldOut) ...[
            StatusChip(
              label: AppLocalizations.of(context)!.statusSoldOut,
              variant: ChipVariant.soldOut,
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: isSoldOut,
            onChanged: onToggle,
            activeThumbColor: AppColors.error,
            activeTrackColor: AppColors.error.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time slot section  (local-only, not persisted)
// ---------------------------------------------------------------------------

class _TimeSlotSection extends StatelessWidget {
  const _TimeSlotSection({required this.selected, required this.onChanged});

  final MenuTimeSlot selected;
  final ValueChanged<MenuTimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _TimeSlotOption(
            slot: MenuTimeSlot.lunch,
            label: l.menuManageTimeSlotLunch,
            subtitle: l.menuManageTimeSlotLunchHours,
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.dinner,
            label: l.menuManageTimeSlotDinner,
            subtitle: l.menuManageTimeSlotDinnerHours,
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.allDay,
            label: l.menuManageTimeSlotAllDay,
            subtitle: l.menuManageTimeSlotAllDayHours,
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.seasonal,
            label: l.menuManageTimeSlotSeasonal,
            subtitle: l.menuManageTimeSlotSeasonalHours,
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TimeSlotOption extends StatelessWidget {
  const _TimeSlotOption({
    required this.slot,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final MenuTimeSlot slot;
  final String label;
  final String subtitle;
  final MenuTimeSlot selected;
  final ValueChanged<MenuTimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == slot;
    return GestureDetector(
      onTap: () => onChanged(slot),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            _RadioIndicator(selected: isSelected),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primaryDark : AppColors.secondary,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark,
                ),
              ),
            )
          : null,
    );
  }
}
