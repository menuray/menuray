import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/dish_row.dart';
import 'package:menuray_merchant/shared/models/dish.dart';

void main() {
  testWidgets('shows name and price', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DishRow(dish: Dish(id: 'x', name: '宫保鸡丁', price: 48))),
    ));
    expect(find.text('宫保鸡丁'), findsOneWidget);
    expect(find.text('¥48'), findsOneWidget);
  });

  testWidgets('low confidence shows help icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DishRow(dish: Dish(id: 'y', name: '川北凉粉', price: 22, confidence: DishConfidence.low))),
    ));
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });
}
