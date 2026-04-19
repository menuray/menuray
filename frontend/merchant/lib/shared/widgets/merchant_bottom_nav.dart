import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum MerchantTab { menus, data, mine }

class MerchantBottomNav extends StatelessWidget {
  const MerchantBottomNav({super.key, required this.current, required this.onTap});

  final MerchantTab current;
  final ValueChanged<MerchantTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 24, color: Color(0x14000000), offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TabItem(icon: Icons.restaurant_menu, label: 'Menus', active: current == MerchantTab.menus, onTap: () => onTap(MerchantTab.menus)),
          _TabItem(icon: Icons.analytics_outlined, label: 'Data', active: current == MerchantTab.data, onTap: () => onTap(MerchantTab.data)),
          _TabItem(icon: Icons.person_outline, label: 'Mine', active: current == MerchantTab.mine, onTap: () => onTap(MerchantTab.mine)),
        ]),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.ink.withValues(alpha: 0.5);
    final bg = active ? AppColors.primaryDark : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
