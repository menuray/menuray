import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/publish/presentation/select_template_screen.dart';

void main() {
  testWidgets('SelectTemplateScreen renders header, tabs, and templates', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SelectTemplateScreen()));
    await tester.pumpAndSettle();
    expect(find.text('选择模板'), findsOneWidget);
    expect(find.text('使用此模板'), findsOneWidget);
    expect(find.text('墨意'), findsOneWidget);
  });
}
