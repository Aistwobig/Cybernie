import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A townsfolk NPC who just idles in place (the bard by the door, the
/// couple having a drink at a table): one strip of equal frames, played on
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
    scaleBy: 0.31,
    stepTime: 0.2,
    feet: feet,
  );

  /// Two adventurers at their table, chatting and clinking mugs. Their table
  /// replaces the one painted there (removed from the map picture).
  factory TavernNpc.couple(Vector2 bottom) => TavernNpc(
    asset: 'assets/images/npc_couple.png',
    frames: 8,
    cell: Vector2(230, 230),
    baseline: 224,
    scaleBy: 0.85,
    stepTime: 0.28,
    feet: bottom,
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
