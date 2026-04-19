import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/menu_card.dart';
import 'package:menuray_merchant/shared/mock/mock_data.dart';

void main() {
  testWidgets('shows menu name, view count and status chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MenuCard(menu: MockData.lunchMenu)),
    ));
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('1247 次访问'), findsOneWidget);
    expect(find.text('已发布'), findsOneWidget);
  });

  testWidgets('draft variant uses draft chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MenuCard(menu: MockData.brunchMenu)),
    ));
    expect(find.text('草稿'), findsOneWidget);
  });
}
