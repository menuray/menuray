import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/publish/presentation/preview_menu_screen.dart';

void main() {
  testWidgets('PreviewMenuScreen renders title, segments, and CTAs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PreviewMenuScreen()));
    await tester.pumpAndSettle();
    expect(find.text('预览'), findsOneWidget);
    expect(find.text('发布菜单'), findsOneWidget);
    expect(find.text('返回编辑'), findsOneWidget);
  });
}
