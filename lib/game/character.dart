import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

enum Facing { south, north, west, east }

/// Anyone standing in the tavern: drawn from an 8-column x 4-row walk sheet
/// (menanim.png: rows are South, North, West, East), with a name tag and
/// chat bubbles. [Player] (you) and [RemotePlayer] (everyone else) build on
/// this.
///
/// [position] is the point between the character's feet.
abstract class Character extends SpriteAnimationGroupComponent<(Facing, bool)>
    with HasGameReference {
  Character({required this.sheetAsset, required String name})
    : _name = name,
      super(anchor: const Anchor(0.5, _feetY / _cellHeight));

  final String sheetAsset;
  String _name;

  static const double _cellWidth = 265;
  static const double _cellHeight = 378;
  static const double _feetY = 345; // where the shoes sit inside a cell
  static const double _scale = 0.23; // cell size -> size on the map

  Facing facing = Facing.south;
  bool moving = false;
  late final TextComponent _nameTag;
  _ChatBubble? _bubble;
  TextComponent? _emote;

  set name(String value) {
    _name = value;
    if (isLoaded) _nameTag.text = value;
  }

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(sheetAsset);
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(_cellWidth, _cellHeight),
    );

    animations = {
      for (final facing in Facing.values) ...{
        (facing, true): sheet.createAnimation(
          row: facing.index,
          stepTime: 0.09,
        ),
        (facing, false): sheet.createAnimation(
          row: facing.index,
          stepTime: 1,
          to: 1,
        ),
      },
    };
    current = (facing, moving);
    size = Vector2(_cellWidth, _cellHeight) * _scale;
    // Keep pixel art crisp when scaled.
    paint.filterQuality = FilterQuality.none;

    _nameTag = TextComponent(
      text: _name,
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, 2),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
    );
    add(_nameTag);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;
    final pose = (facing, moving);
    if (current != pose) current = pose;
    // Whoever is lower on screen is drawn in front.
    priority = position.y.round();
  }

  /// Shows [text] in a speech bubble above the name tag for a few seconds.
  void say(String text) {
    if (!isLoaded) return;
    _bubble?.removeFromParent();
    final bubble = _ChatBubble(text)
      ..position = Vector2(size.x / 2, -16)
      ..anchor = Anchor.bottomCenter;
    _bubble = bubble;
    add(bubble);
  }

  /// Pops [emoji] up beside the head, floats it upward, then removes it.
  void emote(String emoji) {
    if (!isLoaded) return;
    _emote?.removeFromParent();
    final emote = TextComponent(
      text: emoji,
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x * 0.9, 14),
      scale: Vector2.all(0.2),
      textRenderer: TextPaint(style: const TextStyle(fontSize: 30)),
    );
    emote.addAll([
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.3, curve: Curves.easeOutBack),
      ),
      MoveByEffect(
        Vector2(0, -18),
        EffectController(duration: 2.2, curve: Curves.easeOutCubic),
      ),
      RemoveEffect(delay: 2.4),
    ]);
    _emote = emote;
    add(emote);
  }
}

/// A parchment speech bubble that removes itself after [_lifetime] seconds.
class _ChatBubble extends PositionComponent {
  _ChatBubble(String text)
    : _painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1B1712),
            height: 1.25,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: 170);

  final TextPainter _painter;
  static const double _padding = 7;
  static const double _lifetime = 5;
  double _age = 0;

  @override
  Future<void> onLoad() async {
    size = Vector2(
      _painter.width + _padding * 2,
      _painter.height + _padding * 2,
    );
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age > _lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(6),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xF2F5EFE0));
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFF1B1712)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _painter.paint(canvas, const Offset(_padding, _padding));
  }
}
