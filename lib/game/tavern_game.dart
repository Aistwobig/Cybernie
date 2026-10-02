import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_images.dart';
import '../constants/characters.dart';
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
      );
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
  late final JoystickComponent _joystick;
  late final _keyboardInput = _KeyboardInput(onInteract: interact);
  _HitboxOverlay? _hitboxOverlay;

  /// Called when our position should be sent to the other players.
  void Function(double x, double y, Facing facing, bool moving)? onLocalMove;

  /// Called when another player is tapped (opens their player card).
  void Function(String playerId)? onPlayerTap;

  /// Called when the player steps up to or away from the notice board.
  void Function(bool nearby)? onNoticeBoardNearby;

  /// Called when the player presses E (interact) while at the notice board.
  void Function()? onInteract;

  bool _nearNoticeBoard = false;
  bool get nearNoticeBoard => _nearNoticeBoard;

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
        name: p.name,
        start: Vector2(p.x, p.y),
      );
      _others[p.id] = other;
      world.add(other);
    }
  }

  void moveOtherPlayer(String id, double x, double y, int facing, bool moving) {
    _others[id]?.moveTo(
      Vector2(x, y),
      Facing.values[facing.clamp(0, Facing.values.length - 1)],
      moving,
    );
  }

  void otherPlayerSays(String id, String text) => _others[id]?.say(text);

  void otherPlayerEmotes(String id, String emoji) => _others[id]?.emote(emoji);

  /// Shows one of our own emotes over our head.
  void emote(String emoji) {
    if (isLoaded) player.emote(emoji);
  }

  /// E key: open the notice board when standing at it.
  void interact() {
    if (_nearNoticeBoard) onInteract?.call();
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
    final map = SpriteComponent(
      sprite: await loadSprite(AppImages.tavernRoom),
      size: Vector2(TavernMap.width, TavernMap.height),
      // Characters use their y position as priority; the floor stays below.
      priority: -1,
    )..paint.filterQuality = FilterQuality.none;

    player = Player(
      sheetAsset: _character.sheet,
      feetFraction: _character.feetFraction,
      name: _playerName,
      idleSheetAsset: _character.idleSheet,
      horizontalRunSheetAsset: _character.horizontalRunSheet,
    )..position = Vector2(TavernMap.spawnPoint.dx, TavernMap.spawnPoint.dy);

    world.addAll([map, player, _keyboardInput]);

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
    // Cap dt so a dropped frame can't carry the player through a wall.
    player.walk(input, math.min(dt, 1 / 30));
    _maybeSendPosition(dt);
    _checkNoticeBoard();
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
