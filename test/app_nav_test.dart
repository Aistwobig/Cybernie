import 'package:final_project/utils/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with buttons for each bottom-nav action.
class _Screen extends StatelessWidget {
  const _Screen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('screen:$label'),
          TextButton(
            onPressed: () => AppNav.goHome(context),
            child: const Text('home'),
          ),
          TextButton(
            onPressed: () => AppNav.goToTab(context, '/friends'),
            child: const Text('friends'),
          ),
          TextButton(
            onPressed: () => AppNav.goToTab(context, '/profile'),
            child: const Text('profile'),
          ),
          TextButton(
            onPressed: () => AppNav.back(context),
            child: const Text('back'),
          ),
        ],
      ),
    );
  }
}

void main() {
  // Mimics Flutter's default start for a signed-in player: the splash
  // screen ('/') sits underneath Welcome.
  Widget app() => MaterialApp(
    initialRoute: '/welcome',
    routes: {
      '/': (_) => const _Screen('splash'),
      '/welcome': (_) => const _Screen('welcome'),
      '/friends': (_) => const _Screen('friends'),
      '/profile': (_) => const _Screen('profile'),
    },
  );

  Future<void> tap(WidgetTester tester, String button) async {
    await tester.tap(find.text(button).last);
    await tester.pumpAndSettle();
  }

  testWidgets('switching tabs never lands on the splash screen', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.text('screen:welcome'), findsOneWidget);

    // Welcome -> Friends -> Profile -> Friends -> Home
    await tap(tester, 'friends');
    expect(find.text('screen:friends'), findsOneWidget);
    await tap(tester, 'profile');
    expect(find.text('screen:profile'), findsOneWidget);
    await tap(tester, 'friends');
    expect(find.text('screen:friends'), findsOneWidget);
    await tap(tester, 'home');
    expect(find.text('screen:welcome'), findsOneWidget);

    // Profile -> back also returns to Welcome, not the splash.
    await tap(tester, 'profile');
    await tap(tester, 'back');
    expect(find.text('screen:welcome'), findsOneWidget);
    expect(find.text('screen:splash'), findsNothing);

    // The tab you left is gone once the next one has faded in: back from
    // Profile (opened from Friends) goes home, not to Friends.
    await tap(tester, 'friends');
    await tap(tester, 'profile');
    await tester.pump(AppNav.tabTransition * 2);
    await tap(tester, 'back');
    expect(find.text('screen:welcome'), findsOneWidget);
  });

  testWidgets('tabs slide toward the side of the tab you pick', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/welcome',
        onGenerateRoute: (settings) => AppNav.tabRoute(
          settings,
          (_) => _Screen(settings.name!.substring(1)),
        ),
      ),
    );
    double x(String screen) => tester.getTopLeft(find.text(screen)).dx;

    // Starts a switch and stops halfway through it.
    Future<void> halfway(String button) async {
      await tester.tap(find.text(button).last);
      // The new tab's first frame; the slide starts once it's drawn.
      await tester.pump();
      await tester.pump();
      await tester.pump(AppNav.tabTransition ~/ 2);
    }

    Future<void> finish() async {
      await tester.pumpAndSettle();
      await tester.pump(AppNav.tabTransition * 2);
    }

    // Home -> Friends: Friends comes in from the right edge, pushing Home
    // off to the left.
    await halfway('friends');
    expect(x('screen:friends'), greaterThan(0));
    expect(x('screen:welcome'), lessThan(0));
    await finish();

    // Friends -> Profile: same way. Home never shows in between.
    await halfway('profile');
    expect(x('screen:profile'), greaterThan(0));
    expect(x('screen:friends'), lessThan(0));
    expect(find.text('screen:welcome'), findsNothing);
    await finish();

    // Profile -> Friends: the other way; Friends comes in from the left.
    await halfway('friends');
    expect(x('screen:friends'), lessThan(0));
    expect(x('screen:profile'), greaterThan(0));
    await finish();

    // Friends -> Profile again, with a slow first frame for the new screen
    // (like a freshly built tab in a debug build): the slide still plays in
    // full afterwards instead of being skipped.
    await tester.tap(find.text('profile').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(AppNav.tabTransition ~/ 2);
    expect(x('screen:profile'), greaterThan(0));
    expect(x('screen:friends'), lessThan(0));
    await finish();
    await halfway('friends');
    await finish();

    // Friends -> Home: Home comes back in from the left.
    await halfway('home');
    expect(x('screen:welcome'), lessThan(0));
    expect(x('screen:friends'), greaterThan(0));
    await finish();
    expect(find.text('screen:welcome'), findsOneWidget);
    expect(x('screen:welcome'), 0);
  });
}
