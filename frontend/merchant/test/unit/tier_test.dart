import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/tier.dart';

void main() {
  group('TierX.fromString', () {
    test('maps known strings', () {
      expect(TierX.fromString('free'), Tier.free);
      expect(TierX.fromString('pro'), Tier.pro);
      expect(TierX.fromString('growth'), Tier.growth);
    });
    test('falls back to free on null/unknown', () {
      expect(TierX.fromString(null), Tier.free);
      expect(TierX.fromString('something-else'), Tier.free);
    });
  });

  group('TierX.isPaid / isGrowth', () {
    test('isPaid', () {
      expect(Tier.free.isPaid, false);
      expect(Tier.pro.isPaid, true);
      expect(Tier.growth.isPaid, true);
    });
    test('isGrowth', () {
      expect(Tier.free.isGrowth, false);
      expect(Tier.pro.isGrowth, false);
      expect(Tier.growth.isGrowth, true);
    });
  });

  group('TierX.apiName', () {
    test('round-trips', () {
      for (final t in Tier.values) {
        expect(TierX.fromString(t.apiName), t);
      }
    });
  });
}
