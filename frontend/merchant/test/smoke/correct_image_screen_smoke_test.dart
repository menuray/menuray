import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/capture/presentation/correct_image_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('CorrectImageScreen renders title, toolbar and next', (tester) async {
    await tester.pumpWidget(zhMaterialApp(home: const CorrectImageScreen()));
    // Use pump instead of pumpAndSettle because the loading spinner repeats forever
    await tester.pump();
    expect(find.text('校正图片 (1 / 3)'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('自动校正'), findsOneWidget);
  });
}
