import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/publish/presentation/select_template_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('SelectTemplateScreen renders header, tabs, and templates', (tester) async {
    await tester.pumpWidget(zhMaterialApp(home: const SelectTemplateScreen()));
    await tester.pumpAndSettle();
    expect(find.text('选择模板'), findsOneWidget);
    expect(find.text('使用此模板'), findsOneWidget);
    expect(find.text('墨意'), findsOneWidget);
  });
}
