import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

enum _TimeRange { today, sevenDays, thirtyDays, custom }

class _StatisticsScreenState extends State<StatisticsScreen> {
  _TimeRange _selected = _TimeRange.sevenDays;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => context.go(AppRoutes.menuManage),
        ),
        title: const Text(
          '数据',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: _ExportButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Time range segment control
          _TimeRangeSegment(
            selected: _selected,
            onChanged: (v) => setState(() => _selected = v),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          // Scrollable content
          const Expanded(
            child: _StatisticsBody(),
          ),
        ],
      ),
      bottomNavigationBar: MerchantBottomNav(
        current: MerchantTab.data,
        onTap: (tab) {
          switch (tab) {
            case MerchantTab.menus:
              context.go(AppRoutes.home);
            case MerchantTab.data:
              // already on data screen, no-op
              break;
            case MerchantTab.mine:
              context.go(AppRoutes.settings);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export button
// ---------------------------------------------------------------------------

class _ExportButton extends StatelessWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.download, size: 16, color: AppColors.secondary),
      label: const Text(
        '导出',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.secondary,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFE6E2DB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time range segment
// ---------------------------------------------------------------------------

class _TimeRangeSegment extends StatelessWidget {
  const _TimeRangeSegment({
    required this.selected,
    required this.onChanged,
  });

  final _TimeRange selected;
  final ValueChanged<_TimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _SegmentButton(
              label: '今日',
              isSelected: selected == _TimeRange.today,
              onTap: () => onChanged(_TimeRange.today),
            ),
            _SegmentButton(
              label: '7 天',
              isSelected: selected == _TimeRange.sevenDays,
              onTap: () => onChanged(_TimeRange.sevenDays),
            ),
            _SegmentButton(
              label: '30 天',
              isSelected: selected == _TimeRange.thirtyDays,
              onTap: () => onChanged(_TimeRange.thirtyDays),
            ),
            _SegmentButton(
              label: '自定义',
              isSelected: selected == _TimeRange.custom,
              onTap: () => onChanged(_TimeRange.custom),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A2F5D50),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primaryDark : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scrollable body
// ---------------------------------------------------------------------------

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // Overview cards row
          _OverviewCards(),
          SizedBox(height: 20),
          // Line chart card
          _LineChartCard(),
          SizedBox(height: 20),
          // Top 10 dish ranking
          _DishRankingCard(),
          SizedBox(height: 20),
          // Category pie chart
          _PieChartCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview cards
// ---------------------------------------------------------------------------

class _OverviewCards extends StatelessWidget {
  const _OverviewCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _OverviewCard(
            label: '总访问量',
            value: '8,432',
            icon: Icons.visibility_outlined,
            hasTrend: true,
            trendLabel: '↑12%',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            label: '独立访客',
            value: '3,421',
            icon: Icons.group_outlined,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            label: '平均停留',
            value: '1m 42s',
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    this.hasTrend = false,
    this.trendLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool hasTrend;
  final String? trendLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081C1C18),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: AppColors.primaryDark.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: hasTrend ? AppColors.primaryDark : AppColors.ink,
              height: 1.1,
            ),
          ),
          if (hasTrend && trendLabel != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trendLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Line chart card
// ---------------------------------------------------------------------------

class _LineChartCard extends StatelessWidget {
  const _LineChartCard();

  static const _data = [800.0, 950.0, 1100.0, 1050.0, 1200.0, 1300.0, 1247.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081C1C18),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '每日访问量',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Icon(Icons.more_horiz, color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '过去 7 天',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          // Chart area
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _LineChartPainter(data: _data),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.data});

  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double paddingLeft = 40;
    const double paddingBottom = 28;
    const double paddingTop = 10;
    const double paddingRight = 10;

    final chartW = size.width - paddingLeft - paddingRight;
    final chartH = size.height - paddingBottom - paddingTop;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    // Helper: map data index → canvas point
    Offset toPoint(int i, double val) {
      final x = paddingLeft + (i / (data.length - 1)) * chartW;
      final y = paddingTop + (1 - (val - minVal) / range) * chartH;
      return Offset(x, y);
    }

    final axisColor = const Color(0xFFE6E2DB);
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    // Draw horizontal grid lines (4)
    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + (i / 4) * chartH;
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), axisPaint);
    }

    // Draw Y-axis labels
    final labelStyle = const TextStyle(
      fontSize: 10,
      color: AppColors.secondary,
      fontWeight: FontWeight.w400,
    );
    for (int i = 0; i <= 4; i++) {
      final val = maxVal - (i / 4) * range;
      final y = paddingTop + (i / 4) * chartH;
      final tp = TextPainter(
        text: TextSpan(
          text: val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.round().toString(),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Draw X-axis day labels
    final days = ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'];
    for (int i = 0; i < data.length; i++) {
      final pt = toPoint(i, data[i]);
      final tp = TextPainter(
        text: TextSpan(text: days[i], style: const TextStyle(fontSize: 9, color: AppColors.secondary)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, size.height - paddingBottom + 6));
    }

    // Build path for filled area + line
    final points = [for (int i = 0; i < data.length; i++) toPoint(i, data[i])];

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    // Filled area
    final fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, paddingTop + chartH);
    fillPath.lineTo(points.first.dx, paddingTop + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryDark.withValues(alpha: 0.20),
          AppColors.primaryDark.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // Data point dots
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final pt in points) {
      canvas.drawCircle(pt, 4, dotFill);
      canvas.drawCircle(pt, 4, dotStroke);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) => oldDelegate.data != data;
}

// ---------------------------------------------------------------------------
// Dish ranking card
// ---------------------------------------------------------------------------

// Static data: rank + name + count
const _rankData = [
  ('宫保鸡丁', 1209),
  ('麻婆豆腐', 987),
  ('口水鸡', 654),
  ('凉拌黄瓜', 432),
  ('川北凉粉', 298),
];

class _DishRankingCard extends StatelessWidget {
  const _DishRankingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081C1C18),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '菜品热度排行',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                'TOP 5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // List
          for (int i = 0; i < _rankData.length; i++) ...[
            _DishRankRow(
              rank: i + 1,
              name: _rankData[i].$1,
              count: _rankData[i].$2,
            ),
            if (i < _rankData.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFECE7DC)),
          ],
        ],
      ),
    );
  }
}

