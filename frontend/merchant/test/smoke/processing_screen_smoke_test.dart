import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/capture/presentation/processing_screen.dart';

void main() {
  testWidgets('ProcessingScreen renders title and buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProcessingScreen()));
    await tester.pump(); // initial frame, don't await timer
    expect(find.text('正在识别菜品结构...'), findsOneWidget);
    expect(find.text('后台运行'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
