import 'package:final_project/screens/welcome_screen.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Renders Home signed out (no network) at real phone sizes and with large
/// text, and fails on any layout overflow or exception.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
    );
  });

  const sizes = {
    'iPhone 13': Size(390, 844),
    'small Android': Size(360, 640),
    'iPhone SE (1st gen)': Size(320, 568),
    'landscape phone': Size(844, 390),
  };

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Welcome lays out on ${entry.key} at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            routes: {'/profile': (_) => const SizedBox()},
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.value,
                textScaler: TextScaler.linear(scale),
              ),
              child: const WelcomeScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(find.text("ENTER BERNIE'S TAVERN"), findsOneWidget);
        expect(find.text('Welcome!'), findsOneWidget);
        expect(find.text('Find friends to hang out with'), findsOneWidget);
      });
    }
  }
}
