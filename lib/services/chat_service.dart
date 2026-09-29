import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
  });

  final int id;
  final String senderId;
  final String senderName;
  final String body;
}

/// Text chat for one room, stored in public.messages. New messages arrive
/// live through Supabase Realtime, including your own.
class ChatService {
  ChatService(this.roomId);

  final String roomId;
  RealtimeChannel? _channel;
  final Map<String, String> _names = {};

  static SupabaseClient get _client => Supabase.instance.client;

  String get myId => _client.auth.currentUser!.id;

  Future<List<ChatMessage>> fetchRecent({int limit = 20}) async {
    final rows = await _client
        .from('messages')
        .select('id, sender_id, body, profiles(display_name)')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    return [
      for (final row in rows.reversed)
        ChatMessage(
          id: row['id'] as int,
          senderId: row['sender_id'] as String,
          senderName: _rememberName(
            row['sender_id'] as String,
            (row['profiles'] as Map<String, dynamic>?)?['display_name']
                as String?,
          ),
          body: row['body'] as String,
        ),
    ];
  }

  void subscribe(void Function(ChatMessage message) onMessage) {
    _channel = _client
        .channel('room:$roomId:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final senderId = row['sender_id'] as String;
            onMessage(
              ChatMessage(
                id: row['id'] as int,
                senderId: senderId,
                senderName: await _nameFor(senderId),
                body: row['body'] as String,
              ),
            );
          },
        )
        .subscribe();
  }

  Future<void> send(String body) => _client.from('messages').insert({
    'room_id': roomId,
    'sender_id': myId,
    'body': body,
  });

  Future<void> dispose() async {
    final channel = _channel;
    if (channel != null) await _client.removeChannel(channel);
  }

  String _rememberName(String id, String? name) =>
      _names[id] = (name == null || name.isEmpty) ? 'Player' : name;

  Future<String> _nameFor(String id) async {
    final cached = _names[id];
    if (cached != null) return cached;
    try {
      final row = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', id)
          .single();
      return _rememberName(id, row['display_name'] as String?);
    } catch (_) {
      return 'Player';
    }
  }
}
