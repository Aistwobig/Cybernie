import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import 'character.dart';

/// Bernie, the cat who runs the tavern: an NPC standing behind the bar with
/// a mug, playing his idle loop. Tap him to select him, which shows his
/// pixel name plate; tap him again (or anywhere else) to deselect.
class Bernie extends SpriteAnimationComponent
    with TapCallbacks, HasGameReference {
  Bernie({required Vector2 position})
    : super(position: position, anchor: Anchor(0.5, _feetLine / _cellH));

  static const String displayName = 'Bernie';

  // bernie_idle.png: 8 frames of 300 x 384, feet on row 374.
  static const double _cellW = 300;
  static const double _cellH = 384;
  static const double _feetLine = 374;
  static const int _frames = 8;

  /// Called when he's tapped (selected or deselected).
  void Function(bool selected)? onSelectedChanged;

  _PixelNamePlate? _plate;
  SpeechBubble? _bubble;
  bool _selected = false;
  bool get selected => _selected;

  set selected(bool value) {
    if (value == _selected) return;
    _selected = value;
    _plate?.removeFromParent();
    _plate = null;
    if (value && isLoaded) {
      final plate = _PixelNamePlate(displayName)
        ..position = Vector2(size.x / 2, 8)
        ..anchor = Anchor.bottomCenter
        ..scale = Vector2.all(0.6);
      plate.add(
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.18, curve: Curves.easeOutBack),
        ),
      );
      _plate = plate;
      add(plate);
    }
    onSelectedChanged?.call(value);
  }

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(AppImages.bernieIdle);
    animation = SpriteSheet(
      image: image,
      srcSize: Vector2(_cellW, _cellH),
    ).createAnimation(row: 0, stepTime: 0.2, to: _frames);
    // The same height as the players, so he's to scale.
    size = Vector2(_cellW, _cellH) * (Character.displayHeight / _cellH);
    priority = position.y.round();
    paint.filterQuality = FilterQuality.none;
  }

  /// Shows [text] in a speech bubble over his head (above the name plate
  /// while he's selected) for a few seconds.
  void say(String text) {
    if (!isLoaded) return;
    _bubble?.removeFromParent();
    final bubble = SpeechBubble(text)
      ..position = Vector2(size.x / 2, _selected ? -12 : 6)
      ..anchor = Anchor.bottomCenter;
    _bubble = bubble;
    add(bubble);
  }

  @override
  void onTapUp(TapUpEvent event) => selected = !selected;
}

/// "Bernie" in a pixel font on a small dark plate with a cream pixel border,
/// like a sign hung over his head.
class _PixelNamePlate extends PositionComponent {
  _PixelNamePlate(String text)
    : _painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            height: 1,
            color: Color(0xFFF5EFE0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout() {
    size = Vector2(
      (_painter.width + _padX * 2).ceilToDouble(),
      (_painter.height + _padY * 2).ceilToDouble(),
    );
  }

  final TextPainter _painter;

  static const double _padX = 4;
  static const double _padY = 3;

  static final Paint _fill = Paint()..color = const Color(0xF21B1712);
  static final Paint _border = Paint()..color = const Color(0xFFD4A86A);

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // A 1-pixel border with cut corners, drawn as pixel rectangles.
    canvas
      ..drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), _fill)
      ..drawRect(Rect.fromLTWH(1, 0, w - 2, 1), _border)
      ..drawRect(Rect.fromLTWH(1, h - 1, w - 2, 1), _border)
      ..drawRect(Rect.fromLTWH(0, 1, 1, h - 2), _border)
      ..drawRect(Rect.fromLTWH(w - 1, 1, 1, h - 2), _border)
      // A little pointer under the plate, toward his head.
      ..drawRect(Rect.fromLTWH(w / 2 - 1.5, h, 3, 1), _border)
      ..drawRect(Rect.fromLTWH(w / 2 - 0.5, h + 1, 1, 1), _border);
    _painter.paint(canvas, const Offset(_padX, _padY));
  }
}
