import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

  /// The direction of the latest tab switch: +1 when the new tab comes in
  /// from the right (picking a tab to the right on the bar), -1 when it
  /// comes in from the left (picking a tab to the left).
  /// Null until the first switch; until then tab screens just fade (e.g.
  /// Home after login).
  static int? _slideFrom;

  static void _startSlide(int from) => _slideFrom = from;

  /// Back to the Welcome screen: reuses it if it's underneath, otherwise
  /// makes it the only screen.
  static void goHome(BuildContext context) {
    // From a tab, Home is to the left: it comes in from the left.
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
  /// tabs slides like swiping between pages: picking a tab to the right
  /// brings the new screen in from the right edge, pushing the old one off
  /// to the left; picking one to the left does the opposite.
  static Route<void> tabRoute(RouteSettings settings, WidgetBuilder builder) {
    return _TabRoute(
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
    // Keep the old tab underneath until the new one has slid in fully, so
    // Home never shows through between two tabs; the new tab's route
    // removes it then.
    _replacing = leaving != null && leaving.settings.name != home
        ? leaving
        : null;
    navigator.pushNamed(route);
    // A tab route takes [_replacing] as it's pushed. Any other kind of route
    // doesn't, so remove the old tab once the usual transition is over.
    final replacing = _replacing;
    _replacing = null;
    if (replacing != null) {
      Future<void>.delayed(tabTransition * 1.5, () {
        if (replacing.isActive) navigator.removeRoute(replacing);
      });
    }
  }

  /// The tab being switched away from, handed to the next tab route.
  static Route<dynamic>? _replacing;

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

/// A tab's page route. The first frame of a freshly opened tab can be slow
/// to build (images, fonts, lists), and the animation clock keeps running
/// meanwhile, so the slide would jump straight to the end. It waits at the
/// start until that frame is on screen, then plays in full.
class _TabRoute extends PageRouteBuilder<void> {
  _TabRoute({
    super.settings,
    required super.pageBuilder,
    required super.transitionsBuilder,
    super.transitionDuration,
    super.reverseTransitionDuration,
  });

  @override
  TickerFuture didPush() {
    final pushed = super.didPush();
    final controller = this.controller;

    // Remove the tab we're replacing once we've fully covered it.
    final replacing = AppNav._replacing;
    AppNav._replacing = null;
    if (replacing != null && controller != null) {
      void removeWhenCovered(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        controller.removeStatusListener(removeWhenCovered);
        if (replacing.isActive) navigator?.removeRoute(replacing);
      }

      controller.addStatusListener(removeWhenCovered);
    }

    if (controller != null && AppNav._slideFrom != null) {
      controller
        ..stop(canceled: false)
        ..value = 0;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (isActive && !controller.isCompleted) controller.forward();
      });
    }
    return pushed;
  }
}
