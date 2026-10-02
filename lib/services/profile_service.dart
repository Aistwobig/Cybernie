import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Reads and writes the signed-in user's row in public.profiles, and their
/// photo in the "avatars" storage bucket.
class ProfileService {
  ProfileService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String get _userId => _client.auth.currentUser!.id;

  static Future<Profile> fetchMine() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .single();
    return Profile.fromMap(row);
  }

  /// Another player's profile, e.g. for the card shown when you tap them.
  static Future<Profile> fetchById(String id) async {
    final row = await _client.from('profiles').select().eq('id', id).single();
    return Profile.fromMap(row);
  }

  static Future<void> updateMine({
    String? displayName,
    int? characterIndex,
    String? avatarUrl,
  }) async {
    await _client
        .from('profiles')
        .update({
          'display_name': ?displayName,
          'character_index': ?characterIndex,
          'avatar_url': ?avatarUrl,
        })
        .eq('id', _userId);
  }

  /// Uploads a profile photo to `avatars/<user id>/avatar` and returns its
  /// public URL. The storage policy only allows writing inside your own folder.
  static Future<String> uploadAvatar(Uint8List bytes) async {
    final path = '$_userId/avatar';
    // The picker returns PNG on some platforms and JPEG on others.
    final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: isPng ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows instead of the old cached one.
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
