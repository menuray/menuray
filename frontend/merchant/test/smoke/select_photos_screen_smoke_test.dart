import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/capture/presentation/select_photos_screen.dart';

void main() {
  testWidgets('SelectPhotosScreen renders title and next button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SelectPhotosScreen()));
    await tester.pumpAndSettle();
    expect(find.text('选择菜单图片'), findsOneWidget);
    expect(find.text('下一步 (3)'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
