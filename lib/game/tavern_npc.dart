import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A townsfolk NPC who just idles in place (the bard by the door, two
/// friends having a drink at a table): one strip of equal frames, played on
/// a loop, layered by its bottom edge like everyone else.
class TavernNpc extends SpriteAnimationComponent with HasGameReference {
  TavernNpc({
    required this.asset,
    required this.frames,
    required this.cell,
    required this.baseline,
    required this.scaleBy,
    required this.stepTime,
    required Vector2 feet,
  }) : super(position: feet, anchor: Anchor(0.5, baseline / cell.y));

  /// The bard by the door, strumming his lute.
  factory TavernNpc.bard(Vector2 feet) => TavernNpc(
    asset: 'assets/images/npc_bard.png',
    frames: 8,
    cell: Vector2(270, 300),
    baseline: 290,
    scaleBy: 0.37,
    stepTime: 0.2,
    feet: feet,
  );

  /// The two adventurers drinking at the table by the stairs, seated on
  /// its painted chairs facing each other (cut from one picture, so they
  /// move in step: 7 frames, anchored at the hips).
  factory TavernNpc.drinker({required bool girl, required Vector2 hips}) =>
      TavernNpc(
        asset: girl
            ? 'assets/images/npc_girl.png'
            : 'assets/images/npc_boy.png',
        frames: 7,
        cell: Vector2(140, 200),
        baseline: 170,
        scaleBy: 0.47,
        stepTime: 0.3,
        feet: hips,
      );

  final String asset;
  final int frames;
  final Vector2 cell;
  final double baseline;
  final double scaleBy;
  final double stepTime;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(asset);
    animation = SpriteSheet(
      image: image,
      srcSize: cell,
    ).createAnimation(row: 0, stepTime: stepTime, to: frames);
    size = cell * scaleBy;
    priority = position.y.round();
    paint
      ..filterQuality = FilterQuality.medium
      ..colorFilter = AppColors.artFilter;
  }
}
