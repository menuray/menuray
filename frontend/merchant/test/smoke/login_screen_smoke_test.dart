import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders without throwing and shows wordmark + form',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Happy Menu'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('拍一张照，5 分钟生成电子菜单'), findsOneWidget);
  });
}
