import 'package:final_project/constants/app_images.dart';
import 'package:final_project/game/player.dart';
import 'package:final_project/game/tavern_game.dart';
import 'package:final_project/game/tavern_map.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the tavern loads and the player can walk',
    (tester) async {
      final game = TavernGame(playerName: 'Tester');
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
      // The friend plays as the Mage (character 2).
      game.syncOtherPlayers([
        (id: 'friend', name: 'Luna', character: 2, x: 690.0, y: 615.0),
      ]);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.otherPlayerCount, 1);

      // Switching our own character to the Mage loads her sheet.
      game.playerCharacter = 2;
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.player.sheetAsset, AppImages.mageSheet);
      // Her left/right run frames are the same size as her walk frames,
      // and standing still plays her idle cycle (8 frames), not the walk.
      final anims = game.player.animations!;
      expect(
        anims[(Facing.west, Pose.walk)]!.frames.first.sprite.srcSize,
        anims[(Facing.south, Pose.walk)]!.frames.first.sprite.srcSize,
      );
      expect(anims[(Facing.south, Pose.stand)]!.frames, hasLength(8));
      game.player.walk(Vector2.zero(), 1 / 60);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.player.current, (game.player.facing, Pose.stand));
      expect(game.player.size.y, closeTo(87, 0.01));
      game.moveOtherPlayer('friend', 700, 600, 3, true);
      game.otherPlayerSays('friend', 'hi!');
      // Emotes from them and from us pop up and clear without errors.
      game.otherPlayerEmotes('friend', '👋');
      game.emote('😵');
      // The picture loads, then pops up over our head...
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        game.player.children.whereType<SpriteComponent>(),
        hasLength(1),
        reason: 'our emote should show over our head',
      );
      // ...and is gone a few seconds later.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(game.player.children.whereType<SpriteComponent>(), isEmpty);
      expect(tester.takeException(), isNull);

      // Walking up to the notice board offers it, and E opens it.
      final nearby = <bool>[];
      var interacted = 0;
      game
        ..onNoticeBoardNearby = nearby.add
        ..onInteract = () => interacted++;
      game.interact();
      expect(interacted, 0, reason: 'E does nothing away from the board');
      game.player.position.setValues(
        TavernMap.noticeBoardSpot.dx,
        TavernMap.noticeBoardSpot.dy,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(nearby, [true]);
      expect(game.nearNoticeBoard, isTrue);
      game.interact();
      expect(interacted, 1);

      final sent = <double>[];
      final sentSitting = <bool>[];
      game.onLocalMove = (x, y, facing, moving, sitting) {
        sent.add(x);
        sentSitting.add(sitting);
      };
      game.broadcastPosition();
      expect(sent, hasLength(1));

      // The Mage can sit on a bar stool: standing just in front of one
      // offers "Click to sit"; sitting moves her onto it, facing the bar,
      // with her seated animation, and tells the others.
      final seat = TavernMap.seats.first;
      final seatNearby = <bool>[];
      game.onSeatNearby = seatNearby.add;
      game.player.position.setValues(seat.x, seat.y + 45);
      await tester.pump(const Duration(milliseconds: 16));
      expect(seatNearby, [true]);
      expect(game.nearSeat, isTrue);
      game.interact();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.sitting, isTrue);
      expect(game.player.position, Vector2(seat.x, seat.y));
      expect(game.player.current, (Facing.north, Pose.sit));
      expect(sentSitting.last, isTrue);
      // The stool's front is its own sprite, drawn over her (her legs tuck
      // behind it).
      final stoolFront = game.world.children.whereType<SpriteComponent>().where(
        (c) => c.position == Vector2(seat.frontLeft, seat.frontTop),
      );
      expect(stoolFront, hasLength(1));
      expect(stoolFront.single.priority, greaterThan(game.player.priority));
      // Moving gets her up, back where she stood.
      game.player.walk(Vector2.zero(), 1 / 60);
      game.standUp();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.sitting, isFalse);
      expect(game.player.position, Vector2(seat.x, seat.y + 45));
      expect(game.player.current?.$2, isNot(Pose.sit));
      expect(sentSitting.last, isFalse);

      // Bernie stands behind the bar: the counter is drawn over him. His
      // name plate shows only while he's selected.
      final bernie = game.bernie;
      expect(bernie.isLoaded, isTrue);
      expect(bernie.size.y, closeTo(87, 0.01));
      final counter = game.world.children.whereType<SpriteComponent>().where(
        (c) =>
            c.position ==
            Vector2(
              TavernMap.barCounterFront.left,
              TavernMap.barCounterFront.top,
            ),
      );
      expect(counter, hasLength(1));
      expect(counter.single.priority, greaterThan(bernie.priority));
      expect(bernie.children.whereType<PositionComponent>(), isEmpty);
      bernie.selected = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(bernie.children.whereType<PositionComponent>(), hasLength(1));
      bernie.selected = false;
      await tester.pump(const Duration(milliseconds: 16));
      expect(bernie.children.whereType<PositionComponent>(), isEmpty);

      game.syncOtherPlayers([]);
      expect(game.otherPlayerCount, 0);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
