import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// How the signed-in player is connected to someone else.
enum FriendStatus {
  /// No friendship row yet.
  none,

  /// We sent them a request; waiting for them.
  requestSent,

  /// They sent us a request; we can accept or decline.
  requestReceived,

  /// Accepted friends.
  friends,
}

class FriendEntry {
  const FriendEntry({required this.profile, required this.status});

  final Profile profile;
  final FriendStatus status;
}

/// Friends, friend requests and player search, on top of the
/// public.friendships table (RLS: you only see rows you're part of).
class FriendsService {
  FriendsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String get myId => _client.auth.currentUser!.id;

  static const String _profileColumns =
      'id, username, display_name, avatar_url, last_seen_at';

  /// Everyone we're connected to: friends plus pending requests both ways.
  static Future<List<FriendEntry>> fetchAll() async {
    final rows = await _client
        .from('friendships')
        .select(
          'requester_id, addressee_id, status, '
          'requester:profiles!friendships_requester_id_fkey($_profileColumns), '
          'addressee:profiles!friendships_addressee_id_fkey($_profileColumns)',
        );

    final me = myId;
    return [
      for (final row in rows)
        _entryFrom(row, iAmRequester: row['requester_id'] == me),
    ];
  }

  static FriendEntry _entryFrom(
    Map<String, dynamic> row, {
    required bool iAmRequester,
  }) {
    final other = Map<String, dynamic>.from(
      row[iAmRequester ? 'addressee' : 'requester'] as Map,
    );
    final status = row['status'] == 'accepted'
        ? FriendStatus.friends
        : iAmRequester
        ? FriendStatus.requestSent
        : FriendStatus.requestReceived;
    return FriendEntry(profile: Profile.fromMap(other), status: status);
  }

  /// Players whose name or username contains [query] (not including us).
  static Future<List<Profile>> searchPlayers(String query) async {
    // Keep only characters that are safe inside a PostgREST filter.
    final term = query.replaceAll(RegExp(r'[^\w\s.-]'), '').trim();
    if (term.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .or('display_name.ilike.%$term%,username.ilike.%$term%')
        .neq('id', myId)
        .order('display_name')
        .limit(20);
    return [for (final row in rows) Profile.fromMap(row)];
  }

  static Future<void> sendRequest(String otherId) => _client
      .from('friendships')
      .insert({'requester_id': myId, 'addressee_id': otherId});

  static Future<void> acceptRequest(String requesterId) => _client
      .from('friendships')
      .update({'status': 'accepted'})
      .eq('requester_id', requesterId)
      .eq('addressee_id', myId);

  /// Declines a request, cancels one we sent, or unfriends.
  static Future<void> remove(String otherId) {
    final me = myId;
    return _client
        .from('friendships')
        .delete()
        .or(
          'and(requester_id.eq.$me,addressee_id.eq.$otherId),'
          'and(requester_id.eq.$otherId,addressee_id.eq.$me)',
        );
  }
}
