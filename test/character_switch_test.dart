import 'package:final_project/constants/characters.dart';
import 'package:final_project/game/player.dart';
import 'package:final_project/game/tavern_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The tavern starts with the default character, then switches when the
  // profile arrives - often while the first sheet is still loading. The
  // finished character must be entirely the new one, not squeezed by mixing
  // one character's picture with another's frame count.
  for (final switchAfterFrames in [0, 1, 2, 4]) {
    testWidgets('switching during load (after $switchAfterFrames frames)', (
      tester,
    ) async {
      final game = TavernGame(playerName: 'T', characterIndex: 1);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      Future<void> frames(int n) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      await frames(switchAfterFrames);
      const slime = 5;
      game.playerCharacter = slime;
      await frames(40);
      expect(tester.takeException(), isNull);

      final p = game.player;
      final want = characterAt(slime);
      expect(p.sheetAsset, want.sheet);
      final walk = p.animations![(Facing.south, true)]!.frames;
      final idle = p.animations![(Facing.south, false)]!.frames;
      expect(walk, hasLength(want.frames));
      expect(idle, hasLength(want.frames));
      // Slime cells are 240 x 256, drawn 87 tall.
      expect(walk.first.sprite.srcSize, Vector2(240, 256));
      expect(p.size.x, closeTo(240 * 87 / 256, 0.01));
      expect(p.size.y, closeTo(87, 0.01));

      await tester.pumpWidget(const SizedBox());
    });
  }
}
