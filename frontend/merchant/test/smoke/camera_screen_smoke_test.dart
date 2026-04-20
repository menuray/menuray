import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/capture/presentation/camera_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('CameraScreen renders without throwing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: zhMaterialApp(home: const CameraScreen())),
    );
    // One frame only — don't pumpAndSettle which would await the camera init
    // future that (in the test harness) throws because no camera is available.
    await tester.pump();
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}