class _DishRankRow extends StatelessWidget {
  const _DishRankRow({
    required this.rank,
    required this.name,
    required this.count,
  });

  final int rank;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop
                  ? AppColors.accent
                  : const Color(0xFFE6E2DB),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isTop ? Colors.white : AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Dish image placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDE6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 24,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          // Count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCount(count),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const Text(
                '次',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }
}

// ---------------------------------------------------------------------------
// Pie chart card
// ---------------------------------------------------------------------------

class _PieChartCard extends StatelessWidget {
  const _PieChartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081C1C18),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '类别热度',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '按类别统计浏览占比',
            style: TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          // Pie + legend row
          Row(
            children: [
              // Pie chart
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    slices: const [
                      _PieSlice(fraction: 0.35, color: AppColors.accent, label: '凉菜'),
                      _PieSlice(fraction: 0.65, color: AppColors.primaryDark, label: '热菜'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              const Expanded(child: _PieLegend()),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice({
    required this.fraction,
    required this.color,
    required this.label,
  });

  final double fraction;
  final Color color;
  final String label;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.slices});

  final List<_PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    double startAngle = -math.pi / 2; // start from top

    for (final slice in slices) {
      final sweepAngle = 2 * math.pi * slice.fraction;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      // White gap between slices
      final gapPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        gapPaint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) => false;
}

class _PieLegend extends StatelessWidget {
  const _PieLegend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendItem(
          color: AppColors.accent,
          label: '凉菜',
          percent: '35%',
        ),
        SizedBox(height: 16),
        _LegendItem(
          color: AppColors.primaryDark,
          label: '热菜',
          percent: '65%',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
        ),
        Text(
          percent,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
