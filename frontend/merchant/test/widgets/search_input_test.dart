// test/widgets/search_input_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/shared/widgets/search_input.dart';

void main() {
  testWidgets('shows hint and reports text changes', (tester) async {
    String? typed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SearchInput(onChanged: (v) => typed = v)),
    ));
    expect(find.text('搜索菜单、菜品或状态…'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '宫保');
    expect(typed, '宫保');
  });
}
