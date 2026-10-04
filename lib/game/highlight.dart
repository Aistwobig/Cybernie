import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Gold used for "you can use this" highlights.
const Color highlightGold = Color(0xFFFFC966);

/// Draws a soft gold glow around [sprite]'s shape (drawn at [size]), at
/// [strength] 0..1. Call before drawing the sprite itself, so the glow only
/// shows around its edges.
void renderGlow(Canvas canvas, Sprite sprite, Vector2 size, double strength) {
  if (strength <= 0) return;
  final bounds = Rect.fromLTWH(-12, -12, size.x + 24, size.y + 24);
  canvas.saveLayer(
    bounds,
    Paint()
      ..imageFilter = ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5)
      ..colorFilter = ColorFilter.mode(
        highlightGold.withValues(alpha: strength.clamp(0.0, 1.0)),
        BlendMode.srcIn,
      ),
  );
  // Twice, a pixel apart, so the glow reads as an outline and not just haze.
  sprite.render(canvas, size: size);
  sprite.render(canvas, position: Vector2(0, -1), size: size);
  canvas.restore();
}

/// Fades a highlight in and out and makes it pulse while it's on.
class GlowPulse {
  double _level = 0;
  double _time = 0;

  /// Advances by [dt]; [on] says whether the glow should be showing, and
  /// [strong] makes it brighter (for something not used yet).
  double update(double dt, {required bool on, bool strong = false}) {
    _time += dt;
    final target = on ? 1.0 : 0.0;
    _level += (target - _level) * math.min(1, dt * 6);
    final pulse = 0.75 + 0.25 * math.sin(_time * 3);
    return _level * pulse * (strong ? 0.95 : 0.7);
  }
}

/// Something the player can use (Bernie, the notice board) that can glow
/// and carry a "!" marker. Draw the glow with [renderGlow] using [glow].
mixin Highlightable on PositionComponent {
  /// Glows (gently) while true, e.g. while the player is close enough.
  bool highlighted = false;

  /// Glows brighter and shows a "!" above, for a player who hasn't used it
  /// yet.
  bool showHint = false;

  /// Where the "!" sits (its bottom centre), relative to the component.
  Vector2 get hintPosition => Vector2(size.x / 2, 0);

  /// Hides the "!" for a moment (e.g. while a name plate is in its place).
  bool get hideHint => false;

  HintMarker? _hint;
  final GlowPulse _pulse = GlowPulse();

  /// The glow strength to draw this frame.
  double get glow => _glow;
  double _glow = 0;

  @override
  void update(double dt) {
    super.update(dt);
    // Added here rather than when [showHint] is set, once the size is known.
    if (showHint && _hint == null) {
      _hint = HintMarker()..position = hintPosition;
      add(_hint!);
    } else if (!showHint && _hint != null) {
      _hint!.removeFromParent();
      _hint = null;
    }
    _hint?.scale = Vector2.all(hideHint ? 0 : 1);
    _glow = _pulse.update(dt, on: highlighted || showHint, strong: showHint);
  }
}

/// A piece of the map picture drawn again over the map so it can glow
/// (the notice board).
class HighlightableCutout extends SpriteComponent with Highlightable {
  HighlightableCutout({
    required super.sprite,
    required super.position,
    required super.size,
    super.priority,
  });

  @override
  void render(Canvas canvas) {
    final sprite = this.sprite;
    if (sprite != null) renderGlow(canvas, sprite, size, glow);
    super.render(canvas);
  }
}

/// A small bobbing "!" sign in the pixel style of Bernie's name plate, over
/// something the player hasn't tried yet.
class HintMarker extends PositionComponent {
  HintMarker()
    : _painter = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            height: 1,
            color: Color(0xFF1B1712),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
      super(size: Vector2(12, 14), anchor: Anchor.bottomCenter);

  final TextPainter _painter;
  double _time = 0;
  late final double _baseY = position.y;

  static final Paint _fill = Paint()..color = highlightGold;
  static final Paint _border = Paint()..color = const Color(0xFF1B1712);

  @override
  void update(double dt) {
    _time += dt;
    // A little hop every second or so.
    position.y = _baseY - (math.sin(_time * 4).abs() * 3);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y - 3;
    // Pixel plate with cut corners and a pointer underneath.
    canvas
      ..drawRect(Rect.fromLTWH(1, 0, w - 2, 1), _border)
      ..drawRect(Rect.fromLTWH(1, h - 1, w - 2, 1), _border)
      ..drawRect(Rect.fromLTWH(0, 1, 1, h - 2), _border)
      ..drawRect(Rect.fromLTWH(w - 1, 1, 1, h - 2), _border)
      ..drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), _fill)
      ..drawRect(Rect.fromLTWH(w / 2 - 1.5, h, 3, 1), _border)
      ..drawRect(Rect.fromLTWH(w / 2 - 0.5, h + 1, 1, 1), _border);
    _painter.paint(
      canvas,
      Offset((w - _painter.width) / 2 + 0.5, (h - _painter.height) / 2 + 0.5),
    );
  }
}
