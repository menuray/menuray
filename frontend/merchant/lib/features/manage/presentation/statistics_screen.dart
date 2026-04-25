import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../shared/widgets/tier_gate.dart';
import '../../../theme/app_colors.dart';
import '../../billing/tier.dart';
import '../../store/active_store_provider.dart';
import '../statistics_providers.dart';
import '../statistics_repository.dart';
import 'upgrade_callout.dart';

enum _TimeRange { today, sevenDays, thirtyDays, custom }

extension _RangeX on _TimeRange {
  StatisticsRange toRange() {
    final now = DateTime.now();
    DateTime from;
    switch (this) {
      case _TimeRange.today:
        from = DateTime(now.year, now.month, now.day);
        break;
      case _TimeRange.sevenDays:
        from = now.subtract(const Duration(days: 7));
        break;
      case _TimeRange.thirtyDays:
        from = now.subtract(const Duration(days: 30));
        break;
      case _TimeRange.custom:
        // Simplification: custom == last 12 months (retention cap). A real
        // date picker can replace this in a future session.
        from = DateTime(now.year - 1, now.month, now.day);
        break;
    }
    return (from: from, to: now);
  }
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  _TimeRange _selected = _TimeRange.sevenDays;
  // Cache the range so that every widget rebuild passes the same object to the
  // Riverpod family. If we called DateTime.now() inside build(), each rebuild
  // would produce a microsecond-different range, creating a new family key and
  // causing the autoDispose provider to be discarded before it can resolve.
  late StatisticsRange _range;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _range = _selected.toRange();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      // Recompute the range and invalidate the provider so data refreshes.
      setState(() => _range = _selected.toRange());
      ref.invalidate(statisticsProvider(_range));
    });
  }

  void _onRangeChanged(_TimeRange v) {
    setState(() {
      _selected = v;
      _range = v.toRange();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(
          t.statisticsTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: TierGate(
              allowed: {Tier.growth},
              child: _ExportButton(),
            ),
          ),
        ],
      ),
      body: TierGate(
        allowed: const {Tier.pro, Tier.growth},
        fallback: const UpgradeCallout(),
        child: Column(
          children: [
            _TimeRangeSegment(
              selected: _selected,
              onChanged: _onRangeChanged,
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            Expanded(child: _StatisticsBody(range: _range)),
          ],
        ),
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

class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody({required this.range});
  final StatisticsRange range;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(statisticsProvider(range));
    return async.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(t.statisticsLoading)],
        ),
      ),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e.toString()))),
      data: (data) {
        final total = data.overview.totalViews;
        if (total == 0) {
          return Center(child: Text(t.statisticsNoData));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewCard(overview: data.overview),
              const SizedBox(height: 16),
              _VisitsChartCard(points: data.byDay),
              const SizedBox(height: 16),
              _TopDishesCard(dishes: data.topDishes),
              const SizedBox(height: 16),
              _LocalesCard(rows: data.byLocale),
            ],
          ),
        );
      },
    );
  }
}

class _TimeRangeSegment extends StatelessWidget {
  const _TimeRangeSegment({required this.selected, required this.onChanged});
  final _TimeRange selected;
  final ValueChanged<_TimeRange> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<_TimeRange>(
        segments: [
          ButtonSegment(value: _TimeRange.today,      label: Text(t.statisticsRangeToday)),
          ButtonSegment(value: _TimeRange.sevenDays,  label: Text(t.statisticsRangeSevenDays)),
          ButtonSegment(value: _TimeRange.thirtyDays, label: Text(t.statisticsRangeThirtyDays)),
          ButtonSegment(value: _TimeRange.custom,     label: Text(t.statisticsRangeCustom)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});
  final VisitsOverview overview;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _StatCell(label: t.statisticsOverviewVisits, value: '${overview.totalViews}')),
            Expanded(child: _StatCell(label: t.statisticsOverviewUnique, value: '${overview.uniqueSessions}')),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _VisitsChartCard extends StatelessWidget {
  const _VisitsChartCard({required this.points});
  final List<VisitsByDayPoint> points;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final maxCount = points.isEmpty ? 1 : points.map((p) => p.count).reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.statisticsDailyVisits, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _LineChartPainter(
                  values: points.map((p) => p.count.toDouble()).toList(),
                  max: maxCount.toDouble(),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.max});
  final List<double> values;
  final double max;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / math.max(1, values.length - 1)) * size.width;
      final y = size.height - (values[i] / math.max(1, max)) * size.height;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.max != max;
}

class _TopDishesCard extends StatelessWidget {
  const _TopDishesCard({required this.dishes});
  final List<TopDish> dishes;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.statisticsDishRanking, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (dishes.isEmpty)
              Text(t.statisticsDishTrackingDisabled, style: Theme.of(context).textTheme.bodyMedium)
            else
              ...dishes.map((d) => ListTile(
                    dense: true,
                    title: Text(d.dishName),
                    trailing: Text('${d.count}'),
                  )),
          ],
        ),
      ),
    );
  }
}

class _LocalesCard extends StatelessWidget {
  const _LocalesCard({required this.rows});
  final List<LocaleTraffic> rows;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.statisticsTrafficByLocale, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(t.statisticsNoData)
            else
              ...rows.map((r) => ListTile(
                    dense: true,
                    title: Text(r.locale),
                    trailing: Text('${r.count}'),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  const _ExportButton();
  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return IconButton(
      key: const Key('statistics-export-button'),
      icon: _busy
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download_outlined),
      tooltip: t.statisticsExport,
      onPressed: _busy ? null : _onPressed,
    );
  }

  Future<void> _onPressed() async {
    final t = AppLocalizations.of(context)!;
    final ctx = ref.read(activeStoreProvider);
    if (ctx == null) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final range = (from: now.subtract(const Duration(days: 30)), to: now);
      final csv = await ref
          .read(statisticsRepositoryProvider)
          .exportCsv(storeId: ctx.storeId, range: range);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/menuray-statistics.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: t.statisticsExportSubject));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.statisticsExportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
