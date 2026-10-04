import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../constants/drinks.dart';
import '../constants/emotes.dart';

enum Facing { south, north, west, east }

/// What the character is doing; with [Facing] it picks the animation.
enum Pose { stand, walk, sit }

/// Anyone standing in the tavern: drawn from an 8-column x 4-row walk sheet
/// (rows face South, North, West, East) of any size, with a name tag and
/// chat bubbles. [Player] (you) and [RemotePlayer] (everyone else) build on
/// this.
///
/// [position] is the point between the character's feet.
abstract class Character extends SpriteAnimationGroupComponent<(Facing, Pose)>
    with HasGameReference {
  Character({
    required String sheetAsset,
    required String name,
    String? idleSheetAsset,
    String? horizontalRunSheetAsset,
    double feetFraction = 0.963,
    int frames = 8,
    String? sitBackSheetAsset,
  }) : _sheetAsset = sheetAsset,
       _idleSheetAsset = idleSheetAsset,
       _horizontalRunSheetAsset = horizontalRunSheetAsset,
       _sitBackSheetAsset = sitBackSheetAsset,
       _feetFraction = feetFraction,
       _frames = frames,
       _name = name,
       super(anchor: Anchor(0.5, feetFraction));

  String _sheetAsset;
  String? _idleSheetAsset;
  String? _horizontalRunSheetAsset;
  String? _sitBackSheetAsset;
  double _feetFraction;
  int _frames;
  String _name;

  String get sheetAsset => _sheetAsset;

  /// Every character is drawn this tall on the map, whatever its sheet's
  /// cell size, so different sprites stand at the same height.
  static const double displayHeight = 87;

  Facing facing = Facing.south;
  bool moving = false;

  /// Sitting on a seat, facing [facing]. Shown with the seated animation
  /// when the character has one for that direction.
  bool sitting = false;

  /// Whether this character has a seated animation facing [direction].
  bool canSitFacing(Facing direction) =>
      animations?.containsKey((direction, Pose.sit)) ?? false;
  SpeechBubble? _bubble;
  SpriteComponent? _emote;
  SpriteComponent? _drink;

  late final TextComponent _nameTag = TextComponent(
    text: _name,
    anchor: Anchor.bottomCenter,
    textRenderer: TextPaint(
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: [Shadow(blurRadius: 3, color: Colors.black)],
      ),
    ),
  );

  /// Counts sheet loads. A load that finishes after a newer one has started
  /// is thrown away, so a quick switch (e.g. the profile arriving while the
  /// default character is still loading) never mixes two characters' sheets.
  int _loads = 0;

  set name(String value) {
    _name = value;
    _nameTag.text = value;
  }

  @override
  Future<void> onLoad() async {
    add(_nameTag);
    await _loadSheet();
  }

  /// Switches to another character's sheet (e.g. once a player's chosen
  /// character is known).
  Future<void> useSheet(
    String asset,
    double feetFraction, {
    String? idleSheetAsset,
    String? horizontalRunSheetAsset,
    int frames = 8,
    String? sitBackSheetAsset,
  }) async {
    if (asset == _sheetAsset &&
        feetFraction == _feetFraction &&
        idleSheetAsset == _idleSheetAsset &&
        horizontalRunSheetAsset == _horizontalRunSheetAsset &&
        sitBackSheetAsset == _sitBackSheetAsset &&
        frames == _frames) {
      return;
    }
    _sheetAsset = asset;
    _idleSheetAsset = idleSheetAsset;
    _horizontalRunSheetAsset = horizontalRunSheetAsset;
    _sitBackSheetAsset = sitBackSheetAsset;
    _feetFraction = feetFraction;
    _frames = frames;
    // Not added to the game yet: onLoad will load the new sheet. Otherwise
    // load it now; this also supersedes a first load still in progress.
    if (isLoading || isLoaded) await _loadSheet();
  }

  /// Builds animations from the walk sheet ([_frames] columns x 4 rows),
  /// plus an optional idle sheet of the same layout and an optional 8 x 2
  /// left/right run sheet and an optional seated-from-behind strip.
  ///
  /// The idle and run sheets must use the same cell size and feet line as
  /// the walk sheet (assets/sheets has the tool notes), so switching between
  /// walking, running and standing never makes the character jump or resize.
  Future<void> _loadSheet() => _latestLoad = _load();

  /// The most recent sheet load; a superseded load waits for it instead.
  Future<void>? _latestLoad;

  Future<void> _load() async {
    final load = ++_loads;
    // Read every setting once, before any waiting, so the whole load
    // describes one character even if useSheet changes them meanwhile.
    final sheetAsset = _sheetAsset;
    final idleSheetAsset = _idleSheetAsset;
    final runSheetAsset = _horizontalRunSheetAsset;
    final sitBackAsset = _sitBackSheetAsset;
    final frames = _frames;
    final feetFraction = _feetFraction;

    final image = await game.images.load(sheetAsset);
    final idleImage = idleSheetAsset == null
        ? null
        : await game.images.load(idleSheetAsset);
    final runImage = runSheetAsset == null
        ? null
        : await game.images.load(runSheetAsset);
    final sitBackImage = sitBackAsset == null
        ? null
        : await game.images.load(sitBackAsset);
    // A newer character was picked meanwhile: finish when that one has.
    if (load != _loads) return _latestLoad;

    final cell = Vector2(image.width / frames, image.height / 4);
    final walkSheet = SpriteSheet(image: image, srcSize: cell);
    // A whole cycle lasts as long as 8 frames would, however many there are.
    final perFrame = 8 / frames;
    final idleSheet = idleImage == null
        ? null
        : SpriteSheet(
            image: idleImage,
            srcSize: Vector2(idleImage.width / frames, idleImage.height / 4),
          );
    final runSheet = runImage == null
        ? null
        : SpriteSheet(
            image: runImage,
            srcSize: Vector2(runImage.width / 8, runImage.height / 2),
          );

    final builtAnimations = <(Facing, Pose), SpriteAnimation>{};
    for (final facing in Facing.values) {
      builtAnimations[(facing, Pose.walk)] = walkSheet.createAnimation(
        row: facing.index,
        stepTime: 0.09 * perFrame,
      );
      // Standing still: the idle cycle if there is one, otherwise the first
      // walk frame held still (not the whole walk played slowly).
      builtAnimations[(facing, Pose.stand)] = idleSheet != null
          ? idleSheet.createAnimation(
              row: facing.index,
              stepTime: 0.2 * perFrame,
            )
          : walkSheet.createAnimation(row: facing.index, stepTime: 1, to: 1);
    }
    if (runSheet != null) {
      builtAnimations[(Facing.west, Pose.walk)] = runSheet.createAnimation(
        row: 0,
        stepTime: 0.09,
      );
      builtAnimations[(Facing.east, Pose.walk)] = runSheet.createAnimation(
        row: 1,
        stepTime: 0.09,
      );
    }
    if (sitBackImage != null) {
      builtAnimations[(Facing.north, Pose.sit)] = SpriteSheet(
        image: sitBackImage,
        srcSize: Vector2(
          sitBackImage.width / frames,
          sitBackImage.height.toDouble(),
        ),
      ).createAnimation(row: 0, stepTime: 0.2 * perFrame);
    }
    animations = builtAnimations;
    current = _pose;
    size = cell * (displayHeight / cell.y);
    anchor = Anchor(0.5, feetFraction);
    _nameTag.position = Vector2(size.x / 2, 2);
    // Keep pixel art crisp when scaled.
    paint.filterQuality = FilterQuality.none;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;
    final pose = _pose;
    if (current != pose) current = pose;
    // Whoever is lower on screen is drawn in front.
    priority = position.y.round();
  }

  /// The animation to show now. Sitting without a seated animation for
  /// this direction falls back to standing.
  (Facing, Pose) get _pose {
    if (sitting && canSitFacing(facing)) return (facing, Pose.sit);
    return (facing, moving ? Pose.walk : Pose.stand);
  }

  /// Shows [text] in a speech bubble above the name tag for a few seconds.
  void say(String text) {
    if (!isLoaded) return;
    _bubble?.removeFromParent();
    final bubble = SpeechBubble(text)
      ..position = Vector2(size.x / 2, -16)
      ..anchor = Anchor.bottomCenter;
    _bubble = bubble;
    add(bubble);
  }

  /// How big a held drink is drawn, and for how long it's held.
  static const double drinkSize = 22;
  static const double drinkSeconds = 10;

  /// Shows [drink] (sent as its id, see drinks.dart) held up beside the
  /// head for [drinkSeconds], with a little sip now and then.
  Future<void> holdDrink(String id) async {
    final drink = drinkById(id);
    if (!isLoaded || drink == null) return;
    final image = await game.images.load(drink.asset);
    if (!isMounted) return;
    _drink?.removeFromParent();
    final mug = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2.all(drinkSize),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x * 0.12, 30),
      scale: Vector2.all(0.2),
    )..paint.filterQuality = FilterQuality.none;
    mug.addAll([
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.3, curve: Curves.easeOutBack),
      ),
      // A sip every few seconds: a quick tilt and back.
      RotateEffect.by(
        -0.35,
        EffectController(
          duration: 0.25,
          reverseDuration: 0.35,
          startDelay: 2,
          infinite: true,
        ),
      ),
      RemoveEffect(delay: drinkSeconds),
    ]);
    _drink = mug;
    add(mug);
  }

  /// How big emotes are drawn on the map.
  static const double emoteSize = 34;

  /// Pops the emote sent as [id] (see emotes.dart) up beside the head,
  /// floats it upward, then removes it.
  Future<void> emote(String id) async {
    final picked = emoteById(id);
    if (!isLoaded || picked == null) return;
    final image = await game.images.load(picked.asset);
    if (!isMounted) return;
    _emote?.removeFromParent();
    final emote = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2.all(emoteSize),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x * 0.9, 14),
      scale: Vector2.all(0.2),
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
class SpeechBubble extends PositionComponent {
  SpeechBubble(String text)
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
