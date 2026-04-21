import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:menuray_merchant/l10n/app_localizations.dart';
import 'package:menuray_merchant/shared/validation.dart';

/// Loads an AppLocalizations instance for a given locale so we can pass it to
/// validators without spinning up a full widget tree.
Future<AppLocalizations> loadL10n(Locale locale) async {
  return AppLocalizations.delegate.load(locale);
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l = await loadL10n(const Locale('en'));
  });

  group('validateRequired', () {
    test('null → error', () => expect(validateRequired(null, l), isNotNull));
    test('empty → error', () => expect(validateRequired('', l), isNotNull));
    test('whitespace → error', () => expect(validateRequired('   ', l), isNotNull));
    test('non-empty → null', () => expect(validateRequired('hi', l), isNull));
    test('fieldLabel produces named error',
        () => expect(validateRequired('', l, fieldLabel: 'Phone'), contains('Phone')));
  });

  group('validatePhoneOrChineseMobile', () {
    test('empty → error', () => expect(validatePhoneOrChineseMobile('', l), isNotNull));
    test('11-digit China mobile → ok',
        () => expect(validatePhoneOrChineseMobile('13800001234', l), isNull));
    test('+86 China mobile → ok',
        () => expect(validatePhoneOrChineseMobile('+8613800001234', l), isNull));
    test('+1 US → ok', () => expect(validatePhoneOrChineseMobile('+14155551234', l), isNull));
    test('9-digit unprefixed → error',
        () => expect(validatePhoneOrChineseMobile('123456789', l), isNotNull));
    test('letters → error',
        () => expect(validatePhoneOrChineseMobile('+1415ABC1234', l), isNotNull));
    test('12-digit CN (wrong leading) → error',
        () => expect(validatePhoneOrChineseMobile('23800001234', l), isNotNull));
    test('whitespace-wrapped 11-digit → ok',
        () => expect(validatePhoneOrChineseMobile('  13800001234  ', l), isNull));
  });

  group('normalizePhone', () {
    test('11-digit CN → +86 prefix', () => expect(normalizePhone('13800001234'), '+8613800001234'));
    test('+ prefix kept', () => expect(normalizePhone('+14155551234'), '+14155551234'));
    test('trims whitespace', () => expect(normalizePhone('  13800001234  '), '+8613800001234'));
  });

  group('validatePriceNonNegative', () {
    test('empty → error', () => expect(validatePriceNonNegative('', l), isNotNull));
    test('zero → ok', () => expect(validatePriceNonNegative('0', l), isNull));
    test('10.99 → ok', () => expect(validatePriceNonNegative('10.99', l), isNull));
    test('negative → error', () => expect(validatePriceNonNegative('-1', l), isNotNull));
    test('letters → error', () => expect(validatePriceNonNegative('abc', l), isNotNull));
    test('3 decimals → error', () => expect(validatePriceNonNegative('10.999', l), isNotNull));
    test('1 decimal → ok', () => expect(validatePriceNonNegative('10.9', l), isNull));
  });

  group('validateMaxLength', () {
    test('null → ok', () => expect(validateMaxLength(null, l, max: 10), isNull));
    test('exactly max → ok',
        () => expect(validateMaxLength('a' * 10, l, max: 10), isNull));
    test('over max → error',
        () => expect(validateMaxLength('a' * 11, l, max: 10), isNotNull));
  });
}
