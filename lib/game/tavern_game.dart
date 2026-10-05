import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_images.dart';
import '../constants/characters.dart';
import '../constants/drinks.dart';
import '../constants/emotes.dart';
import '../theme/app_theme.dart';
import 'bernie.dart';
import 'highlight.dart';
import 'night_lighting.dart';
import 'player.dart';
import 'remote_player.dart';
import 'tavern_map.dart';

/// Bernie's Tavern: the map, the local player, an on-screen joystick and
/// WASD / arrow-key movement. Chat and the rest of the UI are Flutter
/// widgets layered on top (see TavernRoomScreen).
class TavernGame extends FlameGame with HasKeyboardHandlerComponents {
  /// [characterIndex] is the player's chosen character (see gameCharacters).
  TavernGame({
    required String playerName,
    int characterIndex = defaultCharacterIndex,
  }) : _playerName = playerName,
       _character = characterAt(characterIndex) {
    // Use full asset paths (AppImages) instead of Flame's assets/images/.
    images.prefix = '';
  }

  GameCharacter _character;
  String _playerName;

  /// Switches our character, e.g. once the profile has loaded.
  /// Every picture the tavern can show: the map, Bernie, the fire, the
  /// joystick, all characters' sheets (so other players' characters appear
  /// fully drawn), drinks and emotes.
  static List<String> get allAssets => {
    AppImages.tavernRoom,
    AppImages.bernieIdle,
    AppImages.fireplaceFire,
    AppImages.joystickBase,
    AppImages.joystickKnob,
    for (final c in gameCharacters) ...[
      c.sheet,
      ?c.idleSheet,
      ?c.horizontalRunSheet,
      ?c.sitBackSheet,
    ],
    for (final drink in drinks) drink.asset,
    for (final emote in emotes) emote.asset,
  }.toList();

  /// Loads [allAssets] into the image cache, reporting progress (0 to 1).
  Future<void> preloadAssets(void Function(double progress) onProgress) async {
    final assets = allAssets;
    var done = 0;
    await Future.wait([
      for (final asset in assets)
        images.load(asset).then((_) => onProgress(++done / assets.length)),
    ]);
  }

  set playerCharacter(int index) {
    _character = characterAt(index);
    if (isLoaded) {
      player.useSheet(
        _character.sheet,
        _character.feetFraction,
        idleSheetAsset: _character.idleSheet,
        horizontalRunSheetAsset: _character.horizontalRunSheet,
        frames: _character.frames,
        sitBackSheetAsset: _character.sitBackSheet,
      );
      player.sitsOverSeat = _character.sitsOverSeat;
      // The new character may not have a seated pose.
      if (sitting) standUp();
    }
  }

  /// Updates the name tag, e.g. once the player's profile has loaded.
  set playerName(String value) {
    _playerName = value;
    if (isLoaded) player.name = value;
  }

  /// How many map pixels tall the view is. Smaller = more zoomed in.
  static const double _visibleMapHeight = 520;

  /// While walking, send our position at most this often (seconds).
  /// ~7 per second keeps Realtime usage low; others smooth between updates.
  static const double _sendInterval = 0.15;

  late final Player player;

  /// Bernie the bartender, behind the bar.
  late final Bernie bernie;

  /// Called when Bernie is selected (tapped) or let go.
  void Function(bool selected)? onBernieSelected;

  /// Called when we order a drink, to tell the other players.
  void Function(String drinkId)? onDrinkOrdered;

  /// Whether we're at the bar, close enough to order from Bernie.
  bool get atBar => _atBar;
  bool _atBar = false;

  /// Called when we step up to the bar (true) or away from it (false).
  void Function(bool atBar)? onAtBarChanged;

  /// Called on each footstep while we walk (alternating feet), for the
  /// footstep sound.
  void Function(bool leftFoot)? onFootstep;

  /// Map pixels per footstep: two steps per walk cycle (0.72 s) at
  /// Player.speed.
  static const double _stepLength = 60;
  double _stepProgress = 0;
  bool _leftFoot = true;

  /// Counts distance actually moved (walking into a wall makes no sound);
  /// the first step of a walk lands almost at once.
  void _countSteps(double moved) {
    if (moved < 0.01) {
      _stepProgress = _stepLength * 0.75;
      return;
    }
    _stepProgress += moved;
    if (_stepProgress >= _stepLength) {
      _stepProgress -= _stepLength;
      onFootstep?.call(_leftFoot);
      _leftFoot = !_leftFoot;
    }
  }

