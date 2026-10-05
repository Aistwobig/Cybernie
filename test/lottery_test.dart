import 'dart:math';

import 'package:final_project/screens/lottery_overlay.dart';
import 'package:final_project/services/coin_service.dart';
import 'package:final_project/services/lottery_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
    );
  });

  test('the chances add up to exactly 100%', () {
    final total = LotteryService.prizes.fold<double>(0, (s, p) => s + p.chance);
    expect(total, 100);
    // Every prize is on the wheel.
    expect(
      wheelSlices.toSet(),
      LotteryService.prizes.map((p) => p.coins).toSet(),
    );
  });

  test('each roll lands on the right prize', () {
    expect(LotteryService.draw(0), 1000);
    expect(LotteryService.draw(0.99), 1000);
    expect(LotteryService.draw(1), 500);
    expect(LotteryService.draw(2.99), 500);
    expect(LotteryService.draw(3), 200);
    expect(LotteryService.draw(7), 150);
    expect(LotteryService.draw(18), 100);
    expect(LotteryService.draw(39), 80);
    expect(LotteryService.draw(66), 50);
    expect(LotteryService.draw(99.99), 50);
  });

  test('over many spins, each prize comes up about as often as its chance', () {
    final random = Random(7);
    const spins = 200000;
    final counts = <int, int>{};
    var paid = 0;
    for (var i = 0; i < spins; i++) {
      final won = LotteryService.draw(random.nextDouble() * 100);
      counts[won] = (counts[won] ?? 0) + 1;
      paid += won;
    }
    for (final prize in LotteryService.prizes) {
      final percent = 100 * (counts[prize.coins] ?? 0) / spins;
      expect(percent, closeTo(prize.chance, 0.4), reason: '${prize.coins}');
    }
    // About 104 coins a spin on average.
    expect(paid / spins, closeTo(104, 2));
  });

  testWidgets('spinning the wheel lands on a prize and pays it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CoinService.coins.value = 100;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: LotteryOverlay(onClose: () => closed = true),
      ),
    );
    expect(find.text('SPIN'), findsWidgets);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('SPINNING...'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final won = CoinService.coins.value! - 100;
    expect(wheelSlices, contains(won));
    expect(find.text('You won $won coins!'), findsOneWidget);
    await tester.tap(find.text('COLLECT'));
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
