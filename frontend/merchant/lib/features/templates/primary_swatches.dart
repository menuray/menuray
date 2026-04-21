import 'package:flutter/material.dart';

/// 12 curated primary-color swatches offered in the select_template screen.
/// Must match frontend/customer/src/lib/templates/primarySwatches.ts exactly.
const List<String> kPrimarySwatchHex = <String>[
  '#2F5D50', // brand green (default)
  '#C2553F', // brick red
  '#E0A969', // amber
  '#1F4068', // navy
  '#3E6B89', // slate blue
  '#567D46', // olive
  '#8B4B66', // mulberry
  '#B56E2D', // burnt orange
  '#3E3E4E', // charcoal
  '#6B4E9E', // purple
  '#2E8B82', // teal
  '#6B1E2E', // wine
];

final List<Color> kPrimarySwatchColors = kPrimarySwatchHex.map(parseHexColor).toList(growable: false);

/// Parses a '#RRGGBB' hex string. Returns opaque black on malformed input.
Color parseHexColor(String hex) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (match == null) return const Color(0xFF000000);
  return Color(int.parse('FF${match.group(1)}', radix: 16));
}