  void _checkBar() {
    final at = TavernMap.barOrderArea.contains(
      Offset(player.position.x, player.position.y),
    );
    if (at != _atBar) {
      _atBar = at;
      onAtBarChanged?.call(at);
    }
  }

  /// Orders [drinkId] from Bernie: he says his line, and we hold the drink.
  void orderDrink(String drinkId) {
    final drink = drinkById(drinkId);
    if (drink == null || !isLoaded) return;
    bernie.say(drink.bernieSays);
    player
      ..holdDrink(drink.id)
      ..applyDrinkEffect(drink);
    onDrinkOrdered?.call(drink.id);
  }

  /// Another player got a drink: show it in their hand, with its effect.
  void otherPlayerDrinks(String id, String drinkId) {
    final drink = drinkById(drinkId);
    final other = _others[id];
    if (drink == null || other == null) return;
    other
      ..holdDrink(drink.id)
      ..applyDrinkEffect(drink);
  }

  late final JoystickComponent _joystick;
  late final _keyboardInput = _KeyboardInput(onInteract: interact);
  _HitboxOverlay? _hitboxOverlay;

  /// Called when our position should be sent to the other players.
  void Function(double x, double y, Facing facing, bool moving, bool sitting)?
  onLocalMove;

  /// Called when another player is tapped (opens their player card).
  void Function(String playerId)? onPlayerTap;

  /// Called when the player steps up to or away from the notice board.
  void Function(bool nearby)? onNoticeBoardNearby;

  /// Called when the player presses E (interact) while at the notice board.
  void Function()? onInteract;

  bool _nearNoticeBoard = false;
  bool get nearNoticeBoard => _nearNoticeBoard;

  /// Called when a free seat comes into reach (true) or goes out of reach
  /// (false), to show or hide "Click to sit".
  void Function(bool nearby)? onSeatNearby;

  /// Called when we sit down (true) or stand up (false).
  void Function(bool sitting)? onSittingChanged;

  /// The seat in reach, if any, and the seat we're on, if any.
  Seat? _nearSeat;
  Seat? _seat;

  /// Where we stood before sitting; standing up puts us back there.
  Vector2? _standSpot;

  bool get nearSeat => _nearSeat != null;
  bool get sitting => _seat != null;

  final Map<String, RemotePlayer> _others = {};
  double _sinceLastSend = 0;
  final Vector2 _lastSentPosition = Vector2.zero();
  bool _lastSentMoving = false;

  bool get showingHitboxes => _hitboxOverlay != null;

  /// Makes the other players on screen match [players]: adds newcomers,
  /// removes whoever left and updates renamed ones.
  void syncOtherPlayers(
    List<({String id, String name, int character, double x, double y})> players,
  ) {
    final ids = {for (final p in players) p.id};
    for (final id in _others.keys.toList()) {
      if (!ids.contains(id)) _others.remove(id)!.removeFromParent();
    }
    for (final p in players) {
      final existing = _others[p.id];
      final look = characterAt(p.character);
      if (existing != null) {
        existing.name = p.name;
        existing.useSheet(
          look.sheet,
          look.feetFraction,
          idleSheetAsset: look.idleSheet,
          horizontalRunSheetAsset: look.horizontalRunSheet,
          frames: look.frames,
          sitBackSheetAsset: look.sitBackSheet,
        );
        existing.sitsOverSeat = look.sitsOverSeat;
        continue;
      }
      final other = RemotePlayer(
        playerId: p.id,
        onTap: (id) => onPlayerTap?.call(id),
        sheetAsset: look.sheet,
        feetFraction: look.feetFraction,
        idleSheetAsset: look.idleSheet,
        horizontalRunSheetAsset: look.horizontalRunSheet,
        frames: look.frames,
        sitBackSheetAsset: look.sitBackSheet,
        name: p.name,
        start: Vector2(p.x, p.y),
      )..sitsOverSeat = look.sitsOverSeat;
      _others[p.id] = other;
      world.add(other);
    }
  }

  void moveOtherPlayer(
    String id,
    double x,
    double y,
    int facing,
    bool moving, {
    bool sitting = false,
  }) {
    _others[id]?.moveTo(
      Vector2(x, y),
      Facing.values[facing.clamp(0, Facing.values.length - 1)],
      moving,
      isSitting: sitting,
    );
  }

  void otherPlayerSays(String id, String text) => _others[id]?.say(text);

