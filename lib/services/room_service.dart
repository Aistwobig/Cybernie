import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Someone currently in a room, as shared through Realtime Presence.
class RoomPlayer {
  const RoomPlayer({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  /// Where they were when they joined. Live positions arrive as [PlayerMove].
  final double x;
  final double y;
}

/// One position update from another player.
class PlayerMove {
  const PlayerMove({
    required this.playerId,
    required this.x,
    required this.y,
    required this.facing,
    required this.moving,
  });

  final String playerId;
  final double x;
  final double y;
  final int facing;
  final bool moving;

  Map<String, dynamic> toPayload() => {
    'id': playerId,
    'x': x.round(),
    'y': y.round(),
    'f': facing,
    'm': moving,
  };

  static PlayerMove? fromPayload(Map<String, dynamic> message) {
    // Depending on the client version the data is either the message itself
    // or nested under 'payload'.
    final data = message['payload'] is Map
        ? Map<String, dynamic>.from(message['payload'] as Map)
        : message;
    final id = data['id'];
    final x = data['x'];
    final y = data['y'];
    if (id is! String || x is! num || y is! num) return null;
    return PlayerMove(
      playerId: id,
      x: x.toDouble(),
      y: y.toDouble(),
      facing: (data['f'] as num?)?.toInt() ?? 0,
      moving: data['m'] == true,
    );
  }
}

/// Live multiplayer for one room, over a single private Realtime channel:
///
/// * Presence says who is in the room (and powers the player count).
/// * Broadcast carries positions. Nothing is stored in the database.
///
/// The channel is private, so only signed-in players can use it; see
/// supabase/migrations/20260930000000_realtime_rooms.sql.
class RoomService {
  RoomService(this.roomId);

  final String roomId;
  static const int maxPlayers = 20;

  RealtimeChannel? _channel;

  static SupabaseClient get _client => Supabase.instance.client;

  String get myId => _client.auth.currentUser!.id;

  static String _topic(String roomId) => 'room:$roomId';

  /// Joins the room. [onPlayers] gets everyone else in the room whenever
  /// that changes, [onMove] every position update, and [onSomeoneJoined]
  /// fires when a new player arrives (so we can tell them where we are).
  Future<void> join({
    required String name,
    required String? avatarUrl,
    required double x,
    required double y,
    required void Function(List<RoomPlayer> others) onPlayers,
    required void Function(PlayerMove move) onMove,
    required void Function() onSomeoneJoined,
    required void Function(String playerId, String emoji) onEmote,
    required void Function() onError,
  }) async {
    await _client.realtime.setAuth(_client.auth.currentSession?.accessToken);

    final channel = _client.channel(
      _topic(roomId),
      opts: RealtimeChannelConfig(key: myId, private: true),
    );
    _channel = channel;

    channel
        .onPresenceSync((_) {
          onPlayers([
            for (final state in channel.presenceState())
              if (state.key != myId && state.presences.isNotEmpty)
                _playerFrom(state.key, state.presences.last.payload),
          ]);
        })
        .onPresenceJoin((payload) {
          if (payload.key != myId) onSomeoneJoined();
        })
        .onBroadcast(
          event: 'move',
          callback: (message) {
            final move = PlayerMove.fromPayload(message);
            if (move != null && move.playerId != myId) onMove(move);
          },
        )
        .onBroadcast(
          event: 'emote',
          callback: (message) {
            final data = message['payload'] is Map
                ? Map<String, dynamic>.from(message['payload'] as Map)
                : message;
            final id = data['id'];
            final emoji = data['e'];
            if (id is String && emoji is String && id != myId) {
              if (isEmote(emoji)) onEmote(id, emoji);
            }
          },
        )
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({
              'name': name,
              'avatar': ?avatarUrl,
              'x': x.round(),
              'y': y.round(),
            });
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            onError();
          }
        });
  }

  /// The reactions players can send. Anything else received is ignored.
  static const List<String> emotes = ['👋', '😂', '❤️', '👍', '🎉', '😮'];

  static bool isEmote(String emoji) => emotes.contains(emoji);

  Future<void> sendEmote(String emoji) async {
    if (!isEmote(emoji)) return;
    await _channel?.sendBroadcastMessage(
      event: 'emote',
      payload: {'id': myId, 'e': emoji},
    );
  }

  Future<void> sendMove(PlayerMove move) async {
    await _channel?.sendBroadcastMessage(
      event: 'move',
      payload: move.toPayload(),
    );
  }

  Future<void> leave() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    await channel.untrack();
    await _client.removeChannel(channel);
  }

  static RoomPlayer _playerFrom(String id, Map<String, dynamic> data) =>
      RoomPlayer(
        id: id,
        name: (data['name'] as String?) ?? 'Player',
        avatarUrl: data['avatar'] as String?,
        x: (data['x'] as num?)?.toDouble() ?? 0,
        y: (data['y'] as num?)?.toDouble() ?? 0,
      );

  /// Live number of players in [roomId], for the Select Room screen. Watches
  /// Presence without joining. Cancel the subscription before entering the
  /// room: one app can only hold one connection to a room's channel.
  static Stream<int> watchPlayerCount(String roomId) {
    late final StreamController<int> controller;
    RealtimeChannel? channel;

    controller = StreamController<int>(
      onListen: () async {
        await _client.realtime.setAuth(
          _client.auth.currentSession?.accessToken,
        );
        final watcher = _client.channel(
          _topic(roomId),
          opts: const RealtimeChannelConfig(private: true),
        );
        channel = watcher;
        watcher.onPresenceSync((_) {
          if (!controller.isClosed) {
            controller.add(watcher.presenceState().length);
          }
        }).subscribe();
      },
      onCancel: () async {
        final watcher = channel;
        channel = null;
        if (watcher != null) await _client.removeChannel(watcher);
      },
    );
    return controller.stream;
  }
}
