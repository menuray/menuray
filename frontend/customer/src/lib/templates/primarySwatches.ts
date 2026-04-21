// 12 curated primary-color swatches offered in the merchant picker.
// Values must match frontend/merchant/lib/features/templates/primary_swatch_dart
// exactly — neither codebase imports from the other.
export const PRIMARY_SWATCHES: readonly string[] = [
  '#2F5D50',  // brand green (default)
  '#C2553F',  // brick red
  '#E0A969',  // amber
  '#1F4068',  // navy
  '#3E6B89',  // slate blue
  '#567D46',  // olive
  '#8B4B66',  // mulberry
  '#B56E2D',  // burnt orange
  '#3E3E4E',  // charcoal
  '#6B4E9E',  // purple
  '#2E8B82',  // teal
  '#6B1E2E',  // wine
];

const HEX_RE = /^#[0-9A-Fa-f]{6}$/;

/** Returns true iff s is a 6-digit hex color (case-insensitive, # required). */
export function isValidHex(s: unknown): s is string {
  return typeof s === 'string' && HEX_RE.test(s);
}
