import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/manage/presentation/menu_management_screen.dart';

void main() {
  testWidgets('MenuManagementScreen renders title and quick actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MenuManagementScreen()));
    await tester.pumpAndSettle();
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('编辑内容'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
  });
}
