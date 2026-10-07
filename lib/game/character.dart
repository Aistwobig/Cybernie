import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../constants/drinks.dart';
import '../constants/emotes.dart';
import '../theme/app_theme.dart';

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
    String? sitSideSheetAsset,
    String? sitFrontSheetAsset,
  }) : _sheetAsset = sheetAsset,
       _idleSheetAsset = idleSheetAsset,
       _horizontalRunSheetAsset = horizontalRunSheetAsset,
       _sitBackSheetAsset = sitBackSheetAsset,
       _sitSideSheetAsset = sitSideSheetAsset,
       _sitFrontSheetAsset = sitFrontSheetAsset,
       _feetFraction = feetFraction,
       _frames = frames,
       _name = name,
       super(anchor: Anchor(0.5, feetFraction));

  String _sheetAsset;
  String? _idleSheetAsset;
  String? _horizontalRunSheetAsset;
  String? _sitBackSheetAsset;
  String? _sitSideSheetAsset;
  String? _sitFrontSheetAsset;
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

  /// While sitting, drawn over the stool's front instead of behind it.
  bool sitsOverSeat = false;

  /// Lifts a seated [sitsOverSeat] character above the stool front, whose
  /// bottom edge is at most this far below the seat.
  static const int _overSeatLift = 26;

  /// Whether this character has a seated animation facing [direction].
  bool canSitFacing(Facing direction) =>
      animations?.containsKey((direction, Pose.sit)) ?? false;
  SpeechBubble? _bubble;
  SpriteComponent? _drink;

  late final NamePlate _nameTag = NamePlate(_name)
    ..anchor = Anchor.bottomCenter;

  /// This player's camera, drawn just above the name tag while it's on.
  CameraPicture? _camera;

  /// Shows (or hides) this player's camera above the name tag. [mirror]:
  /// flipped like a mirror (our own camera, as people expect to see
  /// themselves). [turns]: quarter turns clockwise to stand the picture
  /// upright (a phone held sideways sends it lying on its side).
  void showCamera(bool on, {bool mirror = false, int turns = 0}) {
    _camera?.turns = turns;
    if (on == (_camera != null)) return;
    if (on) {
      final picture = CameraPicture(mirror: mirror)..turns = turns;
      _camera = picture;
      add(picture);
    } else {
      _camera?.removeFromParent();
      _camera = null;
    }
    _bubble?.y = _bubbleY;
    _typing?.y = _bubbleY;
  }

  /// The camera's newest frame (disposed here once it's replaced or unused).
  set cameraFrame(ui.Image image) {
    final camera = _camera;
    if (camera == null) {
      image.dispose();
    } else {
      camera.frame = image;
    }
  }

  /// Speech and "..." bubbles sit above the name tag, or above the camera
  /// picture while it's shown.
  double get _bubbleY =>
      _camera == null ? -16 : -16 - CameraPicture.pictureSize.y - 6;

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
    String? sitSideSheetAsset,
    String? sitFrontSheetAsset,
  }) async {
    if (asset == _sheetAsset &&
        feetFraction == _feetFraction &&
        idleSheetAsset == _idleSheetAsset &&
        horizontalRunSheetAsset == _horizontalRunSheetAsset &&
        sitBackSheetAsset == _sitBackSheetAsset &&
        sitSideSheetAsset == _sitSideSheetAsset &&
        sitFrontSheetAsset == _sitFrontSheetAsset &&
        frames == _frames) {
      return;
    }
    _sheetAsset = asset;
    _idleSheetAsset = idleSheetAsset;
    _horizontalRunSheetAsset = horizontalRunSheetAsset;
    _sitBackSheetAsset = sitBackSheetAsset;
    _sitSideSheetAsset = sitSideSheetAsset;
    _sitFrontSheetAsset = sitFrontSheetAsset;
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

  /// Completes once the current character's sheets are loaded and in use.
  Future<void> get sheetsReady async {
    await loaded;
    await _latestLoad;
  }

  Future<void> _load() async {
    final load = ++_loads;
    // Read every setting once, before any waiting, so the whole load
    // describes one character even if useSheet changes them meanwhile.
    final sheetAsset = _sheetAsset;
    final idleSheetAsset = _idleSheetAsset;
    final runSheetAsset = _horizontalRunSheetAsset;
    final sitBackAsset = _sitBackSheetAsset;
    final sitSideAsset = _sitSideSheetAsset;
    final sitFrontAsset = _sitFrontSheetAsset;
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
    final sitSideImage = sitSideAsset == null
        ? null
        : await game.images.load(sitSideAsset);
    final sitFrontImage = sitFrontAsset == null
        ? null
        : await game.images.load(sitFrontAsset);
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
    if (sitSideImage != null) {
      final sideSheet = SpriteSheet(
        image: sitSideImage,
        srcSize: Vector2(sitSideImage.width / frames, sitSideImage.height / 2),
      );
      builtAnimations[(Facing.west, Pose.sit)] = sideSheet.createAnimation(
        row: 0,
        stepTime: 0.2 * perFrame,
      );
      builtAnimations[(Facing.east, Pose.sit)] = sideSheet.createAnimation(
        row: 1,
        stepTime: 0.2 * perFrame,
      );
    }
    if (sitFrontImage != null) {
      builtAnimations[(Facing.south, Pose.sit)] = SpriteSheet(
        image: sitFrontImage,
        srcSize: Vector2(
          sitFrontImage.width / frames,
          sitFrontImage.height.toDouble(),
        ),
      ).createAnimation(row: 0, stepTime: 0.2 * perFrame);
    }
    animations = builtAnimations;
    current = _pose;
    size = cell * (displayHeight / cell.y);
    anchor = Anchor(0.5, feetFraction);
    _nameTag.position = Vector2(size.x / 2, 2);
    // Keep pixel art crisp when scaled.
    paint
      ..filterQuality = FilterQuality.none
      // At night: the gentler tint, so characters stay brighter than the
      // dimmed tavern around them.
      ..colorFilter = AppColors.artFilter;
  }

  /// Drink effects still running, with the seconds they have left.
  final Map<DrinkEffect, double> _effects = {};
  double _effectClock = 0;
  double _nextPuff = 0;

  bool hasEffect(DrinkEffect effect) => _effects.containsKey(effect);

  /// Seconds left on [effect] (0 when it isn't running).
  double effectLeft(DrinkEffect effect) => _effects[effect] ?? 0;

  /// Goblin Cider makes you walk this much faster.
  static const double swiftBoost = 1.7;

  double get speedMultiplier => hasEffect(DrinkEffect.swift) ? swiftBoost : 1;

  /// Starts (or restarts) [drink]'s effect.
  void applyDrinkEffect(Drink drink) {
    _effects[drink.effect] = drink.effectSeconds.toDouble();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;
    final pose = _pose;
    if (current != pose) current = pose;
    _updateEffects(dt);
    // Whoever is lower on screen is drawn in front.
    priority =
        position.y.round() +
        (sitting && sitsOverSeat && canSitFacing(facing) ? _overSeatLift : 0);
  }

  void _updateEffects(double dt) {
    _effectClock += dt;
    _effects.updateAll((_, left) => left - dt);
    _effects.removeWhere((_, left) => left <= 0);

    // Ale: a merry sway from the feet.
    angle = hasEffect(DrinkEffect.tipsy)
        ? math.sin(_effectClock * 3.2) * 0.07
        : 0;

    _nextPuff -= dt;
    if (_nextPuff > 0) return;
    if (hasEffect(DrinkEffect.swift) && moving) {
      _puff('✦', const Color(0xFF7CFF6B), rise: 6, life: 0.5, size: 9);
      _nextPuff = 0.12;
    } else if (hasEffect(DrinkEffect.hearts)) {
      _puff('♥', const Color(0xFFFF5C8A), rise: 26, life: 1.4, size: 11);
      _nextPuff = 0.45;
    } else if (hasEffect(DrinkEffect.tipsy)) {
      _puff('°', const Color(0xFFFFE9A8), rise: 22, life: 1.2, size: 13);
      _nextPuff = 0.35;
    }
  }

  final math.Random _random = math.Random();

  /// A little symbol that floats up from the character and fades out.
  void _puff(
    String symbol,
    Color color, {
    required double rise,
    required double life,
    required double size,
  }) {
    final puff = TextComponent(
      text: symbol,
      anchor: Anchor.center,
      position: Vector2(
        this.size.x * (0.3 + 0.4 * _random.nextDouble()),
        this.size.y * (moving ? 0.85 : 0.35 + 0.3 * _random.nextDouble()),
      ),
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: size,
          color: color,
          shadows: const [Shadow(blurRadius: 2, color: Color(0x99000000))],
        ),
      ),
    );
    puff.addAll([
      MoveByEffect(
        Vector2((_random.nextDouble() - 0.5) * 10, -rise),
        EffectController(duration: life, curve: Curves.easeOut),
      ),
      OpacityEffect.fadeOut(EffectController(duration: life)),
      RemoveEffect(delay: life),
    ]);
    add(puff);
  }

  @override
  void render(Canvas canvas) {
    if (hasEffect(DrinkEffect.glow)) _renderMoonGlow(canvas);
    super.render(canvas);
    if (speaking) _renderSpeaking(canvas);
  }

  /// Talking in voice chat: little sound waves pulse beside the name.
  bool speaking = false;

  static final Paint _wave = Paint()
    ..color = const Color(0xFF7CFF8A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  void _renderSpeaking(Canvas canvas) {
    // To the right of the name tag (which sits centred at the top).
    final x = size.x / 2 + _nameTag.width / 2 + 4;
    const y = -5.0;
    canvas.drawCircle(Offset(x, y), 2, Paint()..color = _wave.color);
    final beat = (_effectClock * 3) % 1;
    for (var i = 0; i < 2; i++) {
      final r = 4.0 + i * 3.5 + beat * 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r),
        -0.7,
        1.4,
        false,
        _wave..color = _wave.color.withValues(alpha: 1 - i * 0.35 - beat * 0.3),
      );
    }
    _wave.color = const Color(0xFF7CFF8A);
  }

  /// Moonberry: a pale blue glow around the character, pulsing gently.
  /// At night it's bigger and lights up the floor around them.
  void _renderMoonGlow(Canvas canvas) {
    final night = AppColors.sceneFilter != null;
    final pulse = 0.85 + 0.15 * math.sin(_effectClock * 2.4);
    // Fades out over the last 3 seconds.
    final fade = (effectLeft(DrinkEffect.glow) / 3).clamp(0.0, 1.0);
    final centre = Offset(size.x / 2, size.y * 0.55);
    // At night it's a lantern: a wide pool of light you can see by.
    final radius = size.y * (night ? 2.2 : 0.7) * pulse;
    const moon = Color(0xFFBFE3FF);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..blendMode = night ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [
            moon.withValues(alpha: (night ? 0.5 : 0.45) * fade),
            moon.withValues(alpha: (night ? 0.28 : 0.15) * fade),
            moon.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
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
    // Their message arrived, so they're done typing.
    showTyping(false);
    _bubble?.removeFromParent();
    final bubble = SpeechBubble(text)
      ..position = Vector2(size.x / 2, _bubbleY)
      ..anchor = Anchor.bottomCenter;
    _bubble = bubble;
    add(bubble);
  }

  TypingBubble? _typing;

  /// Shows (or hides) a "..." bubble above the head while this player is
  /// writing a chat message. It takes the place of their last speech bubble
  /// (they're on to the next message).
  void showTyping(bool typing) {
    if (!typing) {
      _typing?.removeFromParent();
      _typing = null;
      return;
    }
    if (!isLoaded || (_typing?.isMounted ?? false)) return;
    _bubble?.removeFromParent();
    final bubble = TypingBubble()
      ..position = Vector2(size.x / 2, _bubbleY)
      ..anchor = Anchor.bottomCenter;
    _typing = bubble;
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

  /// At most this many emotes float over a head at once (spamming stacks
  /// them; the oldest goes first).
  static const int maxEmotes = 12;
  final List<SpriteComponent> _emotes = [];
  final math.Random _emoteRandom = math.Random();

  /// Pops the emote sent as [id] (see emotes.dart) up beside the head and
  /// floats it upward, drifting a little, then removes it. Sending several
  /// quickly stacks them, each on its own path.
  Future<void> emote(String id) async {
    final picked = emoteById(id);
    if (!isLoaded || picked == null) return;
    final image = await game.images.load(picked.asset);
    if (!isMounted) return;
    _emotes.removeWhere((e) => !e.isMounted && e.isRemoved);
    while (_emotes.length >= maxEmotes) {
      _emotes.removeAt(0).removeFromParent();
    }
    final jitter = (_emoteRandom.nextDouble() - 0.5) * 16;
    final drift = (_emoteRandom.nextDouble() - 0.5) * 14;
    final emote = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2.all(emoteSize),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x * 0.9 + jitter, 14),
      scale: Vector2.all(0.2),
    );
    emote.addAll([
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.3, curve: Curves.easeOutBack),
      ),
      MoveByEffect(
        Vector2(drift, -18 - _emoteRandom.nextDouble() * 10),
        EffectController(duration: 2.2, curve: Curves.easeOutCubic),
      ),
      RemoveEffect(
        delay: 2.4,
        onComplete: () => _emotes.remove(emote),
      ),
    ]);
    _emotes.add(emote);
    add(emote);
  }
}

