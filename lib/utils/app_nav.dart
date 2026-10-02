import 'package:flutter/material.dart';

/// Moving between the bottom-nav tabs (Home, Friends, Profile).
///
/// The screen stack is always Welcome at the bottom with at most one tab on
/// top, so going "back" can never land on the splash or login screens.
class AppNav {
  AppNav._();

  static const String home = '/welcome';

  /// Lets a screen know when it becomes visible again (RouteAware), e.g.
  /// Home refreshing your name after Profile, or the tavern count.
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// Back to the Welcome screen: reuses it if it's underneath, otherwise
  /// makes it the only screen.
  static void goHome(BuildContext context) {
    final navigator = Navigator.of(context);
    var found = false;
    navigator.popUntil((route) {
      if (route.settings.name == home) {
        found = true;
        return true;
      }
      return route.isFirst;
    });
    if (!found) navigator.pushNamedAndRemoveUntil(home, (_) => false);
  }

  /// Opens the Friends or Profile tab directly on top of Welcome, replacing
  /// whichever tab was open.
  static Future<void> goToTab(BuildContext context, String route) {
    return Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(route, (r) => r.settings.name == home);
  }

  /// Leaves a screen opened from Home (e.g. Select Room). Goes home instead
  /// if there's nothing to go back to.
  static void back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      goHome(context);
    }
  }
}
