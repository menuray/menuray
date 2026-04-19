import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../../theme/app_colors.dart';
import 'status_chip.dart';

class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.menu, this.onTap, this.onMore});

  final Menu menu;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final isDraft = menu.status == MenuStatus.draft;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: menu.coverImage != null
                      ? Image.asset(menu.coverImage!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.divider,
                          child: const Icon(Icons.restaurant, color: AppColors.secondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      StatusChip(
                        label: isDraft ? '草稿' : '已发布',
                        variant: isDraft ? ChipVariant.draft : ChipVariant.published,
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTime(menu.updatedAt), style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                    ]),
                    const SizedBox(height: 6),
                    Text(menu.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(isDraft ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('${menu.viewCount} 次访问', style: const TextStyle(fontSize: 13, color: AppColors.secondary)),
                    ]),
                  ],
                ),
              ),
            ]),
            Positioned(
              top: 0, right: 0,
              child: IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t).inDays;
    if (d == 0) return '今天';
    if (d == 1) return '昨天';
    if (d < 7) return '$d 天前';
    if (d < 30) return '${(d / 7).floor()} 周前';
    return '${(d / 30).floor()} 个月前';
  }
}
