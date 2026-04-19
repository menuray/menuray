import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders header, search, menu list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('云间小厨'), findsOneWidget);
    expect(find.text('Curated Menus'), findsOneWidget);
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('新建菜单'), findsOneWidget);
  });
}
