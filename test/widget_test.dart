// A widget test: it builds your app in memory and checks what is on screen.
// Run them all with: flutter test
//
// You are not required to write more of these, but a project with a few real
// tests reads very differently from one with none.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/main.dart';

void main() {
  testWidgets('home screen shows its title and counts taps', (tester) async {
    // Build the app. Note we build MyApp directly, not the DevicePreview
    // wrapper, because a test does not need the phone frame.
    await tester.pumpWidget(const MyApp());

    expect(find.text('It works'), findsOneWidget);
    expect(find.text('Taps: 0'), findsOneWidget);

    // Tap the button, then let the widget rebuild.
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Taps: 1'), findsOneWidget);
  });
}
