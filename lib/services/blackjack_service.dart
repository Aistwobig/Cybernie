import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blackjack.dart';

/// Bernie's blackjack table. Each call returns the player's coins and hand
/// afterwards.
abstract class BlackjackTable {
  static const int minBet = 10;
  static const int maxBet = 500;

  Future<BlackjackState> load();
  Future<BlackjackState> deal(int bet);
  Future<BlackjackState> hit();
  Future<BlackjackState> stand();
  Future<BlackjackState> doubleDown();
}

/// The real table: every hand is shuffled, dealt and paid out by the
/// database (see supabase/migrations/20261007000000_coins_blackjack.sql).
class SupabaseBlackjackTable implements BlackjackTable {
  static SupabaseClient get _client => Supabase.instance.client;

  Future<BlackjackState> _call(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final result = await _client.rpc<dynamic>(fn, params: params);
    return BlackjackState.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<BlackjackState> load() => _call('blackjack_state');

  @override
  Future<BlackjackState> deal(int bet) =>
      _call('blackjack_deal', {'p_bet': bet});

  @override
  Future<BlackjackState> hit() => _call('blackjack_hit');

  @override
  Future<BlackjackState> stand() => _call('blackjack_stand');

  @override
  Future<BlackjackState> doubleDown() => _call('blackjack_double');
}

/// The same rules played on the device, for signed-out (offline) runs and
/// tests. Coins aren't saved.
class LocalBlackjackTable implements BlackjackTable {
  LocalBlackjackTable({this.coins = 500, Random? random, List<int>? deck})
    : _random = random ?? Random(),
      _fixedDeck = deck;

  int coins;
  final Random _random;

  /// When set, every hand is dealt from this order (for tests).
  final List<int>? _fixedDeck;

  List<int> _deck = [];
  List<int> _player = [];
  List<int> _dealer = [];
  int _bet = 0;
  bool _playing = false;
  BlackjackOutcome? _outcome;
  int _payout = 0;

  BlackjackState get _state => BlackjackState(
    coins: coins,
    hand: _player.isEmpty
        ? null
        : BlackjackHand(
            player: List.of(_player),
            dealer: _playing ? [_dealer.first, hiddenCard] : List.of(_dealer),
            bet: _bet,
            playing: _playing,
            outcome: _outcome,
            payout: _payout,
          ),
  );

  int _draw() => _deck.removeAt(0);

  @override
  Future<BlackjackState> load() async => _state;

  @override
  Future<BlackjackState> deal(int bet) async {
    if (_playing) throw StateError('a hand is already being played');
    if (bet < BlackjackTable.minBet ||
        bet > BlackjackTable.maxBet ||
        bet > coins) {
      throw ArgumentError('invalid bet');
    }
    coins -= bet;
    _deck = List.of(
      _fixedDeck ?? (List.generate(52, (i) => i)..shuffle(_random)),
    );
    _player = [_deck[0], _deck[2]];
    _dealer = [_deck[1], _deck[3]];
    _deck.removeRange(0, 4);
    _bet = bet;
    _playing = true;
    _outcome = null;
    _payout = 0;
    if (handValue(_player) == 21 || handValue(_dealer) == 21) {
      _finish(dealerPlays: false);
    }
    return _state;
  }

  @override
  Future<BlackjackState> hit() async {
    if (!_playing) throw StateError('no hand in play');
    _player.add(_draw());
    final value = handValue(_player);
    if (value > 21) {
      _finish(dealerPlays: false);
    } else if (value == 21) {
      _finish(dealerPlays: true);
    }
    return _state;
  }

  @override
  Future<BlackjackState> stand() async {
    if (!_playing) throw StateError('no hand in play');
    _finish(dealerPlays: true);
    return _state;
  }

  @override
  Future<BlackjackState> doubleDown() async {
    if (!_playing) throw StateError('no hand in play');
    if (_player.length != 2) throw StateError('too late to double');
    if (coins < _bet) throw StateError('not enough coins');
    coins -= _bet;
    _bet *= 2;
    _player.add(_draw());
    _finish(dealerPlays: true);
    return _state;
  }

  void _finish({required bool dealerPlays}) {
    final pv = handValue(_player);
    if (dealerPlays && pv <= 21) {
      while (handValue(_dealer) < 17) {
        _dealer.add(_draw());
      }
    }
    final dv = handValue(_dealer);
    final playerBj = isBlackjack(_player);
    final dealerBj = isBlackjack(_dealer);
    final (outcome, pay) = switch (true) {
      _ when pv > 21 => (BlackjackOutcome.bust, 0),
      _ when playerBj && dealerBj => (BlackjackOutcome.push, _bet),
      _ when playerBj => (BlackjackOutcome.blackjack, _bet + _bet * 3 ~/ 2),
      _ when dealerBj => (BlackjackOutcome.dealerBlackjack, 0),
      _ when dv > 21 => (BlackjackOutcome.dealerBust, _bet * 2),
      _ when pv > dv => (BlackjackOutcome.win, _bet * 2),
      _ when pv < dv => (BlackjackOutcome.lose, 0),
      _ => (BlackjackOutcome.push, _bet),
    };
    _outcome = outcome;
    _payout = pay;
    _playing = false;
    coins += pay;
  }
}
