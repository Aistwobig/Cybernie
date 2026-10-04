import 'package:supabase_flutter/supabase_flutter.dart';

/// One private message between two friends: text, or one of the game's
/// emotes (see constants/emotes.dart).
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    this.body,
    this.emote,
    this.editedAt,
  });

  factory DirectMessage.fromRow(Map<String, dynamic> row) => DirectMessage(
    id: row['id'] as int,
    senderId: row['sender_id'] as String,
    recipientId: row['recipient_id'] as String,
    body: row['body'] as String?,
    emote: row['emote'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    editedAt: row['edited_at'] == null
        ? null
        : DateTime.parse(row['edited_at'] as String).toLocal(),
  );

  final int id;
  final String senderId;
  final String recipientId;
  final String? body;
  final String? emote;
  final DateTime createdAt;
  final DateTime? editedAt;

  bool get isEmote => emote != null;

  /// Whether this message belongs to the conversation with [friendId].
  bool isWith(String friendId) =>
      senderId == friendId || recipientId == friendId;
}

/// Private messages between friends, stored in public.direct_messages
/// (see supabase/migrations/20261005000000_direct_messages.sql).
class DirectMessageService {
  DirectMessageService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String get myId => _client.auth.currentUser!.id;

  static const int maxLength = 500;

  /// The latest messages with [friendId], oldest first.
  static Future<List<DirectMessage>> fetchConversation(
    String friendId, {
    int limit = 80,
  }) async {
    final me = myId;
    final rows = await _client
        .from('direct_messages')
        .select()
        .or(
          'and(sender_id.eq.$me,recipient_id.eq.$friendId),'
          'and(sender_id.eq.$friendId,recipient_id.eq.$me)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in rows.reversed) DirectMessage.fromRow(row)];
  }

  static Future<DirectMessage> sendText(String friendId, String body) =>
      _insert({'recipient_id': friendId, 'body': body});

  static Future<DirectMessage> sendEmote(String friendId, String emoteId) =>
      _insert({'recipient_id': friendId, 'emote': emoteId});

  static Future<DirectMessage> _insert(Map<String, dynamic> values) async {
    final row = await _client
        .from('direct_messages')
        .insert({'sender_id': myId, ...values})
        .select()
        .single();
    return DirectMessage.fromRow(row);
  }

  /// Changes the text of one of our messages and marks it edited.
  static Future<DirectMessage> edit(int id, String body) async {
    final row = await _client
        .from('direct_messages')
        .update({
          'body': body,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return DirectMessage.fromRow(row);
  }

  /// Deletes one of our messages, for both players.
  static Future<void> delete(int id) =>
      _client.from('direct_messages').delete().eq('id', id);

  /// Listens for messages sent to us, and for edits and deletions, until
  /// the returned feed is closed.
  static DirectMessageFeed listen({
    required void Function(DirectMessage message) onNew,
    required void Function(DirectMessage message) onEdited,
    required void Function(int id) onDeleted,
  }) {
    final me = myId;
    final mine = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'recipient_id',
      value: me,
    );
    // Each feed gets its own channel, so a chat screen and the tavern can
    // both listen at once.
    final channel = _client
        .channel('dm:$me:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: mine,
          callback: (p) => onNew(DirectMessage.fromRow(p.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'direct_messages',
          filter: mine,
          callback: (p) => onEdited(DirectMessage.fromRow(p.newRecord)),
        )
        // Deletions can't be filtered; they only carry the message id.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'direct_messages',
          callback: (p) {
            final id = p.oldRecord['id'];
            if (id is int) onDeleted(id);
          },
        )
        .subscribe();
    return DirectMessageFeed._(channel);
  }
}

/// A live subscription from [DirectMessageService.listen].
class DirectMessageFeed {
  DirectMessageFeed._(this._channel);

  final RealtimeChannel _channel;

  Future<void> close() => Supabase.instance.client.removeChannel(_channel);
}
