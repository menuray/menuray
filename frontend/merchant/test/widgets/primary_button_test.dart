import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/primary_button.dart';

void main() {
  testWidgets('shows label and triggers onPressed', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrimaryButton(label: '登录', onPressed: () => tapped++)),
    ));
    expect(find.text('登录'), findsOneWidget);
    await tester.tap(find.text('登录'));
    expect(tapped, 1);
  });

  testWidgets('shows spinner and disables tap when loading', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrimaryButton(label: 'X', loading: true, onPressed: () => tapped++)),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(tapped, 0);
  });
}
