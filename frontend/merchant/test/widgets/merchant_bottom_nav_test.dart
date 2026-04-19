import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/shared/widgets/merchant_bottom_nav.dart';

void main() {
  testWidgets('reports tap with selected tab', (tester) async {
    MerchantTab? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MerchantBottomNav(current: MerchantTab.menus, onTap: (t) => tapped = t)),
    ));
    await tester.tap(find.text('Data'));
    expect(tapped, MerchantTab.data);
  });
}
