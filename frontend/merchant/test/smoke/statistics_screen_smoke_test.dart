import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/manage/presentation/statistics_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('StatisticsScreen renders title and Top 1 dish', (tester) async {
    await tester.pumpWidget(zhMaterialApp(home: const StatisticsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('宫保鸡丁'), findsOneWidget);
    expect(find.text('每日访问量'), findsOneWidget);
  });
}
