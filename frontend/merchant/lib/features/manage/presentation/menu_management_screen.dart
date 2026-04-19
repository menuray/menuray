import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/models/dish.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  // Sold-out switch state keyed by dish id
  late final Map<String, bool> _soldOut;

  // Currently selected time slot
  MenuTimeSlot _timeSlot = MenuTimeSlot.lunch;

  @override
  void initState() {
    super.initState();
    // Collect all dishes across categories and initialise from model
    final dishes = MockData.lunchMenu.categories.expand((c) => c.dishes);
    _soldOut = {for (final d in dishes) d.id: d.soldOut};
    // Seed 口水鸡 (d1) as sold-out per spec
    _soldOut['d1'] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '午市套餐 2025 春',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.edit, size: 16, color: AppColors.secondary),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.more_vert, color: AppColors.secondary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info card ─────────────────────────────────────────────────
            const _InfoCard(),
            const SizedBox(height: 20),

            // ── Quick actions row ─────────────────────────────────────────
            _QuickActionsRow(
              onEditContent: () => context.go(AppRoutes.organize),
              onShare: () => context.go(AppRoutes.published),
              onStatistics: () => context.go(AppRoutes.statistics),
            ),
            const SizedBox(height: 24),

            // ── Sold-out management section ───────────────────────────────
            _SectionHeader(icon: Icons.restaurant, title: '售罄管理'),
            const SizedBox(height: 12),
            _SoldOutSection(
              soldOut: _soldOut,
              onToggle: (id, value) {
                setState(() => _soldOut[id] = value);
              },
            ),
            const SizedBox(height: 24),

            // ── Time slot section ─────────────────────────────────────────
            _SectionHeader(icon: Icons.schedule, title: '营业时段'),
            const SizedBox(height: 12),
            _TimeSlotSection(
              selected: _timeSlot,
              onChanged: (slot) => setState(() => _timeSlot = slot),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const StatusChip(label: '已发布', variant: ChipVariant.published),
            const SizedBox(width: 10),
            Text(
              '更新于 3 天前',
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
          '浏览量',
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
      child: const Icon(Icons.qr_code_2, size: 44, color: AppColors.primaryDark),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row (5 buttons)
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
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.edit,
            label: '编辑内容',
            onTap: onEditContent,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _ActionButton(
            icon: Icons.block,
            label: '售罄管理',
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _ActionButton(
            icon: Icons.attach_money,
            label: '调价',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.share,
            label: '分享',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.analytics,
            label: '数据',
            onTap: onStatistics,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

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
    required this.soldOut,
    required this.onToggle,
  });

  final Map<String, bool> soldOut;
  final void Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    // Collect all dishes from lunchMenu categories
    final dishes = MockData.lunchMenu.categories
        .expand((c) => c.dishes)
        .toList();

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
              isSoldOut: soldOut[dish.id] ?? dish.soldOut,
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
          // Dish icon placeholder
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
            const StatusChip(label: '已售罄', variant: ChipVariant.soldOut),
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
// Time slot section
// ---------------------------------------------------------------------------

class _TimeSlotSection extends StatelessWidget {
  const _TimeSlotSection({
    required this.selected,
    required this.onChanged,
  });

  final MenuTimeSlot selected;
  final ValueChanged<MenuTimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
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
            label: '午市',
            subtitle: '11:00–14:00',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.dinner,
            label: '晚市',
            subtitle: '17:00–22:00',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.allDay,
            label: '全天',
            subtitle: '营业时间内',
            selected: selected,
            onChanged: onChanged,
          ),
          _TimeSlotOption(
            slot: MenuTimeSlot.seasonal,
            label: '季节限定',
            subtitle: '自定义日期',
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
                    color: isSelected ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom radio indicator (avoids deprecated Radio widget APIs)
// ---------------------------------------------------------------------------

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
