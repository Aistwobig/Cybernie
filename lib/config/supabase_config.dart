/// Supabase connection values.
///
/// The defaults below are this project's URL and publishable key, so the app
/// connects however it is launched. Both are designed to be public (they ship
/// inside every web build anyway): the data is protected by the Row Level
/// Security policies in supabase/migrations/, not by these values.
///
/// To point at a different project, override them at build time:
///
///   flutter run --dart-define-from-file=.env
///
/// Never put the secret (service_role) key here.
class SupabaseConfig {
  static const String _defaultUrl = 'https://dfiownckxdvkbkxrrswa.supabase.co';
  static const String _defaultPublishableKey =
      'sb_publishable_EDRL0sSiGU9Y_k8BX7Rvzg_k5qA-TpB';

  // An empty define (e.g. a missing GitHub secret) also falls back.
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const String url = _envUrl == '' ? _defaultUrl : _envUrl;
  static const String publishableKey = _envPublishableKey == ''
      ? _defaultPublishableKey
      : _envPublishableKey;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
