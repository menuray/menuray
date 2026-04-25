import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('customerHost defaults to menu.menuray.com', () {
      expect(AppConfig.customerHost, 'menu.menuray.com');
    });

    test('customerMenuUrl composes host + slug with https scheme', () {
      expect(
        AppConfig.customerMenuUrl('foo-bar-2025'),
        'https://menu.menuray.com/foo-bar-2025',
      );
    });

    test('customerInviteUrl includes accept-invite path + token query', () {
      expect(
        AppConfig.customerInviteUrl('abc123'),
        'https://menu.menuray.com/accept-invite?token=abc123',
      );
    });
  });
}
