import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/settings/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class HappyMenuApp extends ConsumerWidget {
  const HappyMenuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MenuRay',
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: ref.watch(localeNotifierProvider),
    );
  }
}