  void otherPlayerEmotes(String id, String emoji) => _others[id]?.emote(emoji);

  /// Shows or hides the "..." bubble over another player who is typing.
  void otherPlayerTyping(String id, bool typing) =>
      _others[id]?.showTyping(typing);

  /// Shows one of our own emotes over our head.
  void emote(String emoji) {
    if (isLoaded) player.emote(emoji);
  }

  /// E key: stand up when sitting, sit on the seat in reach, or open the
  /// notice board when standing at it.
  void interact() {
    if (sitting) {
      standUp();
    } else if (_nearSeat != null) {
      sitDown();
    } else if (_nearNoticeBoard) {
      onInteract?.call();
    }
  }

  /// Called when a seat is double-tapped from too far away to sit on it.
  void Function()? onSeatTooFar;

  /// Double-tapping a seat: sits on it when we're close enough and it's
  /// free; double-tapping the seat we're on stands us up.
  void sitOn(Seat seat) {
    if (!player.isLoaded) return;
    if (sitting) {
      if (identical(seat, _seat)) standUp();
      return;
    }
    if (!player.canSitFacing(seat.facing) || _seatTaken(seat)) return;
    final distance = player.position.distanceTo(Vector2(seat.x, seat.y));
    if (distance > TavernMap.seatTapReach) {
      onSeatTooFar?.call();
      return;
    }
    _setNearSeat(seat);
    sitDown();
  }

  bool _seatTaken(Seat seat) => _others.values.any(
    (o) => o.sitting && o.position.distanceTo(Vector2(seat.x, seat.y)) < 12,
  );

  /// Sits on the free seat in reach (see [nearSeat]).
  void sitDown() {
    final seat = _nearSeat;
    if (seat == null || sitting || !player.isLoaded) return;
    _standSpot = player.position.clone();
    player
      ..position.setValues(seat.x, seat.y)
      ..facing = seat.facing
      ..moving = false
      ..sitting = true;
    _seat = seat;
    _setNearSeat(null);
    _sendPosition();
    onSittingChanged?.call(true);
  }

  /// Gets up and steps back to where we stood before sitting.
  void standUp() {
    if (!sitting) return;
    final spot = _standSpot;
    if (spot != null) player.position.setFrom(spot);
    player.sitting = false;
    _seat = null;
    _standSpot = null;
    _sendPosition();
    onSittingChanged?.call(false);
  }

  void _setNearSeat(Seat? seat) {
    final was = _nearSeat != null;
    _nearSeat = seat;
    if (was != (seat != null)) onSeatNearby?.call(seat != null);
  }

  /// The closest seat in reach that we have a seated pose for and nobody
  /// else is sitting on.
  void _checkSeats() {
    if (sitting) return;
    Seat? best;
    var bestDistance = TavernMap.seatReach;
    for (final seat in TavernMap.seats) {
      if (!player.canSitFacing(seat.facing)) continue;
      final distance = player.position.distanceTo(Vector2(seat.x, seat.y));
      if (distance > bestDistance) continue;
      if (_seatTaken(seat)) continue;
      best = seat;
      bestDistance = distance;
    }
    if (best != _nearSeat) _setNearSeat(best);
  }

  int get otherPlayerCount => _others.length;

  /// Sends our current position right away, e.g. when someone new joins and
  /// needs to know where we're standing.
  void broadcastPosition() {
    if (!isLoaded || !player.isLoaded) return;
    _sendPosition();
  }

  void _sendPosition() {
    _sinceLastSend = 0;
    _lastSentPosition.setFrom(player.position);
    _lastSentMoving = player.moving;
    onLocalMove?.call(
      player.position.x,
      player.position.y,
      player.facing,
      player.moving,
      player.sitting,
    );
  }

  void _maybeSendPosition(double dt) {
    _sinceLastSend += dt;
    final moved = player.position.distanceTo(_lastSentPosition) > 0.5;
    if (player.moving && moved && _sinceLastSend >= _sendInterval) {
      _sendPosition();
    } else if (!player.moving && _lastSentMoving) {
      // Stopped: send once more so others see us stand still in place.
      _sendPosition();
    }
  }

  @override
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    final mapImage = await images.load(AppImages.tavernRoom);
    final map = _Floor(
      sprite: Sprite(mapImage),
      size: Vector2(TavernMap.width, TavernMap.height),
      // Characters use their y position as priority; the floor stays below.
      priority: -1,
      // Tapping anywhere else on the map lets go of Bernie.
      onTap: () => bernie.selected = false,
    )..paint.filterQuality = FilterQuality.none;

