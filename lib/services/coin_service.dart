import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/drinks.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
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

  /// Pays for [drink] at Bernie's bar and puts it in the inventory. Returns
  /// false (charging nothing) if the player can't afford it.
  static Future<bool> buyDrink(Drink drink) async {
    final bought = await _pay(drink);
    if (bought) await InventoryService.added(drink.id);
    return bought;
  }

  static Future<bool> _pay(Drink drink) async {
    final have = coins.value ?? 0;
    if (have < drink.price) return false;
    if (!AuthService.isSignedIn) {
      final offline = table as LocalBlackjackTable;
      offline.coins -= drink.price;
      coins.value = offline.coins;
      return true;
    }
    try {
      final left = await Supabase.instance.client.rpc<dynamic>(
        'buy_drink',
        params: {'p_drink': drink.id},
      );
      coins.value = (left as num).toInt();
      return true;
    } on PostgrestException catch (error) {
      // Only a real "can't afford it" refuses the drink. Anything else
      // (e.g. the drink-prices migration not run yet) and Bernie serves it
      // on the house, so ordering never silently does nothing.
      debugPrint('Buying a drink: ${error.message}');
      return !error.message.contains('not enough coins');
    } catch (error) {
      debugPrint('Buying a drink: $error');
      return true;
    }
  }

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
