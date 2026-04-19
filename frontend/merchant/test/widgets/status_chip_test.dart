import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/shared/widgets/status_chip.dart';

void main() {
  testWidgets('renders label and adapts color per variant', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusChip(label: '已发布', variant: ChipVariant.published)),
    ));
    expect(find.text('已发布'), findsOneWidget);
  });
}
