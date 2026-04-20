import 'package:flutter/material.dart';
import 'package:menuray_merchant/l10n/app_localizations.dart';

/// Wraps [home] in a Chinese Localizations scope so smoke tests — which
/// assert the pre-i18n Chinese copy verbatim — keep passing after the
/// migration. Replaces MaterialApp-level delegate wiring in tests.
MaterialApp zhMaterialApp({required Widget home}) => MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
