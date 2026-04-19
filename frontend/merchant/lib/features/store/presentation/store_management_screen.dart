import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/models/store.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StoreManagementScreen extends StatelessWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => context.go(AppRoutes.settings),
        ),
        title: const Text(
          '门店管理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
            label: const Text(
              '新增门店',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store cards list
            for (final store in MockData.stores) ...[
              _StoreCard(store: store),
              const SizedBox(height: 16),
            ],
            // Bottom caption
            const _BottomCaption(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store card
// ---------------------------------------------------------------------------

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final Store store;

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
            // Header row: name + badge + more menu
            _StoreCardHeader(store: store),
            const SizedBox(height: 8),
            // Address
            _StoreAddress(address: store.address),
            const SizedBox(height: 16),
            // Stats row
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
  const _StoreCardHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
      child: const Text(
        '当前',
        style: TextStyle(
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.secondary),
      onSelected: (_) {},
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'enter', child: Text('进入')),
        PopupMenuItem(value: 'settings', child: Text('设置')),
        PopupMenuItem(value: 'copy', child: Text('复制菜单')),
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
    return Row(
      children: [
        _StatChip(label: '${store.menuCount} 套菜单'),
        const SizedBox(width: 12),
        const _Divider(),
        const SizedBox(width: 12),
        _StatChip(label: '本周 ${_formatVisits(store.weeklyVisits)} 访问'),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          '菜单可在门店间复用或独立编辑',
          style: TextStyle(
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
