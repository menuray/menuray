import 'package:flutter/material.dart';

/// Brand colors derived from docs/DESIGN.md
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2F5D50);      // 墨绿
  static const accent = Color(0xFFE0A969);       // 琥珀金
  static const surface = Color(0xFFFBF7F0);      // 暖米白
  static const ink = Color(0xFF1F1F1F);          // 深炭
  static const secondary = Color(0xFF6B7B6F);    // 灰绿
  static const success = Color(0xFF4A8A6E);
  static const warning = Color(0xFFE0A969);
  static const error = Color(0xFFC2553F);        // 砖红
  static const divider = Color(0xFFECE7DC);      // 暖灰

  /// Primary container — 用于 Stitch HTML 里的 primary-container（更亮的墨绿）
  static const primaryContainer = Color(0xFF2F5D50);

  /// 更深的墨绿，用于强对比按钮
  static const primaryDark = Color(0xFF154539);

  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primaryDark,
        primaryContainer: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: ink,
      );
}
