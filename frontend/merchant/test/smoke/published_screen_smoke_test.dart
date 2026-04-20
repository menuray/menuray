import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/publish/presentation/published_screen.dart';

void main() {
  testWidgets('PublishedScreen renders success heading and CTAs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PublishedScreen(menuId: 'm1')));
    await tester.pumpAndSettle();
    expect(find.text('菜单已发布！'), findsOneWidget);
    expect(find.text('返回菜单首页'), findsOneWidget);
    expect(find.text('保存二维码'), findsOneWidget);
    expect(find.text('导出 PDF'), findsOneWidget);
  });
}
