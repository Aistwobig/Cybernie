import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'character.dart';
import 'tavern_map.dart';

export 'character.dart' show Facing, Pose;

/// You. Moves from joystick / keyboard input and collides with the map.
///
/// Only a small box around the feet collides, so the character can stand in
/// front of tall furniture like in a top-down RPG.
class Player extends Character {
  Player({
    required super.sheetAsset,
    required super.name,
    super.idleSheetAsset,
    super.horizontalRunSheetAsset,
    super.feetFraction,
    super.frames,
    super.sitBackSheetAsset,
  });

  static const double speed = 170; // map pixels per second

  /// The part of the character that collides, relative to [position].
  static const double feetWidth = 28;
  static const double feetHeight = 12;

  Rect feetAt(double x, double y) =>
      Rect.fromLTWH(x - feetWidth / 2, y - feetHeight, feetWidth, feetHeight);

  Rect get feet => feetAt(position.x, position.y);

  /// Moves by [input] (each axis -1..1) for [dt] seconds, sliding along
  /// walls: each axis is tried on its own, so hitting a table while moving
  /// diagonally still lets you slide past it.
  void walk(Vector2 input, double dt) {
    if (!isLoaded) return;
    moving = input.length2 > 0.01;
    if (!moving) return;

    if (input.length > 1) input.normalize();
    final step = input * speed * speedMultiplier * dt;

    final nextX = position.x + step.x;
    if (!TavernMap.isBlocked(feetAt(nextX, position.y))) position.x = nextX;
    final nextY = position.y + step.y;
    if (!TavernMap.isBlocked(feetAt(position.x, nextY))) position.y = nextY;

    _face(input);
  }

  /// Slides by [step] without changing pose (e.g. being drawn toward a
  /// charming player), stopping at walls like walking does.
  void nudge(Vector2 step) {
    if (!isLoaded) return;
    final nextX = position.x + step.x;
    if (!TavernMap.isBlocked(feetAt(nextX, position.y))) position.x = nextX;
    final nextY = position.y + step.y;
    if (!TavernMap.isBlocked(feetAt(position.x, nextY))) position.y = nextY;
  }

  void _face(Vector2 input) {
    facing = input.x.abs() > input.y.abs()
        ? (input.x < 0 ? Facing.west : Facing.east)
        : (input.y < 0 ? Facing.north : Facing.south);
  }
}
