import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/billing_providers.dart';
import 'package:menuray_merchant/features/billing/tier.dart';
import 'package:menuray_merchant/shared/widgets/tier_gate.dart';

Widget _harness({required Tier? tier, required Widget child}) {
  return ProviderScope(
    overrides: [
      currentTierProvider.overrideWith(
        (ref) async => tier ?? Tier.free,
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows child when tier is allowed', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.pro,
      child: const TierGate(
        allowed: {Tier.pro, Tier.growth},
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsOneWidget);
  });

  testWidgets('hides child for free tier', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.free,
      child: const TierGate(
        allowed: {Tier.pro, Tier.growth},
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsNothing);
  });

  testWidgets('renders fallback when provided', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.free,
      child: const TierGate(
        allowed: {Tier.pro},
        fallback: Text('upgrade-callout'),
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsNothing);
    expect(find.text('upgrade-callout'), findsOneWidget);
  });
}
