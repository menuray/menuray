import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/publish/presentation/custom_theme_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('CustomThemeScreen renders preview, controls, and CTA', (tester) async {
    await tester.pumpWidget(zhMaterialApp(home: const CustomThemeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('主题定制'), findsOneWidget);
    expect(find.text('保存并预览'), findsOneWidget);
    expect(find.text('主色'), findsOneWidget);
  });
}
