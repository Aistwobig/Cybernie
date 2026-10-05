import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'blackjack_service.dart';

/// The player's tavern coins, shown in the tavern's top-right corner and
/// bet at Bernie's blackjack table.
class CoinService {
  CoinService._();

  /// Null until loaded (or when they can't be loaded).
  static final ValueNotifier<int?> coins = ValueNotifier(null);

  static const int dailyBonus = 50;

  static LocalBlackjackTable? _offline;

  /// The blackjack table to play at: the real one when signed in, otherwise
  /// one on the device whose coins aren't saved.
  static BlackjackTable get table => AuthService.isSignedIn
      ? SupabaseBlackjackTable()
      : (_offline ??= LocalBlackjackTable());

  /// Loads the coins on entering the tavern, adding the daily bonus once a
  /// day. Returns the coins just added (0 if already claimed today).
  static Future<int> enterTavern() async {
    if (!AuthService.isSignedIn) {
      coins.value = (table as LocalBlackjackTable).coins;
      return 0;
    }
    final result = await Supabase.instance.client.rpc<dynamic>(
      'claim_daily_coins',
    );
    final data = Map<String, dynamic>.from(result as Map);
    coins.value = (data['coins'] as num?)?.toInt();
    return (data['bonus'] as num?)?.toInt() ?? 0;
  }
}
