import 'package:final_project/constants/app_images.dart';
import 'package:final_project/game/tavern_game.dart';
import 'package:final_project/game/tavern_map.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the tavern loads and the player can walk',
    (tester) async {
      final game = TavernGame(
        playerName: 'Tester',
        characterSheet: AppImages.characterMenAnim,
      );
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));

      // Keep drawing frames while the images decode. Frames that run before
      // the sprite sheet is ready must not crash.
      for (var i = 0; i < 200; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        if (game.isLoaded && game.player.isLoaded) break;
      }
      expect(game.player.isLoaded, isTrue, reason: 'player never loaded');

      final start = game.player.position.clone();
      expect(start, Vector2(TavernMap.spawnPoint.dx, TavernMap.spawnPoint.dy));

      // Walk north for half a second.
      for (var i = 0; i < 30; i++) {
        game.player.walk(Vector2(0, -1), 1 / 60);
      }
      expect(game.player.position.y, lessThan(start.y));

      // Other players appear, move and leave.
      game.syncOtherPlayers([(id: 'friend', name: 'Luna', x: 690, y: 615)]);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.otherPlayerCount, 1);
      game.moveOtherPlayer('friend', 700, 600, 3, true);
      game.otherPlayerSays('friend', 'hi!');
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);

      final sent = <double>[];
      game.onLocalMove = (x, y, facing, moving) => sent.add(x);
      game.broadcastPosition();
      expect(sent, hasLength(1));

      game.syncOtherPlayers([]);
      expect(game.otherPlayerCount, 0);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
