import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/shared/widgets/empty_state.dart';

void main() {
  testWidgets('shows message and triggers action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyState(
        message: '还没有菜单',
        actionLabel: '立即新建',
        onAction: () => tapped++,
      )),
    ));
    expect(find.text('还没有菜单'), findsOneWidget);
    await tester.tap(find.text('立即新建'));
    expect(tapped, 1);
  });
}
