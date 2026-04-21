import 'package:menuray_merchant/l10n/app_localizations.dart';

/// Returns null if non-empty (after trim); else localized error.
/// If [fieldLabel] is provided, returns "{fieldLabel} is required".
String? validateRequired(String? value, AppLocalizations l, {String? fieldLabel}) {
  if (value == null || value.trim().isEmpty) {
    return fieldLabel != null
        ? l.validationRequiredFieldNamed(fieldLabel)
        : l.validationRequired;
  }
  return null;
}

/// Accepts either an 11-digit Chinese mobile starting with 1, or a full E.164
/// number (+ followed by 7-15 digits, first digit 1-9). Returns localized error
/// otherwise. Empty input is treated as required.
String? validatePhoneOrChineseMobile(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final v = raw.trim();
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return null;
  if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v)) return null;
  return l.validationPhoneInvalid;
}

/// Canonicalizes the user input into E.164 form. 11-digit CN → '+86…';
/// anything else trimmed and returned as-is. Callers pass this to
/// Supabase signInWithOtp.
String normalizePhone(String raw) {
  final v = raw.trim();
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return '+86$v';
  return v;
}

/// Returns null for a non-negative decimal with at most 2 fractional digits.
String? validatePriceNonNegative(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final t = raw.trim();
  final d = double.tryParse(t);
  if (d == null) return l.validationPriceInvalid;
  if (d < 0) return l.validationPriceNegative;
  final parts = t.split('.');
  if (parts.length == 2 && parts[1].length > 2) return l.validationPriceTooPrecise;
  return null;
}

/// Returns null if [raw] is null or within [max] characters; else localized error.
/// Required-ness should be checked separately via [validateRequired].
String? validateMaxLength(String? raw, AppLocalizations l, {required int max}) {
  if (raw == null) return null;
  if (raw.length > max) return l.validationMaxLength(max);
  return null;
}
