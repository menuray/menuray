import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/ai/presentation/ai_optimize_screen.dart';

void main() {
  testWidgets('AiOptimizeScreen renders all toggle cards and CTA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiOptimizeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('一键优化菜单'), findsOneWidget);
    expect(find.text('自动配图'), findsOneWidget);
    expect(find.text('描述扩写'), findsOneWidget);
    expect(find.text('多语言翻译'), findsOneWidget);
    expect(find.text('开始增强'), findsOneWidget);
  });
}
