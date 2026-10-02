import 'package:supabase_flutter/supabase_flutter.dart';

class NoticeNote {
  const NoticeNote({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

/// Thrown when the notice_notes table hasn't been created yet
/// (supabase/migrations/20261003000000_notice_board.sql not run).
class NoticeBoardMissingException implements Exception {
  const NoticeBoardMissingException();
}

/// Notes pinned to a room's notice board (public.notice_notes).
class NoticeBoardService {
  NoticeBoardService._();

  static const int maxLength = 140;

  static SupabaseClient get _client => Supabase.instance.client;

  static String get myId => _client.auth.currentUser!.id;

  static Future<List<NoticeNote>> fetch(String roomId, {int limit = 30}) =>
      _guard(() async {
        final rows = await _client
            .from('notice_notes')
            .select('id, author_id, body, created_at, profiles(display_name)')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(limit);
        return [
          for (final row in rows)
            NoticeNote(
              id: row['id'] as int,
              authorId: row['author_id'] as String,
              authorName:
                  ((row['profiles'] as Map<String, dynamic>?)?['display_name']
                      as String?) ??
                  'Player',
              body: row['body'] as String,
              createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
            ),
        ];
      });

  static Future<void> pin(String roomId, String body) => _guard(
    () => _client.from('notice_notes').insert({
      'room_id': roomId,
      'author_id': myId,
      'body': body.trim(),
    }),
  );

  static Future<void> takeDown(int noteId) =>
      _guard(() => _client.from('notice_notes').delete().eq('id', noteId));

  /// Turns "table doesn't exist" into [NoticeBoardMissingException].
  static Future<T> _guard<T>(Future<T> Function() query) async {
    try {
      return await query();
    } on PostgrestException catch (error) {
      // 42P01: undefined table. PGRST205: table not in the API's schema.
      if (error.code == '42P01' || error.code == 'PGRST205') {
        throw const NoticeBoardMissingException();
      }
      rethrow;
    }
  }
}
