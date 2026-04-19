import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_menu_merchant/features/capture/presentation/camera_screen.dart';

void main() {
  testWidgets('CameraScreen renders without throwing and shows main controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CameraScreen()));
    await tester.pumpAndSettle();
    // Shutter button + "完成 (3)" + close icon
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('完成 (3)'), findsOneWidget);
  });
}
