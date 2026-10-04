import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_images.dart';
import '../constants/characters.dart';
import '../constants/drinks.dart';
import 'bernie.dart';
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
    player.holdDrink(drink.id);
    onDrinkOrdered?.call(drink.id);
  }

  /// Another player got a drink: show it in their hand.
  void otherPlayerDrinks(String id, String drinkId) =>
      _others[id]?.holdDrink(drinkId);

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
      );
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
      final taken = _others.values.any(
        (o) => o.sitting && o.position.distanceTo(Vector2(seat.x, seat.y)) < 12,
      );
      if (taken) continue;
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

    player = Player(
      sheetAsset: _character.sheet,
      feetFraction: _character.feetFraction,
      name: _playerName,
      idleSheetAsset: _character.idleSheet,
      horizontalRunSheetAsset: _character.horizontalRunSheet,
      frames: _character.frames,
      sitBackSheetAsset: _character.sitBackSheet,
    )..position = Vector2(TavernMap.spawnPoint.dx, TavernMap.spawnPoint.dy);

    world.addAll([
      map,
      bernie,
      counterFront,
      ...stoolFronts,
      player,
      _keyboardInput,
    ]);

    _joystick = JoystickComponent(
      background: _JoystickBase(radius: 48),
      knob: CircleComponent(
        radius: 20,
        paint: Paint()..color = const Color(0xE6F5EFE0),
      ),
      margin: const EdgeInsets.only(left: 36, bottom: 32),
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
    if (!sitting) player.walk(input, math.min(dt, 1 / 30));
    _maybeSendPosition(dt);
    _checkNoticeBoard();
    _checkSeats();
    _checkBar();
    _followPlayer();
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

/// Dark ring with a crosshair, matching the mockup's joystick.
class _JoystickBase extends CircleComponent {
  _JoystickBase({required super.radius})
    : super(paint: Paint()..color = const Color(0x661B1712));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(radius, radius);
    final ring = Paint()
      ..color = const Color(0xCCF5EFE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, ring);
    final tick = Paint()
      ..color = const Color(0x99F5EFE0)
      ..strokeWidth = 2;
    const inner = 8.0;
    canvas
      ..drawLine(
        center.translate(0, -radius + 4),
        center.translate(0, -radius + 4 + inner),
        tick,
      )
      ..drawLine(
        center.translate(0, radius - 4),
        center.translate(0, radius - 4 - inner),
        tick,
      )
      ..drawLine(
        center.translate(-radius + 4, 0),
        center.translate(-radius + 4 + inner, 0),
        tick,
      )
      ..drawLine(
        center.translate(radius - 4, 0),
        center.translate(radius - 4 - inner, 0),
        tick,
      );
  }
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
