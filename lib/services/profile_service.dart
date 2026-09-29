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

  static Future<void> updateMine({
    String? displayName,
    int? characterIndex,
    String? avatarUrl,
  }) async {
    await _client.from('profiles').update({
      'display_name': ?displayName,
      'character_index': ?characterIndex,
      'avatar_url': ?avatarUrl,
    }).eq('id', _userId);
  }

  /// Uploads a profile photo to `avatars/<user id>/avatar.jpg` and returns its
  /// public URL. The storage policy only allows writing inside your own folder.
  static Future<String> uploadAvatar(Uint8List bytes) async {
    final path = '$_userId/avatar.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows instead of the old cached one.
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
