import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// All sign-in goes through Google. There is no separate register flow:
/// the first Google sign-in creates the Supabase user, and a database trigger
/// (see supabase/migrations/) creates their profile row.
class AuthService {
  AuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool get isSignedIn =>
      SupabaseConfig.isConfigured && _client.auth.currentSession != null;

  static User? get currentUser =>
      SupabaseConfig.isConfigured ? _client.auth.currentUser : null;

  static Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  /// Opens Google's sign-in page. On web this leaves the app and comes back
  /// to [_redirectUrl] with the session, which Supabase picks up on startup.
  static Future<void> signInWithGoogle() async {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException(
        'Supabase is not configured. Run with --dart-define-from-file=.env',
      );
    }

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      // Always show the account chooser, so switching accounts is possible.
      queryParams: const {'prompt': 'select_account'},
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Where Google sends the player back. On the web: the page the app is
  /// served from, e.g. http://localhost:8080/ locally or
  /// `https://<user>.github.io/<repo>/` when deployed. In the Android app:
  /// [appCallback], which opens the app again (see AndroidManifest.xml).
  /// All of them must be listed under Authentication > URL Configuration >
  /// Redirect URLs in Supabase.
  static String get _redirectUrl =>
      kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : appCallback;

  static const String appCallback = 'com.cybernie://login-callback';
}
