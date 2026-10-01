import 'package:final_project/models/profile.dart';
import 'package:final_project/utils/last_seen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12);

  Profile seen(Duration ago) => Profile(
    id: 'p',
    username: 'player_1',
    displayName: 'Luna',
    avatarUrl: null,
    characterIndex: 0,
    level: 1,
    lastSeenAt: now.subtract(ago),
  );

  test('recently seen players are online', () {
    expect(seen(const Duration(seconds: 30)).isOnline(now), isTrue);
    expect(lastSeenLabel(seen(const Duration(seconds: 90)), now), 'Online');
  });

  test('older activity reads as mins, hours and days ago', () {
    expect(
      lastSeenLabel(seen(const Duration(minutes: 5)), now),
      'Active 5 mins ago',
    );
    expect(
      lastSeenLabel(seen(const Duration(minutes: 2, seconds: 30)), now),
      'Active 2 mins ago',
    );
    expect(
      lastSeenLabel(seen(const Duration(hours: 1)), now),
      'Active 1 hour ago',
    );
    expect(
      lastSeenLabel(seen(const Duration(hours: 5)), now),
      'Active 5 hours ago',
    );
    expect(
      lastSeenLabel(seen(const Duration(days: 1)), now),
      'Active 1 day ago',
    );
    expect(
      lastSeenLabel(seen(const Duration(days: 3)), now),
      'Active 3 days ago',
    );
  });

  test('players who never opened the app since the update are offline', () {
    const never = Profile(
      id: 'p',
      username: '',
      displayName: 'Bob',
      avatarUrl: null,
      characterIndex: 0,
      level: 1,
    );
    expect(never.isOnline(now), isFalse);
    expect(lastSeenLabel(never, now), 'Offline');
  });

  test('profiles read last_seen_at from Supabase rows', () {
    final profile = Profile.fromMap({
      'id': 'p',
      'username': 'player_1',
      'display_name': 'Luna',
      'avatar_url': null,
      'last_seen_at': '2026-10-01T04:00:00+00:00',
    });
    expect(profile.lastSeenAt!.toUtc(), DateTime.utc(2026, 10, 1, 4));
  });
}
