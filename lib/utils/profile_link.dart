import 'package:shared_preferences/shared_preferences.dart';

/// Links to a player's profile page, as put in their QR code:
/// `<this site>/#/player/<player id>`. Scanning it with any phone camera
/// opens the app on that profile.
class ProfileLink {
  ProfileLink._();

  static const String routePrefix = '/player/';

  /// The route for [playerId]'s profile page.
  static String route(String playerId) => '$routePrefix$playerId';

  /// The player id in [routeName], if it's a profile route.
  static String? playerIdIn(String? routeName) {
    if (routeName == null || !routeName.startsWith(routePrefix)) return null;
    final id = routeName
        .substring(routePrefix.length)
        .split(RegExp('[/?#]'))
        .first;
    return id.isEmpty ? null : id;
  }

  /// The live site, for when the app isn't running from a web address (the
  /// Android app).
  static const String liveSite = 'https://aistwobig.github.io/Cybernie/';

  /// The full web address of [playerId]'s profile: on this site in a
  /// browser, on [liveSite] in the app.
  static String url(String playerId) {
    final here = Uri.base;
    final base = here.scheme == 'http' || here.scheme == 'https'
        ? here
        : Uri.parse(liveSite);
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      fragment: route(playerId),
    ).toString();
  }

  // A scanned link opened while signed out is remembered until sign-in
  // (Google sends the player back to the site's front page, without it).
  static const String _pendingKey = 'pending_profile_link';

  static Future<void> savePending(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, playerId);
    } catch (_) {}
  }

  /// The remembered profile, if any (and forgets it).
  static Future<String?> takePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_pendingKey);
      if (id != null) await prefs.remove(_pendingKey);
      return id;
    } catch (_) {
      return null;
    }
  }
}
