/// Blackjack cards and hands, matching supabase/migrations/
/// 20261007000000_coins_blackjack.sql.
///
/// A card is a number 0-51: suit = card ~/ 13 (0 hearts, 1 diamonds,
/// 2 clubs, 3 spades) and rank = card % 13 (0 ace, 1-9 two to ten, 10 jack,
/// 11 queen, 12 king), the rows and columns of AppImages.catCards. -1 is a
/// face-down card.
library;

const int hiddenCard = -1;

int cardSuit(int card) => card ~/ 13;
int cardRank(int card) => card % 13;

/// What a card counts for, with an ace as 11.
int cardPoints(int card) {
  final rank = cardRank(card);
  if (rank == 0) return 11;
  if (rank >= 9) return 10;
  return rank + 1;
}

/// The best total of [cards]: aces count 11, or 1 when 11 would bust.
/// Face-down cards don't count.
int handValue(Iterable<int> cards) {
  var total = 0;
  var aces = 0;
  for (final card in cards) {
    if (card == hiddenCard) continue;
    total += cardPoints(card);
    if (cardRank(card) == 0) aces++;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

/// Two cards worth 21.
bool isBlackjack(List<int> cards) =>
    cards.length == 2 && handValue(cards) == 21;

enum BlackjackOutcome {
  win('win'),
  blackjack('blackjack'),
  dealerBust('dealer_bust'),
  lose('lose'),
  dealerBlackjack('dealer_blackjack'),
  bust('bust'),
  push('push');

  const BlackjackOutcome(this.id);

  final String id;

  static BlackjackOutcome? fromId(String? id) =>
      values.where((o) => o.id == id).firstOrNull;

  /// The player got more back than they bet.
  bool get playerWon => this == win || this == blackjack || this == dealerBust;
}

/// One hand as the player may see it (Bernie's second card is [hiddenCard]
/// while it's being played).
class BlackjackHand {
  const BlackjackHand({
    required this.player,
    required this.dealer,
    required this.bet,
    required this.playing,
    this.outcome,
    this.payout = 0,
  });

  final List<int> player;
  final List<int> dealer;
  final int bet;

  /// Still the player's turn.
  final bool playing;
  final BlackjackOutcome? outcome;

  /// Coins paid back when the hand ended (bet included).
  final int payout;

  /// What the player won or lost on this hand.
  int get net => payout - bet;

  static BlackjackHand fromJson(Map<String, dynamic> json) => BlackjackHand(
    player: _cards(json['player']),
    dealer: _cards(json['dealer']),
    bet: (json['bet'] as num).toInt(),
    playing: json['playing'] == true,
    outcome: BlackjackOutcome.fromId(json['outcome'] as String?),
    payout: (json['payout'] as num?)?.toInt() ?? 0,
  );

  static List<int> _cards(Object? list) => [
    for (final c in (list as List? ?? const [])) (c as num).toInt(),
  ];
}

/// The player's coins and their current (or last) hand.
class BlackjackState {
  const BlackjackState({required this.coins, this.hand});

  final int coins;
  final BlackjackHand? hand;

  static BlackjackState fromJson(Map<String, dynamic> json) => BlackjackState(
    coins: (json['coins'] as num?)?.toInt() ?? 0,
    hand: json['hand'] is Map
        ? BlackjackHand.fromJson(Map<String, dynamic>.from(json['hand'] as Map))
        : null,
  );
}
