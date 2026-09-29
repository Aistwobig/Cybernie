/// A row from the public.profiles table.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.characterIndex,
    required this.level,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int characterIndex;
  final int level;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        displayName: map['display_name'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        characterIndex: map['character_index'] as int? ?? 0,
        level: map['level'] as int? ?? 1,
      );
}
