import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/error_view.dart';

void main() {
  testWidgets('renders message + error icon, no button when onRetry absent',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorView(message: 'Boom')),
    );
    expect(find.text('Boom'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('renders button when onRetry provided; tapping invokes it',
      (tester) async {
    int calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: ErrorView(
        message: 'Boom',
        retryLabel: 'Try again',
        onRetry: () => calls++,
      ),
    ));
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(calls, 1);
  });
}
