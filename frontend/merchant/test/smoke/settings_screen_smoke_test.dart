import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/store/presentation/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen renders header, list, and logout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('云间小厨 · 静安店'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('店铺信息'), findsOneWidget);
  });
}
