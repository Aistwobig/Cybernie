import 'package:final_project/utils/profile_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Profile QR codes link to `/player/<id>`, and that route is recognised.
void main() {
  test('a profile route carries the player id', () {
    const id = '7a1c2f40-1b2d-4c3e-9f00-123456789abc';
    expect(ProfileLink.route(id), '/player/$id');
    expect(ProfileLink.playerIdIn('/player/$id'), id);
    expect(ProfileLink.playerIdIn('/player/$id?from=qr'), id);
    expect(ProfileLink.playerIdIn('/player/'), isNull);
    expect(ProfileLink.playerIdIn('/friends'), isNull);
    expect(ProfileLink.playerIdIn(null), isNull);
  });

  test('the link points at the profile page, with the player id', () {
    final link = Uri.parse(ProfileLink.url('abc'));
    expect(link.scheme, startsWith('http'));
    expect(link.path, endsWith('/p/'));
    expect(link.queryParameters['id'], 'abc');
  });
}
