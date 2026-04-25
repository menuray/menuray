/// Build-time application configuration.
///
/// All values resolve via `String.fromEnvironment` so they are baked into the
/// build artifact. Override at build/run time with
/// `--dart-define=KEY=VALUE`. Hot-reload of an env change requires a full
/// rebuild — this is a deliberate trade for a simple, dep-free indirection.
class AppConfig {
  const AppConfig._();

  /// The customer-facing host that serves published menus and the
  /// `/accept-invite` landing page. Default matches the historically
  /// hard-coded value so prod builds need no flag.
  static const String customerHost = String.fromEnvironment(
    'MENURAY_CUSTOMER_HOST',
    defaultValue: 'menu.menuray.com',
  );

  /// Public URL for a published menu identified by its slug.
  static String customerMenuUrl(String slug) =>
      'https://$customerHost/$slug';

  /// Public URL for accepting a pending store-member invite.
  static String customerInviteUrl(String token) =>
      'https://$customerHost/accept-invite?token=$token';
}
