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

  /// How long switching tabs takes.
  static const Duration tabTransition = Duration(milliseconds: 220);

  /// The page route for a tab screen: a quick cross-fade instead of the
  /// default zoom, so the bottom bar (in the same place on every tab) stays
  /// still and only the content changes.
  static Route<void> tabRoute(RouteSettings settings, WidgetBuilder builder) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: tabTransition,
      reverseTransitionDuration: tabTransition,
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  /// Opens the Friends or Profile tab directly on top of Welcome, replacing
  /// whichever tab was open.
  static void goToTab(BuildContext context, String route) {
    final navigator = Navigator.of(context);
    final leaving = ModalRoute.of(context);
    navigator.pushNamed(route);
    // Keep the old tab underneath until the new one has faded in fully, so
    // Home never flashes through between two tabs.
    if (leaving != null && leaving.settings.name != home) {
      Future<void>.delayed(tabTransition * 1.5, () {
        if (leaving.isActive) navigator.removeRoute(leaving);
      });
    }
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
