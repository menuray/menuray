import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/billing_providers.dart';
import 'package:menuray_merchant/features/billing/tier.dart';
import 'package:menuray_merchant/features/manage/presentation/statistics_screen.dart';
import 'package:menuray_merchant/features/manage/statistics_providers.dart';
import 'package:menuray_merchant/features/manage/statistics_repository.dart';

import '../support/test_harness.dart';

StatisticsData _sampleData({bool dishes = true, bool visits = true}) => StatisticsData(
      overview: VisitsOverview(totalViews: visits ? 42 : 0, uniqueSessions: visits ? 17 : 0),
      byDay: visits
          ? [VisitsByDayPoint(DateTime(2026, 4, 20), 20), VisitsByDayPoint(DateTime(2026, 4, 21), 22)]
          : const [],
      topDishes: dishes
          ? [const TopDish(dishId: 'd1', dishName: '宫保鸡丁', count: 12)]
          : const [],
      byLocale: const [LocaleTraffic('zh-CN', 30), LocaleTraffic('en', 12)],
    );

void main() {
  testWidgets('free tier shows UpgradeCallout', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.free),
          testActiveStoreOverride(storeId: 'store-1'),
          statisticsProvider.overrideWith((ref, range) async => _sampleData()),
        ],
        child: zhMaterialApp(home: const StatisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statistics-upgrade-button')), findsOneWidget);
    expect(find.byKey(const Key('statistics-export-button')), findsNothing);
  });

  testWidgets('pro tier shows data, no export button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.pro),
          testActiveStoreOverride(storeId: 'store-1'),
          statisticsProvider.overrideWith((ref, range) async => _sampleData()),
        ],
        child: zhMaterialApp(home: const StatisticsScreen()),
      ),
    );
    // pumpAndSettle resolves both currentTierProvider and statisticsProvider.
    // The range is now cached in state (not re-computed on every build), so
    // Riverpod's family key stays stable and the provider resolves without looping.
    // Timer.periodic fires after 30 s of fake time; pumpAndSettle uses 100 ms
    // steps so stays well under that limit.
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('宫保鸡丁'), findsOneWidget);
    expect(find.byKey(const Key('statistics-export-button')), findsNothing);
    expect(find.byKey(const Key('statistics-upgrade-button')), findsNothing);
  });

  testWidgets('growth tier shows export button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.growth),
          testActiveStoreOverride(storeId: 'store-1'),
          statisticsProvider.overrideWith((ref, range) async => _sampleData()),
        ],
        child: zhMaterialApp(home: const StatisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statistics-export-button')), findsOneWidget);
  });
}
