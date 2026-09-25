// A widget test: it builds your app in memory and checks what is on screen.
// Run them all with: flutter test
//
// You are not required to write more of these, but a project with a few real
// tests reads very differently from one with none.
 
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
 
import 'package:final_project/screens/splash_screen.dart';
import 'package:final_project/constants/app_strings.dart';
 
void main() {
  testWidgets('Splash screen shows the app name, tagline, and CTA',
      (tester) async {
    // Wrap SplashScreen in a MaterialApp, since it needs a Navigator,
    // Directionality, and Theme to build correctly on its own.
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );
 
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.tagline), findsOneWidget);
    expect(find.text(AppStrings.tapToContinue), findsOneWidget);
  });
}
 