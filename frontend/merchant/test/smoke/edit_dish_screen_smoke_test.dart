import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/edit/presentation/edit_dish_screen.dart';

void main() {
  testWidgets('EditDishScreen renders form with prefilled values', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditDishScreen()));
    await tester.pumpAndSettle();
    expect(find.text('编辑菜品'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // Some form values should be visible
    expect(find.text('宫保鸡丁'), findsWidgets); // appears in TextField + maybe label
  });
}
