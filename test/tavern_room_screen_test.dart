import 'package:final_project/screens/tavern_room_screen.dart';
import 'package:final_project/services/sfx_service.dart';
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
    // No audio plugin in tests.
    SfxService.volume.value = 0;
    // The test waits in real time for the loading screen, which lets
    // google_fonts try to download fonts; tests have no network, so ignore
    // just those failures.
    final report = reportTestException;
    reportTestException = (details, description) {
      if (details.exception.toString().contains('Failed to load font')) return;
      report(details, description);
    };
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

      // The loading screen covers the room until everything has loaded.
      final loading = find.byKey(const Key('tavern-loading'));
      expect(loading, findsOneWidget);
      for (var i = 0; i < 60 && loading.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(loading, findsNothing, reason: 'the room is ready and shown');

      // A free spin is waiting, so Bernie's wheel pops up; put it off.
      for (
        var i = 0;
        i < 10 && find.text('Maybe later').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Maybe later'));
      await tester.pump();
      expect(find.text('Free spin!'), findsOneWidget);
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
      // All eight pictures fit in the row at this size.
      expect(find.byTooltip('Wave'), findsOneWidget);
      expect(find.byTooltip('Crying'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('emote_'),
        ),
        findsNWidgets(8),
      );
      expect(tester.takeException(), isNull);

      // Leave the screen so the game's timers stop.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
