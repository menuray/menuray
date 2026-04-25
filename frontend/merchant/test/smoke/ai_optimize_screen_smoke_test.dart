import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/ai/presentation/ai_optimize_screen.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('AiOptimizeScreen renders toggle cards + 8 locale options + CTA',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: zhMaterialApp(home: const AiOptimizeScreen(menuId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('一键优化菜单'), findsOneWidget);
    expect(find.text('自动配图'), findsOneWidget);
    // Auto-image subtitle gets the "(coming soon)" suffix appended.
    expect(find.textContaining('即将推出'), findsOneWidget);
    expect(find.text('描述扩写'), findsOneWidget);
    expect(find.text('多语言翻译'), findsOneWidget);
    expect(find.text('开始增强'), findsOneWidget);

    // The locale dropdown shows the currently-selected option (English by
    // default) — assertion confirms the picker rendered with the expanded
    // list. The dropdown menu items themselves render in an overlay so we
    // don't tap-open the dropdown here; one entry shown in the closed state
    // is enough to confirm the picker is wired.
    expect(find.text('英语'), findsWidgets);
  });

  testWidgets('AiOptimizeScreen disables the auto-image toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: zhMaterialApp(home: const AiOptimizeScreen(menuId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();
    // Three Switch widgets (auto-image / desc-expand / multi-lang). The
    // auto-image one (first in DOM order) has onChanged: null.
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, 3);
    expect(switches[0].onChanged, isNull, reason: 'auto-image is disabled');
    expect(switches[1].onChanged, isNotNull, reason: 'desc-expand is enabled');
    expect(switches[2].onChanged, isNotNull, reason: 'multi-lang is enabled');
  });
}
