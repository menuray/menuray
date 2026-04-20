import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/edit/presentation/organize_menu_screen.dart';

void main() {
  testWidgets('OrganizeMenuScreen renders categories and dishes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrganizeMenuScreen(menuId: 'm1')));
    await tester.pumpAndSettle();
    expect(find.text('整理菜单'), findsOneWidget);
    expect(find.text('凉菜'), findsOneWidget);
    expect(find.text('宫保鸡丁'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
  });
}
