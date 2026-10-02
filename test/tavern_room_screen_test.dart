import 'package:final_project/screens/tavern_room_screen.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lays out the tavern (signed out, so no network) in a landscape phone and
/// in a portrait window where the room is drawn sideways, and opens the
/// "Who's here" panel and emote picker.
void main() {
  setUpAll(() async {
    // A tap that lands on something else (e.g. an overlapping button) fails.
    WidgetController.hitTestWarningShouldBeFatal = true;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
    );
  });

  for (final size in const [Size(844, 390), Size(667, 375), Size(390, 844)]) {
    testWidgets('tavern HUD lays out at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const TavernRoomScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Open "Who's here" from the player count.
      await tester.tap(find.text('1 / 20'));
      await tester.pump();
      expect(find.text("Who's here (1 / 20)"), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close it; chat and the emote picker come back.
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.tap(find.byTooltip('Emotes'));
      await tester.pump();
      expect(find.text('🎉'), findsOneWidget);
      expect(find.text('😠'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Leave the screen so the game's timers stop.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
