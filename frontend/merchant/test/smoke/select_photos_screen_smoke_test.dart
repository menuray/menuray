import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/capture/presentation/select_photos_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('SelectPhotosScreen renders title', (tester) async {
    await tester.pumpWidget(zhMaterialApp(home: const SelectPhotosScreen()));
    await tester.pump();
    expect(find.text('选择菜单图片'), findsOneWidget);
  });
}
