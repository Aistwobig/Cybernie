import 'dart:async';

import 'package:flutter/material.dart';

/// Moving between the bottom-nav tabs (Home, Friends, Profile).
///
/// The screen stack is always Welcome at the bottom with at most one tab on
/// top, so going "back" can never land on the splash or login screens.
class AppNav {
  AppNav._();

  static const String home = '/welcome';

  /// The bottom-nav tabs, left to right.
  static const List<String> tabs = [home, '/friends', '/profile'];

  /// Lets a screen know when it becomes visible again (RouteAware), e.g.
  /// Home refreshing your name after Profile, or the tavern count.
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// How long switching tabs takes.
  static const Duration tabTransition = Duration(milliseconds: 300);

  /// While a tab switch is running: +1 when the new tab comes in from the
  /// right (moving right along the bar), -1 when it comes in from the left.
  /// Null otherwise, and tab screens just fade (e.g. Home after login).
  static int? _slideFrom;
  static Timer? _slideEnd;

  static void _startSlide(int from) {
    _slideFrom = from;
    _slideEnd?.cancel();
    _slideEnd = Timer(tabTransition * 2, () => _slideFrom = null);
  }

  /// Back to the Welcome screen: reuses it if it's underneath, otherwise
  /// makes it the only screen.
  static void goHome(BuildContext context) {
    // From a tab, Home is to the left: slide the tab away to the right.
    if (tabs.contains(ModalRoute.of(context)?.settings.name)) _startSlide(-1);
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

  /// The page route for a tab screen (Home, Friends, Profile). Switching
  /// tabs slides like swiping between pages, in the direction of the tab
  /// you picked: the new screen pushes the old one off the other side.
  static Route<void> tabRoute(RouteSettings settings, WidgetBuilder builder) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: tabTransition,
      reverseTransitionDuration: tabTransition,
      pageBuilder: (context, _, _) => builder(context),
      // Called on every animation frame, so it follows the current switch.
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final from = _slideFrom;
        if (from == null) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        }
        const curve = Curves.easeOutCubic;
        // This screen arriving (or, when popped, leaving the other way).
        final ownSide = animation.status == AnimationStatus.reverse
            ? -from
            : from;
        // This screen being pushed off by the next one (or coming back).
        final coveredSide = secondaryAnimation.status == AnimationStatus.reverse
            ? from
            : -from;
        final dx =
            ownSide * (1 - curve.transform(animation.value)) +
            coveredSide * curve.transform(secondaryAnimation.value);
        return FractionalTranslation(translation: Offset(dx, 0), child: child);
      },
    );
  }

  /// Opens the Friends or Profile tab directly on top of Welcome, replacing
  /// whichever tab was open.
  static void goToTab(BuildContext context, String route) {
    final navigator = Navigator.of(context);
    final leaving = ModalRoute.of(context);
    final fromIndex = tabs.indexOf(leaving?.settings.name ?? home);
    _startSlide(tabs.indexOf(route) > fromIndex ? 1 : -1);
    navigator.pushNamed(route);
    // Keep the old tab underneath until the new one has slid in fully, so
    // Home never shows through between two tabs.
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
