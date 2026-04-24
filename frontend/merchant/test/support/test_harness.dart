import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:menuray_merchant/features/store/active_store_provider.dart';
import 'package:menuray_merchant/l10n/app_localizations.dart';
import 'package:menuray_merchant/shared/models/store_context.dart';

/// Wraps [home] in a Chinese Localizations scope so smoke tests — which
/// assert the pre-i18n Chinese copy verbatim — keep passing after the
/// migration. Replaces MaterialApp-level delegate wiring in tests.
MaterialApp zhMaterialApp({required Widget home}) => MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// Seeds [activeStoreProvider] with a StoreContext for [storeId]/[role] so
/// screens that read `currentStoreProvider` (which throws when the active
/// store is null) work under test.
class _TestActiveStoreNotifier extends ActiveStoreNotifier {
  _TestActiveStoreNotifier(super.ref, StoreContext ctx) {
    state = ctx;
  }
}

Override testActiveStoreOverride({
  String storeId = 'store-seed',
  String role = 'owner',
}) =>
    activeStoreProvider.overrideWith(
      (ref) => _TestActiveStoreNotifier(
        ref,
        StoreContext(storeId: storeId, role: role),
      ),
    );