/// A player's camera, in a copper frame just above their name tag (green
/// while they talk). Part of the character, so it moves exactly with them.
class CameraPicture extends PositionComponent with ParentIsA<Character> {
  CameraPicture({required this.mirror})
    : super(size: pictureSize.clone(), anchor: Anchor.bottomCenter);

  /// In map pixels (4:3).
  static final Vector2 pictureSize = Vector2(92, 69);

  final bool mirror;

  /// Quarter turns clockwise that stand the frames upright.
  int turns = 0;
  ui.Image? _frame;

  set frame(ui.Image image) {
    _frame?.dispose();
    _frame = image;
  }

  static const double _border = 2;
  static const Radius _corner = Radius.circular(6);

  @override
  void update(double dt) {
    super.update(dt);
    // Just above the name tag (whose bottom edge sits at its position).
    final tag = parent._nameTag;
    position.setValues(parent.size.x / 2, tag.position.y - tag.size.y - 3);
  }

  @override
  void render(Canvas canvas) {
    final box = size.toRect();
    final outer = RRect.fromRectAndRadius(box, _corner);
    canvas.drawRRect(
      outer.shift(const Offset(0, 1.5)),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..color = parent.speaking
            ? const Color(0xFF7CFF8A)
            : const Color(0xFFB8742E),
    );
    final inner = RRect.fromRectAndRadius(
      box.deflate(_border),
      _corner - const Radius.circular(_border),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xFF1A0F08));
    final frame = _frame;
    if (frame == null) return;
    // Fill the box, cropping the frame's longer side (like object-fit:
    // cover). The frame is first turned upright (a sideways frame fills
    // the box with its sides swapped), then mirrored if it's ours.
    final target = inner.outerRect;
    final sideways = turns.isOdd;
    final dw = sideways ? target.height : target.width;
    final dh = sideways ? target.width : target.height;
    final fw = frame.width.toDouble(), fh = frame.height.toDouble();
    final scale = math.max(dw / fw, dh / fh);
    final sw = dw / scale, sh = dh / scale;
    final source = Rect.fromLTWH((fw - sw) / 2, (fh - sh) / 2, sw, sh);
    canvas
      ..save()
      ..clipRRect(inner)
      ..translate(target.center.dx, target.center.dy);
    if (mirror) canvas.scale(-1, 1);
    canvas
      ..rotate(turns * math.pi / 2)
      ..drawImageRect(
        frame,
        source,
        Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }

