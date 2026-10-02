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
    ]) {
      expect(TavernMap.isBlocked(feetAt(point)), isTrue, reason: '$point');
    }
  });
}
