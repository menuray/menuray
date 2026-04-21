import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/templates/data/template_repository.dart';
import 'package:menuray_merchant/features/templates/presentation/select_template_screen.dart';

import '../support/test_harness.dart';

const _templates = <Template>[
  Template(
    id: 'minimal',
    name: 'Minimal',
    description: 'Clean single column.',
    previewImageUrl: '/templates/minimal.png',
    isLaunch: true,
  ),
  Template(
    id: 'grid',
    name: 'Grid',
    description: 'Photo cards.',
    previewImageUrl: '/templates/grid.png',
    isLaunch: true,
  ),
  Template(
    id: 'bistro',
    name: 'Bistro',
    description: 'Coming soon.',
    previewImageUrl: null,
    isLaunch: false,
  ),
  Template(
    id: 'izakaya',
    name: 'Izakaya',
    description: 'Coming soon.',
    previewImageUrl: null,
    isLaunch: false,
  ),
  Template(
    id: 'street',
    name: 'Street',
    description: 'Coming soon.',
    previewImageUrl: null,
    isLaunch: false,
  ),
];

Widget _harness(Widget child) => ProviderScope(
      overrides: [
        templateListProvider.overrideWith((ref) async => _templates),
      ],
      child: zhMaterialApp(home: child),
    );

void main() {
  testWidgets('renders 2 launch templates + 3 coming-soon placeholders',
      (tester) async {
    await tester.pumpWidget(_harness(const SelectTemplateScreen(menuId: 'm1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Bistro'), findsOneWidget);
    expect(find.text('Izakaya'), findsOneWidget);
    expect(find.text('Street'), findsOneWidget);
    // ZH label for "Coming soon" is "即将推出"; 3 non-launch templates.
    expect(find.text('即将推出'), findsNWidgets(3));
  });

  testWidgets('tapping a swatch updates selection indicator', (tester) async {
    await tester.pumpWidget(_harness(const SelectTemplateScreen(menuId: 'm1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // No swatch selected initially.
    expect(find.byIcon(Icons.check), findsNothing);

    // Swatches are below the template grid; scroll down to reveal them.
    await tester.scrollUntilVisible(
      find.byKey(const Key('swatch-#C2553F')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Tap the #C2553F swatch via its stable Key.
    await tester.tap(find.byKey(const Key('swatch-#C2553F')));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
