import 'dart:ui';

import 'package:final_project/game/player.dart';
import 'package:final_project/game/tavern_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Rect feetAt(Offset p) => Rect.fromLTWH(
    p.dx - Player.feetWidth / 2,
    p.dy - Player.feetHeight,
    Player.feetWidth,
    Player.feetHeight,
  );

  test('players spawn on open floor', () {
    expect(TavernMap.isBlocked(feetAt(TavernMap.spawnPoint)), isFalse);
  });

  test('the rug and walkway to it are open floor', () {
    for (final point in const [
      Offset(637, 900),
      Offset(637, 800),
      Offset(690, 615), // middle of the rug
      Offset(690, 460), // in front of the bar
    ]) {
      expect(TavernMap.isBlocked(feetAt(point)), isFalse, reason: '$point');
    }
  });

  test('players can stand at the notice board', () {
    expect(TavernMap.isBlocked(feetAt(TavernMap.noticeBoardSpot)), isFalse);
  });

  test('walls and furniture block', () {
    for (final point in const [
      Offset(600, 200), // behind the bar
      Offset(30, 600), // left wall
      Offset(1030, 850), // big table bottom-right
      Offset(300, 610), // round table
      Offset(900, 870), // a chair (big table, left)
      Offset(1205, 960), // barrel (bottom-right)
    ]) {
      expect(TavernMap.isBlocked(feetAt(point)), isTrue, reason: '$point');
    }
  });

  test('the floor between and around the furniture is open', () {
    for (final point in const [
      Offset(1000, 600), // between the top-right and middle-right tables
      Offset(1200, 560), // right of the top-right table
      Offset(1250, 760), // right of the middle-right table
      Offset(1020, 965), // below the big table
      Offset(450, 870), // right of the long table
      Offset(160, 680), // between the booth and the long table
      Offset(250, 905), // between the long table and the barrels
      Offset(900, 330), // in front of the door
    ]) {
      expect(TavernMap.isBlocked(feetAt(point)), isFalse, reason: '$point');
    }
  });

  test('every seat has open floor within reach', () {
    for (final seat in TavernMap.seats) {
      var reachable = false;
      for (var dy = -60.0; dy <= 60 && !reachable; dy += 4) {
        for (var dx = -60.0; dx <= 60 && !reachable; dx += 4) {
          final at = Offset(seat.x + dx, seat.y + dy);
          if ((at - Offset(seat.x, seat.y)).distance > TavernMap.seatReach) {
            continue;
          }
          reachable = !TavernMap.isBlocked(feetAt(at));
        }
      }
      expect(reachable, isTrue, reason: 'seat at ${seat.x}, ${seat.y}');
    }
  });
}
