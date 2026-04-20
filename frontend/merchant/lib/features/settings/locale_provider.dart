import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _hydrate();
  }

  static const _prefKey = 'app_locale';

  Future<void> _hydrate() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefKey) ?? 'system';
    state = _fromString(raw);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefKey,
      locale == null ? 'system' : locale.languageCode,
    );
  }

  static Locale? _fromString(String raw) => raw == 'zh'
      ? const Locale('zh')
      : raw == 'en'
      ? const Locale('en')
      : null;
}

final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());
