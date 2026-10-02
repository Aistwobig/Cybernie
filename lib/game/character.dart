import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

enum Facing { south, north, west, east }

/// Anyone standing in the tavern: drawn from an 8-column x 4-row walk sheet
/// (rows face South, North, West, East) of any size, with a name tag and
/// chat bubbles. [Player] (you) and [RemotePlayer] (everyone else) build on
/// this.
///
/// [position] is the point between the character's feet.
abstract class Character extends SpriteAnimationGroupComponent<(Facing, bool)>
    with HasGameReference {
  Character({
    required String sheetAsset,
    required String name,
    String? idleSheetAsset,
    String? horizontalRunSheetAsset,
    double feetFraction = 0.963,
  }) : _sheetAsset = sheetAsset,
       _idleSheetAsset = idleSheetAsset,
       _horizontalRunSheetAsset = horizontalRunSheetAsset,
       _feetFraction = feetFraction,
       _name = name,
       super(anchor: Anchor(0.5, feetFraction));

  String _sheetAsset;
  String? _idleSheetAsset;
  String? _horizontalRunSheetAsset;
  double _feetFraction;
  String _name;

  String get sheetAsset => _sheetAsset;

  /// Every character is drawn this tall on the map, whatever its sheet's
  /// cell size, so different sprites stand at the same height.
  static const double displayHeight = 87;

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
    await _loadSheet();

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

  /// Switches to another character's sheet (e.g. once a player's chosen
  /// character is known).
  Future<void> useSheet(
    String asset,
    double feetFraction, {
    String? idleSheetAsset,
    String? horizontalRunSheetAsset,
  }) async {
    if (asset == _sheetAsset &&
        feetFraction == _feetFraction &&
        idleSheetAsset == _idleSheetAsset &&
        horizontalRunSheetAsset == _horizontalRunSheetAsset) {
      return;
    }
    _sheetAsset = asset;
    _idleSheetAsset = idleSheetAsset;
    _horizontalRunSheetAsset = horizontalRunSheetAsset;
    _feetFraction = feetFraction;
    if (!isLoaded) return; // onLoad will pick up the new sheet.
    await _loadSheet();
    _nameTag.position = Vector2(size.x / 2, 2);
  }

  /// Builds animations from the 8 x 4 walk sheet, plus an optional 8 x 4
  /// idle sheet and an optional 8 x 2 left/right run sheet.
  ///
  /// The idle and run sheets must use the same cell size and feet line as
  /// the walk sheet (assets/sheets has the tool notes), so switching between
  /// walking, running and standing never makes the character jump or resize.
  Future<void> _loadSheet() async {
    final image = await game.images.load(_sheetAsset);
    final cell = Vector2(image.width / 8, image.height / 4);
    final walkSheet = SpriteSheet(image: image, srcSize: cell);

    final idleImage = _idleSheetAsset == null
        ? null
        : await game.images.load(_idleSheetAsset!);
    final idleSheet = idleImage == null
        ? null
        : SpriteSheet(
            image: idleImage,
            srcSize: Vector2(idleImage.width / 8, idleImage.height / 4),
          );
    final runImage = _horizontalRunSheetAsset == null
        ? null
        : await game.images.load(_horizontalRunSheetAsset!);
    final runSheet = runImage == null
        ? null
        : SpriteSheet(
            image: runImage,
            srcSize: Vector2(runImage.width / 8, runImage.height / 2),
          );

    final builtAnimations = <(Facing, bool), SpriteAnimation>{};
    for (final facing in Facing.values) {
      builtAnimations[(facing, true)] = walkSheet.createAnimation(
        row: facing.index,
        stepTime: 0.09,
      );
      // Standing still: the idle cycle if there is one, otherwise the first
      // walk frame held still (not the whole walk played slowly).
      builtAnimations[(facing, false)] = idleSheet != null
          ? idleSheet.createAnimation(row: facing.index, stepTime: 0.2)
          : walkSheet.createAnimation(row: facing.index, stepTime: 1, to: 1);
    }
    if (runSheet != null) {
      builtAnimations[(Facing.west, true)] = runSheet.createAnimation(
        row: 0,
        stepTime: 0.09,
      );
      builtAnimations[(Facing.east, true)] = runSheet.createAnimation(
        row: 1,
        stepTime: 0.09,
      );
    }
    animations = builtAnimations;
    current = (facing, moving);
    size = cell * (displayHeight / cell.y);
    anchor = Anchor(0.5, _feetFraction);
    // Keep pixel art crisp when scaled.
    paint.filterQuality = FilterQuality.none;
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
