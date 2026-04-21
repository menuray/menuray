import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/loading_view.dart';

void main() {
  testWidgets('renders a CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingView()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders label when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingView(label: 'Loading…')),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });
}
