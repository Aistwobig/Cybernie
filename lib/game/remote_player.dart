import 'package:flame/components.dart';

import 'character.dart';

/// Another player in the room. Their game sends a position a few times a
/// second; in between, this glides toward the latest one so movement looks
/// smooth instead of jumping.
class RemotePlayer extends Character {
  RemotePlayer({
    required super.sheetAsset,
    required super.name,
    required Vector2 start,
  }) : _target = start.clone() {
    position = start.clone();
  }

  final Vector2 _target;

  /// Further than this (e.g. after lag), jump straight there instead.
  static const double _snapDistance = 250;

  void moveTo(Vector2 target, Facing newFacing, bool isMoving) {
    _target.setFrom(target);
    facing = newFacing;
    moving = isMoving;
    if (position.distanceTo(_target) > _snapDistance) {
      position.setFrom(_target);
    }
  }

  @override
  void update(double dt) {
    // Ease toward the target; fast enough to keep up with a walking player.
    final t = (dt * 12).clamp(0.0, 1.0);
    position.lerp(_target, t);
    super.update(dt);
  }
}
