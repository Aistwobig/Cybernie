import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'coin_service.dart';

/// One prize on the lottery wheel and its chance (percent).
class LotteryPrize {
  const LotteryPrize(this.coins, this.chance);

  final int coins;
  final double chance;
}

/// Whether a free spin is open, and when the next one opens.
class LotteryStatus {
  const LotteryStatus({
    required this.available,
    required this.slot,
    this.nextAt,
  });

  final bool available;

  /// Which spin this is, e.g. '2026-10-11 pm' (one per slot).
  final String slot;
  final DateTime? nextAt;
}

/// Bernie's free lottery wheel: two spins a day (12 AM and 8 PM, Philippine
/// time). The prize is drawn by the database (see
/// supabase/migrations/20261011000000_lottery.sql); signed out, one spin per
/// visit is drawn on the device with the same chances.
class LotteryService {
  LotteryService._();

  /// The chances, matching public.spin_lottery. They add up to 100.
  static const List<LotteryPrize> prizes = [
    LotteryPrize(1000, 1),
    LotteryPrize(500, 2),
    LotteryPrize(200, 4),
    LotteryPrize(150, 11),
    LotteryPrize(100, 21),
    LotteryPrize(80, 27),
    LotteryPrize(50, 34),
  ];

  static bool _spunOffline = false;
  static final Random _random = Random();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<LotteryStatus> status() async {
    if (!AuthService.isSignedIn) {
      return LotteryStatus(available: !_spunOffline, slot: 'offline');
    }
    final result = Map<String, dynamic>.from(
      await _client.rpc<dynamic>('lottery_status') as Map,
    );
    return LotteryStatus(
      available: result['available'] == true,
      slot: result['slot'] as String? ?? '',
      nextAt: DateTime.tryParse(result['next_at'] as String? ?? '')?.toLocal(),
    );
  }

  /// Spins once: returns the coins won (and updates the coin counter).
  static Future<int> spin() async {
    if (!AuthService.isSignedIn) {
      if (_spunOffline) throw StateError('already spun');
      _spunOffline = true;
      final won = draw(_random.nextDouble() * 100);
      CoinService.coins.value = (CoinService.coins.value ?? 0) + won;
      return won;
    }
    final result = Map<String, dynamic>.from(
      await _client.rpc<dynamic>('spin_lottery') as Map,
    );
    CoinService.coins.value = (result['coins'] as num?)?.toInt();
    return (result['prize'] as num).toInt();
  }

  /// The prize for a roll from 0 up to 100, walking up the chances (the same
  /// way the database draws it).
  @visibleForTesting
  static int draw(double roll) {
    var upTo = 0.0;
    for (final prize in prizes) {
      upTo += prize.chance;
      if (roll < upTo) return prize.coins;
    }
    return prizes.last.coins;
  }
}