    bernie = Bernie(
      position: Vector2(TavernMap.bartenderSpot.dx, TavernMap.bartenderSpot.dy),
    )..onSelectedChanged = (selected) => onBernieSelected?.call(selected);
    // The counter top drawn again over Bernie, so the bar hides him from
    // the waist down. Layered by its bottom edge, like the stools: in front
    // of him, behind anyone sitting at or walking past the bar.
    const counter = TavernMap.barCounterFront;
    final counterFront = SpriteComponent(
      sprite: Sprite(
        mapImage,
        srcPosition: Vector2(counter.left, counter.top),
        srcSize: Vector2(counter.width, counter.height),
      ),
      position: Vector2(counter.left, counter.top),
      size: Vector2(counter.width, counter.height),
      priority: counter.bottom.round(),
    )..paint.filterQuality = FilterQuality.none;

    // Each stool's front as its own sprite over the map, layered by depth
    // like the characters (by its bottom edge): in front of whoever sits on
    // it, behind anyone walking past in front of it.
    final stoolFronts = [
      for (final seat in TavernMap.seats)
        SpriteComponent(
          sprite: Sprite(
            mapImage,
            srcPosition: Vector2(seat.front.left, seat.front.top),
            srcSize: Vector2(seat.front.width, seat.front.height),
          ),
          position: Vector2(seat.front.left, seat.front.top),
          size: Vector2(seat.front.width, seat.front.height),
          priority: seat.front.bottom.round(),
        )..paint.filterQuality = FilterQuality.none,
    ];

    player =
        Player(
            sheetAsset: _character.sheet,
            feetFraction: _character.feetFraction,
            name: _playerName,
            idleSheetAsset: _character.idleSheet,
            horizontalRunSheetAsset: _character.horizontalRunSheet,
            frames: _character.frames,
            sitBackSheetAsset: _character.sitBackSheet,
          )
          ..position = Vector2(TavernMap.spawnPoint.dx, TavernMap.spawnPoint.dy)
          ..sitsOverSeat = _character.sitsOverSeat;

    // Invisible double-tap areas over each stool (seat and legs), for
    // sitting on phones without the button.
    final seatTargets = [
      for (final seat in TavernMap.seats) _SeatTarget(seat, onDoubleTap: sitOn),
    ];

    // The notice board drawn again over the map, so it can glow.
    const board = TavernMap.noticeBoardRect;
    _noticeBoard = HighlightableCutout(
      sprite: Sprite(
        mapImage,
        srcPosition: Vector2(board.left, board.top),
        srcSize: Vector2(board.width, board.height),
      ),
      position: Vector2(board.left, board.top),
      size: Vector2(board.width, board.height),
      // Over the floor, under everyone (it hangs on the back wall).
      priority: 0,
    )..paint.filterQuality = FilterQuality.none;

    // The fire in the fireplace, burning (16 frames over the painted one).
    final fireImage = await images.load(AppImages.fireplaceFire);
    const hearth = TavernMap.fireplaceFire;
    final fire = SpriteAnimationComponent(
      position: Vector2(hearth.left, hearth.top),
      size: Vector2(hearth.width, hearth.height),
      priority: 0,
    );
    fire.animation = SpriteAnimation.spriteList([
      for (var row = 0; row < 4; row++)
        for (var col = 0; col < 4; col++)
          Sprite(
            fireImage,
            srcPosition: Vector2(
              col * fireImage.width / 4,
              row * fireImage.height / 4,
            ),
            srcSize: Vector2(fireImage.width / 4, fireImage.height / 4),
          ),
    ], stepTime: 0.1);

    // Night mode: the map (and the bits of it drawn over characters) dims
    // like the app's other scenes, and its lanterns glow warm.
    final sceneFilter = AppColors.sceneFilter;
    if (sceneFilter != null) {
      // The fire stays bright: it's a light source.
      fire.paint.colorFilter = AppColors.artFilter;
      for (final part in [map, counterFront, _noticeBoard, ...stoolFronts]) {
        part.paint.colorFilter = sceneFilter;
      }
    }

    world.addAll([
      map,
      fire,
      _noticeBoard,
      bernie,
      counterFront,
      ...stoolFronts,
      ...seatTargets,
      player,
      _keyboardInput,
      if (sceneFilter != null) NightLighting(),
    ]);

