import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/merchant_bottom_nav.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('reports tap with selected tab', (tester) async {
    MerchantTab? tapped;
    await tester.pumpWidget(zhMaterialApp(
      home: Scaffold(body: MerchantBottomNav(current: MerchantTab.menus, onTap: (t) => tapped = t)),
    ));
    await tester.tap(find.text('Data'));
    expect(tapped, MerchantTab.data);
  });
}