  @override
  void onRemove() {
    _frame?.dispose();
    _frame = null;
    super.onRemove();
  }
}

/// A player's name on the riveted plate from the HUD kit, with a green
/// "online" light on its left.
class NamePlate extends PositionComponent with HasGameReference {
  NamePlate(String text) {
    this.text = text;
  }

  static const String asset = 'assets/images/th_name.png';

  /// The plate picture's stretchable middle (its ends stay as drawn).
  static const Rect _slice = Rect.fromLTWH(70, 30, 304, 47);

  /// How many picture pixels make one world pixel.
  static const double _scale = 107 / _height;
  static const double _height = 17;

  /// Space inside each end of the frame, and the light (with its gap)
  /// before the name. The light and name are centred as one group.
  static const double _pad = 10;
  static const double _dot = 7;

  double get _groupWidth => _dot + _painter.width;

  late TextPainter _painter;
  ui.Image? _image;

  set text(String value) {
    _painter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF5E6C8),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    size = Vector2((_dot + _painter.width + _pad * 2).clamp(48, 220), _height);
  }

  @override
  Future<void> onLoad() async {
    _image = await game.images.load(asset);
  }

  @override
  void render(Canvas canvas) {
    final image = _image;
    if (image != null) {
      canvas
        ..save()
        ..scale(1 / _scale);
      canvas.drawImageNine(
        image,
        _slice,
        Rect.fromLTWH(0, 0, size.x * _scale, size.y * _scale),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(5)),
        Paint()..color = const Color(0xE62A1A10),
      );
    }
    // The green light.
    final left = (size.x - _groupWidth) / 2;
    final dot = Offset(left + 2, size.y / 2);
    canvas
      ..drawCircle(dot, 2.6, Paint()..color = const Color(0xFF1F6B22))
      ..drawCircle(dot, 2, Paint()..color = const Color(0xFF63E05C))
      ..drawCircle(
        dot.translate(-0.6, -0.6),
        0.7,
        Paint()..color = const Color(0xFFD8FFD0),
      );
    _painter.paint(canvas, Offset(left + _dot, (size.y - _painter.height) / 2));
  }
}

/// A small parchment bubble with three dots bobbing in turn, shown while a
/// player is typing. Removes itself after [_lifetime] seconds in case the
/// "stopped typing" message never arrives.
class TypingBubble extends PositionComponent {
  TypingBubble() : super(size: Vector2(34, 18));

  static const double _lifetime = 8;
  double _age = 0;

  static final Paint _fill = Paint()..color = const Color(0xF2F5EFE0);
  static final Paint _border = Paint()
    ..color = const Color(0xFF1B1712)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _dot = Paint()..color = const Color(0xFF1B1712);

  @override
  void update(double dt) {
    _age += dt;
    if (_age > _lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(9),
    );
    canvas
      ..drawRRect(box, _fill)
      ..drawRRect(box, _border);
    for (var i = 0; i < 3; i++) {
      // Each dot hops in turn, a third of a beat after the one before.
      final phase = (_age * 2.4 - i / 3) % 1;
      final hop = phase < 0.5 ? math.sin(phase * 2 * math.pi) * 3 : 0.0;
      canvas.drawCircle(
        Offset(size.x / 2 + (i - 1) * 8, size.y / 2 - hop),
        2.3,
        _dot,
      );
    }
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