    // The wood-and-brass joystick: the ring stays put, the wooden knob
    // moves inside its dark well.
    final joystickBase = await images.load(AppImages.joystickBase);
    final joystickKnob = await images.load(AppImages.joystickKnob);
    const baseSize = 120.0;
    _joystick = JoystickComponent(
      background: SpriteComponent(
        sprite: Sprite(joystickBase),
        size: Vector2.all(baseSize),
      ),
      knob: SpriteComponent(
        sprite: Sprite(joystickKnob),
        size: Vector2.all(baseSize * 107 / 288),
      ),
      // How far the knob travels: to the edge of the dark well.
      knobRadius: 22,
      margin: const EdgeInsets.only(left: 24, bottom: 20),
    );
    camera.viewport.add(_joystick);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // The player loads its sprite sheet after the game itself has loaded;
    // until then it has no animations to switch between.
    if (!isLoaded || !player.isLoaded) return;

    // Joystick wins over the keyboard when both are in use.
    final input = _joystick.relativeDelta.isZero()
        ? _keyboardInput.direction
        : _joystick.relativeDelta.clone();
    // Moving while seated gets up first.
    if (sitting && input.length2 > 0.01) standUp();
    // Cap dt so a dropped frame can't carry the player through a wall.
    if (!sitting) {
      final before = player.position.clone();
      player.walk(input, math.min(dt, 1 / 30));
      _countSteps(player.position.distanceTo(before));
    }
    _maybeSendPosition(dt);
    _checkNoticeBoard();
    _checkSeats();
    _checkBar();
    _updateHighlights();
    if (!sitting) _pullTowardCharmers(dt);
    _followPlayer();
    _shakeIfDizzy(dt);
  }

  double _shakeClock = 0;

  /// Tavern Ale: the view sways and shakes while we're dizzy, easing off
  /// over the last couple of seconds.
  void _shakeIfDizzy(double dt) {
    final left = player.effectLeft(DrinkEffect.tipsy);
    if (left <= 0) return;
    _shakeClock += dt;
    final strength = 7 * (left / 2).clamp(0.0, 1.0);
    final t = _shakeClock;
    camera.viewfinder.position += Vector2(
      (math.sin(t * 2.3) * 0.7 + math.sin(t * 17) * 0.3) * strength,
      (math.cos(t * 1.9) * 0.6 + math.sin(t * 13) * 0.4) * strength,
    );
    camera.viewfinder.angle = math.sin(t * 1.6) * 0.03 * (strength / 7);
  }

  /// Berry Wine: anyone who drank it slowly draws nearby players toward
  /// them. Each player's own game moves them, so this pulls us toward
  /// other charmers (and their games pull them toward us).
  static const double _charmReach = 320;
  static const double _charmSpeed = 45;

  void _pullTowardCharmers(double dt) {
    if (camera.viewfinder.angle != 0 && !player.hasEffect(DrinkEffect.tipsy)) {
      camera.viewfinder.angle = 0;
    }
    for (final other in _others.values) {
      if (!other.hasEffect(DrinkEffect.hearts)) continue;
      final toward = other.position - player.position;
      final distance = toward.length;
      // Close enough already, or too far to feel it.
      if (distance < 36 || distance > _charmReach) continue;
      player.nudge(toward.normalized() * _charmSpeed * math.min(dt, 1 / 30));
    }
  }

  /// Show a "!" (and a bright glow) over Bernie / the notice board until the
  /// player has used them once. Set by the screen, which remembers that.
  bool bernieHint = false;
  bool noticeBoardHint = false;

  late final HighlightableCutout _noticeBoard;

  /// Both always glow, brighter while the player is close enough to use them.
  void _updateHighlights() {
    bernie
      ..showHint = bernieHint
      ..highlighted = _atBar;
    _noticeBoard
      ..showHint = noticeBoardHint
      ..highlighted = _nearNoticeBoard;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Zoom so about [_visibleMapHeight] map pixels fit vertically, but never
    // so far out that the view is wider than the map.
    camera.viewfinder.zoom = math.max(
      size.y / _visibleMapHeight,
      size.x / TavernMap.width,
    );
  }

  void _checkNoticeBoard() {
    final spot = TavernMap.noticeBoardSpot;
    final near =
        player.position.distanceTo(Vector2(spot.dx, spot.dy)) <=
        TavernMap.noticeBoardReach;
    if (near != _nearNoticeBoard) {
      _nearNoticeBoard = near;
      onNoticeBoardNearby?.call(near);
    }
  }

  /// Centers the camera on the player without showing past the map's edges.
  void _followPlayer() {
    final halfView = size / camera.viewfinder.zoom / 2;
    camera.viewfinder.position = Vector2(
      _clampCenter(player.position.x, halfView.x, TavernMap.width),
      _clampCenter(player.position.y, halfView.y, TavernMap.height),
    );
  }

  static double _clampCenter(double value, double half, double extent) =>
      half * 2 >= extent ? extent / 2 : value.clamp(half, extent - half);

  /// Shows or hides the collision boxes (red) and the player's feet box
  /// (green). While shown, tapping the map prints its coordinates.
  void toggleHitboxes() {
    if (_hitboxOverlay != null) {
      _hitboxOverlay!.removeFromParent();
      _hitboxOverlay = null;
    } else {
      _hitboxOverlay = _HitboxOverlay(player);
      world.add(_hitboxOverlay!);
    }
  }
}

