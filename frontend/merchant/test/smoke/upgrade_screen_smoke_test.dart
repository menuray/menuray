import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/billing_providers.dart';
import 'package:menuray_merchant/features/billing/billing_repository.dart';
import 'package:menuray_merchant/features/billing/presentation/upgrade_screen.dart';
import 'package:menuray_merchant/features/billing/tier.dart';

import '../support/test_harness.dart';

class _FakeBillingRepository implements BillingRepository {
  String? lastSubscribeTier;
  String? lastSubscribeCurrency;
  String? lastSubscribePeriod;
  int portalCalls = 0;

  @override
  Future<String> createCheckoutSession({
    required Tier tier, required String currency, required String period,
  }) async {
    lastSubscribeTier = tier.apiName;
    lastSubscribeCurrency = currency;
    lastSubscribePeriod = period;
    return 'https://checkout.stripe.com/test';
  }

  @override
  Future<String> createPortalSession() async {
    portalCalls++;
    return 'https://billing.stripe.com/test';
  }
}

void main() {
  testWidgets('renders 3 tier cards + currency/period toggles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.free),
          billingRepositoryProvider.overrideWithValue(_FakeBillingRepository()),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('免费版'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('美元'), findsOneWidget);
    expect(find.text('人民币'), findsOneWidget);
    expect(find.text('月付'), findsOneWidget);
    // Free user shows Subscribe buttons on Pro & Growth (not Free).
    expect(find.byKey(const Key('subscribe-pro-button')), findsOneWidget);
    expect(find.byKey(const Key('subscribe-growth-button')), findsOneWidget);
    // Manage-billing only on paid tiers; free user → not present.
    expect(find.byKey(const Key('manage-billing-button')), findsNothing);
  });

  testWidgets('tap Subscribe Pro calls createCheckoutSession with correct args',
      (tester) async {
    final repo = _FakeBillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.free),
          billingRepositoryProvider.overrideWithValue(repo),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('subscribe-pro-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscribe-pro-button')));
    await tester.pump();

    expect(repo.lastSubscribeTier, 'pro');
    expect(repo.lastSubscribeCurrency, 'USD');
    expect(repo.lastSubscribePeriod, 'monthly');
  });

  testWidgets('paid user sees Manage billing button', (tester) async {
    final repo = _FakeBillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.pro),
          billingRepositoryProvider.overrideWithValue(repo),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manage-billing-button')), findsOneWidget);
    expect(find.byKey(const Key('subscribe-pro-button')), findsNothing);
    expect(find.byKey(const Key('subscribe-growth-button')), findsOneWidget);
  });
}
