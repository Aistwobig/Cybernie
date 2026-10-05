import 'package:final_project/models/blackjack.dart';
import 'package:final_project/screens/blackjack_overlay.dart';
import 'package:final_project/services/blackjack_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Cards: hearts are 0 (ace) to 12 (king), so 4 is a five, 9 a ten.
const ace = 0, five = 4, six = 5, seven = 6, nine = 8, ten = 9, king = 12;

/// The local table deals player, dealer, player, dealer, then draws in order.
LocalBlackjackTable tableWith(List<int> deck) =>
    LocalBlackjackTable(coins: 500, deck: deck);

void main() {
  test('hand values count aces as 11 or 1', () {
    expect(handValue([ace, king]), 21);
    expect(handValue([ace, ace, nine]), 21);
    expect(handValue([ace, ace, ace]), 13);
    expect(handValue([king, 11, 1]), 22);
    expect(handValue([five, hiddenCard]), 5);
    expect(isBlackjack([ace, king]), isTrue);
    expect(isBlackjack([seven, seven, seven]), isFalse);
    // Suits are rows of the card sheet: 13 is the ace of diamonds.
    expect(cardSuit(13), 1);
    expect(cardRank(13), 0);
  });

  test('a natural blackjack pays 3 to 2 straight away', () async {
    final table = tableWith([ace, five, king, nine]);
    final state = await table.deal(100);
    expect(state.hand!.playing, isFalse);
    expect(state.hand!.outcome, BlackjackOutcome.blackjack);
    expect(state.coins, 500 - 100 + 250);
  });

  test("Bernie's second card stays hidden until the hand ends", () async {
    final table = tableWith([ten, five, six, nine, king]);
    var state = await table.deal(50);
    expect(state.hand!.dealer, [five, hiddenCard]);
    expect(state.coins, 450);
    // 16 + a king busts.
    state = await table.hit();
    expect(state.hand!.outcome, BlackjackOutcome.bust);
    expect(state.hand!.dealer, [five, nine]);
    expect(state.coins, 450);
  });

  test('standing makes Bernie draw to 17; his bust pays double', () async {
    final table = tableWith([ten, five, six, nine, king]);
    await table.deal(50);
    final state = await table.stand();
    expect(state.hand!.dealer, [five, nine, king]);
    expect(state.hand!.outcome, BlackjackOutcome.dealerBust);
    expect(state.coins, 450 + 100);
  });

  test('doubling doubles the bet and takes one card', () async {
    // 11 against Bernie's 17; the nine makes 20.
    final table = tableWith([five, ten, six, seven, nine]);
    await table.deal(50);
    final state = await table.doubleDown();
    expect(state.hand!.player, [five, six, nine]);
    expect(state.hand!.bet, 100);
    expect(state.hand!.outcome, BlackjackOutcome.win);
    expect(state.coins, 500 - 100 + 200);
  });

  test('a tie gives the bet back; bad bets are refused', () async {
    final table = tableWith([ten, ten, seven, seven]);
    await table.deal(30);
    final state = await table.stand();
    expect(state.hand!.outcome, BlackjackOutcome.push);
    expect(state.coins, 500);
    expect(() => table.deal(5), throwsArgumentError);
    expect(() => table.deal(600), throwsArgumentError);
  });

  for (final size in const [Size(844, 390), Size(667, 375), Size(1280, 720)]) {
    testWidgets('the table plays a hand at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: BlackjackOverlay(
            table: tableWith([ten, five, six, nine, king]),
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('DEAL'), findsOneWidget);
      expect(find.byType(PlayingCardView), findsNothing);

      // Bernie shuffles first (about a second), then deals.
      await tester.tap(find.text('DEAL'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PlayingCardView), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(PlayingCardView), findsNWidgets(4));
      expect(find.text('HIT'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Stand: Bernie turns his card, draws a king and busts.
      await tester.tap(find.text('STAND'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(PlayingCardView), findsNWidgets(5));
      expect(find.text('+25 coins'), findsOneWidget);
      expect(find.text('DEAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Leave table'));
      expect(closed, isTrue);
    });
  }
}