/// An invisible box over a stool (its seat and legs) that reports double
/// taps. Drawn nothing; high priority only so it's found first.
class _SeatTarget extends PositionComponent with DoubleTapCallbacks {
  _SeatTarget(this.seat, {required this.onDoubleTap})
    : super(
        position: Vector2(seat.frontLeft, seat.y - 40),
        size: Vector2(
          seat.frontRight - seat.frontLeft,
          seat.frontBottom - (seat.y - 40),
        ),
        priority: 50000,
      );

  final Seat seat;
  final void Function(Seat seat) onDoubleTap;

  @override
  void onDoubleTapDown(DoubleTapDownEvent event) => onDoubleTap(seat);
}

/// The tavern picture, which reports taps that land on empty floor (not on
/// a player or Bernie).
class _Floor extends SpriteComponent with TapCallbacks {
  _Floor({
    required super.sprite,
    required super.size,
    required super.priority,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  void onTapUp(TapUpEvent event) => onTap();
}

/// Turns held WASD / arrow keys into a direction vector.
class _KeyboardInput extends Component with KeyboardHandler {
  _KeyboardInput({required this.onInteract});

  final void Function() onInteract;
  final Vector2 direction = Vector2.zero();

  static final _left = {LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft};
  static final _right = {
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowRight,
  };
  static final _up = {LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp};
  static final _down = {LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown};

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      onInteract();
    }
    bool held(Set<LogicalKeyboardKey> keys) => keys.any(keysPressed.contains);
    direction.setValues(
      (held(_right) ? 1 : 0) - (held(_left) ? 1 : 0).toDouble(),
      (held(_down) ? 1 : 0) - (held(_up) ? 1 : 0).toDouble(),
    );
    return true;
  }
}

/// Debug view of [TavernMap.collisionBoxes]. Tap anywhere to see the map
/// coordinates under your finger, for tuning the boxes.
class _HitboxOverlay extends PositionComponent with TapCallbacks {
  _HitboxOverlay(this.player)
    : super(
        size: Vector2(TavernMap.width, TavernMap.height),
        priority: 100000, // above every character
      );

  final Player player;
  Offset? _lastTap;

  final _boxFill = Paint()..color = const Color(0x55FF1744);
  final _boxEdge = Paint()
    ..color = const Color(0xFFFF1744)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final _feetPaint = Paint()..color = const Color(0xAA00E676);
  final _label = TextPaint(
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.yellowAccent,
      shadows: [Shadow(blurRadius: 3, color: Colors.black)],
    ),
  );

  @override
  void onTapDown(TapDownEvent event) {
    final point = event.localPosition;
    _lastTap = Offset(point.x, point.y);
    debugPrint('Tavern map tap: x=${point.x.round()}, y=${point.y.round()}');
  }

  @override
  void render(Canvas canvas) {
    for (final box in TavernMap.collisionBoxes) {
      canvas
        ..drawRect(box, _boxFill)
        ..drawRect(box, _boxEdge);
    }
    canvas.drawRect(player.feet, _feetPaint);

    final tap = _lastTap;
    if (tap != null) {
      canvas.drawCircle(tap, 4, Paint()..color = Colors.yellowAccent);
      _label.render(
        canvas,
        'x ${tap.dx.round()}, y ${tap.dy.round()}',
        Vector2(tap.dx + 8, tap.dy - 22),
      );
    }
  }
}
