import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/store/presentation/store_management_screen.dart';

void main() {
  testWidgets('StoreManagementScreen renders title and store list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreManagementScreen()));
    await tester.pumpAndSettle();
    expect(find.text('门店管理'), findsOneWidget);
    expect(find.textContaining('云间小厨'), findsWidgets);  // matches all 3 stores
  });
}
