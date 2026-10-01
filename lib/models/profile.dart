/// A row from the public.profiles table.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.characterIndex,
    required this.level,
    this.lastSeenAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int characterIndex;
  final int level;

  /// When the player last had the app open (see PresenceService).
  final DateTime? lastSeenAt;

  /// Players are seen about once a minute while the app is open, so anyone
  /// seen in the last two minutes is still here.
  static const Duration onlineWindow = Duration(minutes: 2);

  bool isOnline([DateTime? now]) {
    final seen = lastSeenAt;
    if (seen == null) return false;
    return (now ?? DateTime.now()).difference(seen) < onlineWindow;
  }

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    username: map['username'] as String? ?? '',
    displayName: map['display_name'] as String? ?? '',
    avatarUrl: map['avatar_url'] as String?,
    characterIndex: map['character_index'] as int? ?? 0,
    level: map['level'] as int? ?? 1,
    lastSeenAt: map['last_seen_at'] == null
        ? null
        : DateTime.parse(map['last_seen_at'] as String).toLocal(),
  );
}
