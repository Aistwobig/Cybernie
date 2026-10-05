import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'coin_service.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.coins,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final int coins;
  final String? avatarUrl;
}

/// The richest players in the tavern, by coins.
class LeaderboardService {
  LeaderboardService._();

  static const int size = 10;

  static String? get myId {
    try {
      return AuthService.isSignedIn
          ? Supabase.instance.client.auth.currentUser?.id
          : null;
    } catch (_) {
      return null; // Supabase not set up (offline runs).
    }
  }

  static Future<List<LeaderboardEntry>> top() async {
    if (myId == null) {
      // Offline there's only you.
      return [
        LeaderboardEntry(
          id: 'me',
          name: 'You',
          coins: CoinService.coins.value ?? 0,
        ),
      ];
    }
    final rows = await Supabase.instance.client
        .from('profiles')
        .select('id, display_name, avatar_url, coins')
        .order('coins', ascending: false)
        .limit(size);
    return [
      for (final row in rows)
        LeaderboardEntry(
          id: row['id'] as String,
          name: (row['display_name'] as String?)?.trim().isNotEmpty == true
              ? row['display_name'] as String
              : 'Player',
          coins: (row['coins'] as num?)?.toInt() ?? 0,
          avatarUrl: row['avatar_url'] as String?,
        ),
    ];
  }
}
