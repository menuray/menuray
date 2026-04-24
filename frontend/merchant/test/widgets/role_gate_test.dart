import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/store/active_store_provider.dart';
import 'package:menuray_merchant/shared/models/store_context.dart';
import 'package:menuray_merchant/shared/widgets/role_gate.dart';

class _FakeNotifier extends ActiveStoreNotifier {
  _FakeNotifier(super.ref, StoreContext? initial) {
    state = initial;
  }
}

Widget _harness({required StoreContext? ctx, required Widget child}) {
  return ProviderScope(
    overrides: [
      activeStoreProvider.overrideWith((ref) => _FakeNotifier(ref, ctx)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows child when role is allowed', (tester) async {
    await tester.pumpWidget(_harness(
      ctx: const StoreContext(storeId: 's', role: 'manager'),
      child: const RoleGate(
        allowed: {'owner', 'manager'},
        child: Text('write-action'),
      ),
    ));
    expect(find.text('write-action'), findsOneWidget);
  });

  testWidgets('hides child for staff', (tester) async {
    await tester.pumpWidget(_harness(
      ctx: const StoreContext(storeId: 's', role: 'staff'),
      child: const RoleGate(
        allowed: {'owner', 'manager'},
        child: Text('write-action'),
      ),
    ));
    expect(find.text('write-action'), findsNothing);
  });

  testWidgets('renders fallback when provided', (tester) async {
    await tester.pumpWidget(_harness(
      ctx: const StoreContext(storeId: 's', role: 'staff'),
      child: const RoleGate(
        allowed: {'owner'},
        fallback: Text('read-only'),
        child: Text('write-action'),
      ),
    ));
    expect(find.text('write-action'), findsNothing);
    expect(find.text('read-only'), findsOneWidget);
  });

  testWidgets('hides child when no active store', (tester) async {
    await tester.pumpWidget(_harness(
      ctx: null,
      child: const RoleGate(
        allowed: {'owner', 'manager', 'staff'},
        child: Text('write-action'),
      ),
    ));
    expect(find.text('write-action'), findsNothing);
  });
}
