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
  });
}
