import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../constants/characters.dart';
import '../constants/drinks.dart';
import '../constants/emotes.dart';
import '../game/tavern_game.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/coin_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/room_service.dart';
import '../services/sfx_service.dart';
import '../game/tavern_map.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_chip.dart';
import '../widgets/leaderboard_panel.dart';
import 'blackjack_overlay.dart';
import 'tavern_panels.dart';

/// Bernie's Tavern. Always landscape and full screen: phones are asked to
/// rotate, and where that isn't possible (web, the device preview frame) the
/// whole room is drawn rotated so it still fills the screen sideways.
class TavernRoomScreen extends StatefulWidget {
  const TavernRoomScreen({super.key});

  @override
  State<TavernRoomScreen> createState() => _TavernRoomScreenState();
}

class _TavernRoomScreenState extends State<TavernRoomScreen> {
  static const String _roomId = 'tavern';
  static const int _visibleMessages = 5;

  late final TavernGame _game = TavernGame(
    playerName: AppStrings.profilePlayerName,
  );
  int _myCharacter = defaultCharacterIndex;
  final FocusNode _gameFocus = FocusNode();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  ChatService? _chat;
  RoomService? _room;
  bool _isSending = false;
  int _playersInRoom = 1;

  String _myName = AppStrings.profilePlayerName;
  String? _myAvatarUrl;
  List<RoomPlayer> _others = const [];
  _Panel _panel = _Panel.none;
  String? _cardPlayerId;
  String _reportName = '';
  bool _cameFromList = false;
  bool _nearNoticeBoard = false;
  bool _nearSeat = false;
  bool _sitting = false;
  bool _emotesOpen = false;

  /// The chat log starts folded so the room is clear on entering; new
  /// messages show as "N NEW MESSAGES" on its header until it's opened.
  bool _chatCollapsed = true;
  int _unreadMessages = 0;

  /// The friend in the private chat panel, opened from their player card.
  Profile? _chatFriend;

  /// At the bar (can order from Bernie), and a short pause after ordering.
  bool _atBar = false;
  bool _justOrdered = false;
  Timer? _orderPause;

  /// Our own typing: whether the room was told we're typing, when we last
  /// said so, and a timer that says we stopped after a pause.
  bool _typingSent = false;
  DateTime _lastTypingPing = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _typingIdle;
  String _lastDraft = '';
  static const Duration _typingRepeat = Duration(seconds: 2);
  static const Duration _typingPause = Duration(seconds: 4);

  /// Others typing, by player id. Each one is dropped if no new "typing"
  /// arrives in time (their "stopped" message may never come).
  final Map<String, Timer> _typers = {};
  static const Duration _typingTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _game.onPlayerTap = (id) => _openPlayerCard(id, fromList: false);
    _game.onNoticeBoardNearby = (near) {
      if (mounted) setState(() => _nearNoticeBoard = near);
    };
    _game.onInteract = _openNoticeBoard;
    _game.onSeatNearby = (near) {
      if (mounted) setState(() => _nearSeat = near);
    };
    _game.onSittingChanged = (sitting) {
      SfxService.play(sitting ? Sfx.sit : Sfx.stand);
      if (mounted) setState(() => _sitting = sitting);
    };
    // Tapping Bernie opens his menu; letting go of him closes it.
    _game.onBernieSelected = (selected) {
      if (!mounted) return;
      if (selected) {
        SfxService.play(Sfx.sparkle);
        _markSeen(_seenBernieKey);
        setState(() {
          _panel = _Panel.bar;
          _emotesOpen = false;
        });
      } else if (_panel == _Panel.bar) {
        setState(() => _panel = _Panel.none);
      }
    };
    _game.onAtBarChanged = (atBar) {
      if (mounted) setState(() => _atBar = atBar);
    };
    _game.onDrinkOrdered = (drinkId) => _room?.sendDrink(drinkId);
    _game.onSeatTooFar = () => _showSnack(AppStrings.walkCloserToSit);
    _game.onFootstep = (left) =>
        SfxService.play(left ? Sfx.step1 : Sfx.step2, gain: 0.45);
    _messageController.addListener(_onDraftChanged);
    _prepare();
    _loadHints();
    _loadCoins();
    _fireSound = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _updateFireSound(),
    );
    _enterRoom();
    _connectChat();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _game
      ..onLocalMove = null
      ..onPlayerTap = null
      ..onNoticeBoardNearby = null
      ..onSeatNearby = null
      ..onSittingChanged = null
      ..onBernieSelected = null
      ..onAtBarChanged = null
      ..onDrinkOrdered = null
      ..onSeatTooFar = null
      ..onFootstep = null
      ..onInteract = null;
    _orderPause?.cancel();
    _fireSound?.cancel();
    _fireLoop.dispose();
    _effectTicker?.cancel();
    _typingIdle?.cancel();
    for (final timer in _typers.values) {
      timer.cancel();
    }
    _room?.leave();
    _chat?.dispose();
    _gameFocus.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// The loading screen stays up until [_ready]; [_loadStep] and
  /// [_loadProgress] describe how far along it is.
  bool _ready = false;
  bool _loadingGone = false;
  int _loadStep = 0;
  double _loadProgress = 0;
  final Completer<void> _profileReady = Completer<void>();

  /// Waits for everything the room shows before revealing it: all pictures,
  /// the map and Bernie, then our own character (in our chosen look, with
  /// our name). Each step gives up after a while rather than hang.
  Future<void> _prepare() async {
    final started = DateTime.now();
    void progress(int step, double value) {
      if (mounted) {
        setState(() {
          _loadStep = step;
          _loadProgress = value;
        });
      }
    }

    Future<void> step(Future<void> work) => work
        .timeout(const Duration(seconds: 15))
        .catchError((Object error) => debugPrint('Loading tavern: $error'));

    // 1. Every picture (60% of the bar).
    await step(_game.preloadAssets((p) => progress(0, p * 0.6)));
    // 2. The room itself: map, fire, Bernie.
    progress(1, 0.65);
    await step(_game.loaded);
    progress(1, 0.75);
    // 3. Us: our profile, then our character's sheets and name.
    progress(2, 0.8);
    await step(_profileReady.future);
    await step(_game.player.sheetsReady);
    progress(2, 1);
    // A moment on the full bar so it doesn't flash by.
    final shown = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 900);
    if (shown < minimum) await Future<void>.delayed(minimum - shown);
    if (!mounted) return;
    setState(() => _ready = true);
    _gameFocus.requestFocus();
  }

  /// Loads our name, then joins the room's live channel so we see the other
  /// players and they see us.
  Future<void> _enterRoom() async {
    if (!AuthService.isSignedIn) {
      _profileReady.complete();
      return;
    }

    var name = AppStrings.profilePlayerName;
    try {
      final profile = await ProfileService.fetchMine();
      if (profile.displayName.isNotEmpty) name = profile.displayName;
      _myAvatarUrl = profile.avatarUrl;
      _myCharacter = profile.characterIndex;
      _game.playerCharacter = _myCharacter;
    } catch (_) {
      // Keep the default name.
    }
    if (!_profileReady.isCompleted) _profileReady.complete();
    if (!mounted) return;
    _game.playerName = name;
    setState(() => _myName = name);

    final room = RoomService(_roomId);
    _room = room;
    _game.onLocalMove = (x, y, facing, moving, sitting) => room.sendMove(
      PlayerMove(
        playerId: room.myId,
        x: x,
        y: y,
        facing: facing.index,
        moving: moving,
        sitting: sitting,
      ),
    );

    await room.join(
      name: name,
      avatarUrl: _myAvatarUrl,
      character: _myCharacter,
      x: TavernMap.spawnPoint.dx,
      y: TavernMap.spawnPoint.dy,
      onPlayers: (others) {
        _game.syncOtherPlayers([
          for (final p in others)
            (id: p.id, name: p.name, character: p.character, x: p.x, y: p.y),
        ]);
        if (!mounted) return;
        setState(() {
          _others = others;
          _playersInRoom = others.length + 1;
          // Whoever left isn't typing any more.
          final here = {for (final p in others) p.id};
          _typers.removeWhere((id, timer) {
            if (here.contains(id)) return false;
            timer.cancel();
            return true;
          });
        });
      },
      onMove: (move) => _game.moveOtherPlayer(
        move.playerId,
        move.x,
        move.y,
        move.facing,
        move.moving,
        sitting: move.sitting,
      ),
      onSomeoneJoined: _game.broadcastPosition,
      onEmote: (id, emoji) {
        _game.otherPlayerEmotes(id, emoji);
        SfxService.play(Sfx.pop, gain: 0.6);
      },
      onDrink: _game.otherPlayerDrinks,
      onTyping: _setTyping,
      onError: () => _showSnack(AppStrings.roomConnectionError),
    );
    // A little welcome jingle once we're in.
    SfxService.play(Sfx.join);
  }

  Future<void> _connectChat() async {
    if (!AuthService.isSignedIn) return;
    final chat = ChatService(_roomId);
    _chat = chat;
    chat.subscribe((message) {
      if (!mounted || _messages.any((m) => m.id == message.id)) return;
      setState(() {
        _messages.add(message);
        if (_chatCollapsed && message.senderId != chat.myId) _unreadMessages++;
      });
      // Our own bubble is shown as soon as we send; show everyone else's.
      if (message.senderId != chat.myId) {
        _setTyping(message.senderId, false);
        SfxService.play(Sfx.message, gain: 0.7);
        _game.otherPlayerSays(message.senderId, message.body);
      }
    });
    try {
      final recent = await chat.fetchRecent(limit: _visibleMessages);
      if (!mounted) return;
      setState(() {
        final seen = {for (final m in _messages) m.id};
        _messages.insertAll(0, recent.where((m) => !seen.contains(m.id)));
      });
    } catch (_) {
      // Chat history is optional; live messages still arrive.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final chat = _chat;
    if (text.isEmpty || _isSending) return;
    if (chat == null) {
      _showSnack(AppStrings.chatSignInRequired);
      return;
    }

    setState(() => _isSending = true);
    try {
      await chat.send(text);
      _messageController.clear();
      _game.player.say(text);
      // Hand the keyboard back to the game so WASD moves again.
      _gameFocus.requestFocus();
    } catch (_) {
      _showSnack(AppStrings.chatSendError);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Tells the room when we start typing (again every [_typingRepeat] while
  /// we keep at it) and when we stop: the box is emptied or sent, or we
  /// pause for [_typingPause].
  void _onDraftChanged() {
    final draft = _messageController.text.trim();
    // Moving the cursor also notifies; only edits count.
    if (draft == _lastDraft) return;
    _lastDraft = draft;
    if (draft.isEmpty) {
      _stopTyping();
      return;
    }
    final now = DateTime.now();
    if (!_typingSent || now.difference(_lastTypingPing) >= _typingRepeat) {
      _typingSent = true;
      _lastTypingPing = now;
      _room?.sendTyping(true);
    }
    _typingIdle?.cancel();
    _typingIdle = Timer(_typingPause, _stopTyping);
  }

  void _stopTyping() {
    _typingIdle?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    _room?.sendTyping(false);
  }

  /// Shows [playerId] as typing (over their head and under the chat) for
  /// up to [_typingTimeout], or stops showing them.
  void _setTyping(String playerId, bool typing) {
    _game.otherPlayerTyping(playerId, typing);
    if (!mounted) return;
    setState(() {
      _typers.remove(playerId)?.cancel();
      if (typing) {
        _typers[playerId] = Timer(
          _typingTimeout,
          () => _setTyping(playerId, false),
        );
      }
    });
  }

  static const String _seenBernieKey = 'tavern_seen_bernie';
  static const String _seenBoardKey = 'tavern_seen_notice_board';

  /// Bernie and the notice board carry a "!" until this player has used
  /// them once on this device.
  Future<void> _loadHints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _game
        ..bernieHint = !(prefs.getBool(_seenBernieKey) ?? false)
        ..noticeBoardHint = !(prefs.getBool(_seenBoardKey) ?? false);
    } catch (_) {
      // No storage (e.g. private browsing): show both hints this visit.
      _game
        ..bernieHint = true
        ..noticeBoardHint = true;
    }
  }

  Future<void> _markSeen(String key) async {
    if (key == _seenBernieKey) {
      if (!_game.bernieHint) return;
      _game.bernieHint = false;
    } else {
      if (!_game.noticeBoardHint) return;
      _game.noticeBoardHint = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _leaveRoom() => Navigator.of(context).pop();

  void _openPlayers() => setState(() {
    _panel = _Panel.players;
    _emotesOpen = false;
  });

  void _openPlayerCard(String playerId, {required bool fromList}) {
    if (!mounted) return;
    setState(() {
      _cardPlayerId = playerId;
      _cameFromList = fromList;
      _panel = _Panel.playerCard;
      _emotesOpen = false;
    });
  }

  void _openReport(String playerId, String name) => setState(() {
    _cardPlayerId = playerId;
    _reportName = name;
    _panel = _Panel.report;
  });

  void _openNoticeBoard() {
    if (!mounted) return;
    _markSeen(_seenBoardKey);
    setState(() {
      _panel = _Panel.noticeBoard;
      _emotesOpen = false;
    });
  }

  void _openLeaderboard() {
    SfxService.play(Sfx.click, gain: 0.6);
    setState(() {
      _panel = _Panel.leaderboard;
      _emotesOpen = false;
    });
  }

  void _openDirectChat(Profile friend) => setState(() {
    _chatFriend = friend;
    _panel = _Panel.directChat;
    _emotesOpen = false;
  });

  void _closePanel() {
    final wasBar = _panel == _Panel.bar;
    setState(() => _panel = _Panel.none);
    // Closing his menu lets go of Bernie (hides his name plate).
    if (wasBar) _game.bernie.selected = false;
    // Give the keyboard back to the game so WASD works again.
    _gameFocus.requestFocus();
  }

  /// Orders from Bernie, then closes his menu. Ordering pauses for a few
  /// seconds so drinks can't be spammed.
  Future<void> _orderDrink(String drinkId) async {
    final drink = drinkById(drinkId);
    if (_justOrdered || drink == null) return;
    _orderPause?.cancel();
    setState(() => _justOrdered = true);
    _orderPause = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _justOrdered = false);
    });
    // Pay, and it goes to the inventory (not drunk yet). Before the coins
    // have loaded (e.g. the coins migration isn't run) it's on the house.
    if (CoinService.coins.value == null) {
      await InventoryService.added(drink.id);
    } else if (!await CoinService.buyDrink(drink)) {
      _showSnack(AppStrings.cantAffordDrink(drink.price));
      return;
    }
    if (!mounted) return;
    _game.serveDrink(drinkId);
    SfxService.play(Sfx.coin);
    _showSnack(AppStrings.itemSentToInventory(drink.name));
  }

  /// Drinks one [drinkId] from the inventory: its effect starts now.
  Future<void> _useItem(String drinkId) async {
    if (!await InventoryService.use(drinkId)) return;
    if (!mounted) return;
    _game.drink(drinkId);
    SfxService.play(Sfx.pop);
    _closePanel();
    _startEffectTicker();
  }

  void _openTasks() {
    SfxService.play(Sfx.click, gain: 0.6);
    TaskService.load();
    setState(() {
      _panel = _Panel.tasks;
      _emotesOpen = false;
    });
  }

  void _openInventory() {
    SfxService.play(Sfx.click, gain: 0.6);
    setState(() {
      _panel = _Panel.inventory;
      _emotesOpen = false;
    });
  }

  Future<void> _claimTask(String taskId) async {
    if (await TaskService.claim(taskId)) {
      SfxService.play(Sfx.coin);
    } else {
      _showSnack(AppStrings.taskNotReady);
    }
  }

  /// Ticks once a second while a drink effect is running, for the chip
  /// that counts it down.
  Timer? _effectTicker;

  void _startEffectTicker() {
    _effectTicker?.cancel();
    setState(() {});
    _effectTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_activeEffects.isEmpty) timer.cancel();
    });
  }

  /// Drinks whose effect is still on us, with whole seconds left.
  List<(Drink, int)> get _activeEffects => [
    if (_game.isLoaded)
      for (final drink in drinks)
        if (_game.player.hasEffect(drink.effect))
          (drink, _game.player.effectLeft(drink.effect).ceil()),
  ];

  /// The fireplace crackling: louder the closer we stand to it.
  final AmbientLoop _fireLoop = AmbientLoop('sfx_fire_loop');
  Timer? _fireSound;

  /// Full volume within [_fireNear] map pixels of the fire, fading to
  /// silence at [_fireFar].
  static const double _fireNear = 70;
  static const double _fireFar = 650;

  void _updateFireSound() {
    if (!_game.isLoaded || !_game.player.isLoaded) return;
    final fire = TavernMap.fireplaceFire.center;
    final distance = _game.player.position.distanceTo(
      Vector2(fire.dx, fire.dy),
    );
    final t = ((distance - _fireNear) / (_fireFar - _fireNear)).clamp(0.0, 1.0);
    // Falls off like a real sound: loud close up, quickly quieter.
    var level = (1 - t) * (1 - t) * 0.85;
    // Muffled while sitting at Bernie's card table.
    if (_blackjackOpen) level *= 0.35;
    _fireLoop.setLevel(level);
  }

  /// Bernie's blackjack table, over the whole room while it's open.
  bool _blackjackOpen = false;

  void _openBlackjack() {
    SfxService.play(Sfx.sparkle);
    _closePanel();
    setState(() {
      _blackjackOpen = true;
      _emotesOpen = false;
    });
  }

  void _closeBlackjack() {
    setState(() => _blackjackOpen = false);
    // WASD walks again.
    _gameFocus.requestFocus();
  }

  /// Loads our coins (adding the once-a-day bonus) for the top-right corner,
  /// and our inventory and tasks.
  Future<void> _loadCoins() async {
    InventoryService.load();
    TaskService.load();
    try {
      final bonus = await CoinService.enterTavern();
      if (bonus > 0) {
        SfxService.play(Sfx.coin);
        _showSnack(AppStrings.dailyCoinsBonus(bonus));
      }
    } catch (error) {
      // Coins are optional (e.g. the coins migration hasn't been run yet).
      debugPrint('Coins: $error');
    }
  }

  void _sendEmote(String emoji) {
    SfxService.play(Sfx.pop);
    _game.emote(emoji);
    _room?.sendEmote(emoji);
    setState(() => _emotesOpen = false);
    _gameFocus.requestFocus();
  }

  /// The name a player is shown with in the room, for the card's title
  /// while their profile loads.
  String _nameInRoom(String playerId) =>
      _others.where((p) => p.id == playerId).map((p) => p.name).firstOrNull ??
      AppStrings.profilePlayerName;

  Widget? _buildPanel() {
    final cardId = _cardPlayerId;
    switch (_panel) {
      case _Panel.none:
        return null;
      case _Panel.players:
        return PlayersPanel(
          myName: _myName,
          myAvatarUrl: _myAvatarUrl,
          others: _others,
          onSelect: (id) => _openPlayerCard(id, fromList: true),
          onClose: _closePanel,
        );
      case _Panel.playerCard:
        if (cardId == null) return null;
        return PlayerCardPanel(
          key: ValueKey(cardId),
          playerId: cardId,
          fallbackName: _nameInRoom(cardId),
          onReport: _openReport,
          onClose: _closePanel,
          onBack: _cameFromList ? _openPlayers : null,
          onMessage: _openDirectChat,
        );
      case _Panel.report:
        if (cardId == null) return null;
        return ReportPanel(
          key: ValueKey('report-$cardId'),
          playerId: cardId,
          playerName: _reportName,
          roomId: _roomId,
          onClose: _closePanel,
          onBack: () => _openPlayerCard(cardId, fromList: _cameFromList),
        );
      case _Panel.tasks:
        return TasksPanel(onClaim: _claimTask, onClose: _closePanel);
      case _Panel.inventory:
        return InventoryPanel(onUse: _useItem, onClose: _closePanel);
      case _Panel.leaderboard:
        // Reloads when our coins change.
        return LeaderboardPanel(
          key: ValueKey('board-${CoinService.coins.value}'),
          onClose: _closePanel,
        );
      case _Panel.noticeBoard:
        return NoticeBoardPanel(roomId: _roomId, onClose: _closePanel);
      case _Panel.bar:
        return BarMenuPanel(
          atBar: _atBar,
          canOrder: !_justOrdered,
          onOrder: _orderDrink,
          onClose: _closePanel,
          onPlayBlackjack: _openBlackjack,
        );
      case _Panel.directChat:
        final friend = _chatFriend;
        if (friend == null) return null;
        return DirectChatPanel(
          key: ValueKey('dm-'),
          friend: friend,
          onClose: _closePanel,
          // Back to their player card.
          onBack: cardId == null
              ? null
              : () => _openPlayerCard(cardId, fromList: _cameFromList),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final room = _buildRoom();
          return constraints.maxHeight > constraints.maxWidth
              ? RotatedBox(quarterTurns: 1, child: room)
              : room;
        },
      ),
    );
  }

  Widget _buildRoom() {
    final panel = _buildPanel();

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: GameWidget(game: _game, focusNode: _gameFocus),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _RoomTitle(
              onBack: _leaveRoom,
              playerCount: _playersInRoom,
              onShowPlayers: _openPlayers,
            ),
          ),
          // Next to a free seat: offer to sit. Seated: offer to stand. A
          // small chip under the room title, so it doesn't cover the bar
          // and Bernie in the middle of the view.
          if ((_nearSeat || _sitting) && _panel == _Panel.none)
            Positioned(
              top: 58,
              left: 12,
              child: _HudButton(
                label: _sitting
                    ? AppStrings.standUpButton
                    : AppStrings.clickToSitButton,
                icon: _sitting ? Icons.directions_walk : Icons.event_seat,
                onPressed: () {
                  _sitting ? _game.standUp() : _game.sitDown();
                  // Keep WASD / E working after clicking.
                  _gameFocus.requestFocus();
                },
                filled: true,
                compact: true,
              ),
            ),
          // Drink effects still running, counting down.
          Positioned(
            top: 90,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (drink, seconds) in _activeEffects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _EffectChip(drink: drink, seconds: seconds),
                  ),
              ],
            ),
          ),
          if (_nearNoticeBoard && _panel != _Panel.noticeBoard)
            Positioned(
              top: 62,
              left: 0,
              right: 0,
              child: Center(
                child: _HudButton(
                  label: AppStrings.readNoticeBoardKey,
                  icon: Icons.push_pin_outlined,
                  onPressed: _openNoticeBoard,
                  filled: true,
                ),
              ),
            ),
          ..._buildHud(constraints, panel),
          // Over everything until the room is fully ready, then fades away
          // (and is removed once it has).
          if (!_loadingGone)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _ready,
                child: AnimatedOpacity(
                  opacity: _ready ? 0 : 1,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  onEnd: () {
                    if (_ready && mounted) setState(() => _loadingGone = true);
                  },
                  child: _LoadingScreen(
                    key: const Key('tavern-loading'),
                    step: _loadStep,
                    progress: _loadProgress,
                  ),
                ),
              ),
            ),
          if (_blackjackOpen)
            Positioned.fill(
              child: BlackjackOverlay(
                table: CoinService.table,
                offline: !AuthService.isSignedIn,
                onClose: _closeBlackjack,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHud(BoxConstraints constraints, Widget? panel) {
    final panelWidth = constraints.maxWidth * 0.45 < 340
        ? constraints.maxWidth * 0.45
        : 340.0;

    return [
      // Our coins, top right, with the leaderboard button beside them (an
      // open panel takes that side).
      if (panel == null)
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              // Tasks: a "!" until every reward has been claimed.
              ValueListenableBuilder<List<TaskState>>(
                valueListenable: TaskService.tasks,
                builder: (context, _, _) => _HudIcon(
                  asset: AppImages.hudTask,
                  label: AppStrings.tasksTitle,
                  onTap: _openTasks,
                  badge: !TaskService.allClaimed,
                ),
              ),
              const SizedBox(width: 6),
              _HudIcon(
                asset: AppImages.hudInventory,
                label: AppStrings.inventoryTitle,
                onTap: _openInventory,
              ),
              const SizedBox(width: 6),
              _HudIcon(
                asset: AppImages.hudTrophy,
                label: AppStrings.leaderboardTitle,
                onTap: _openLeaderboard,
              ),
              const SizedBox(width: 8),
              const CoinChip(),
            ],
          ),
        ),
      // Leaving is the back arrow in the room title. In debug builds only,
      // the hitbox toggle sits under the coins.
      if (kDebugMode && _panel == _Panel.none)
        Positioned(
          top: 54,
          right: 12,
          child: _HudButton(
            label: AppStrings.hitboxesButton,
            onPressed: () => setState(_game.toggleHitboxes),
            filled: _game.showingHitboxes,
          ),
        ),
      // An open panel takes the right side; chat returns when it closes.
      if (panel != null)
        Positioned(
          top: 58,
          right: 12,
          bottom: 12,
          width: panelWidth,
          child: panel,
        )
      else
        Positioned(
          right: 12,
          bottom: 12,
          width: panelWidth < 340 ? panelWidth + 40 : 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_messages.isNotEmpty) ...[
                _ChatLog(
                  messages: _messages.length > _visibleMessages
                      ? _messages.sublist(_messages.length - _visibleMessages)
                      : _messages,
                  collapsed: _chatCollapsed,
                  unread: _unreadMessages,
                  onToggle: () => setState(() {
                    _chatCollapsed = !_chatCollapsed;
                    if (!_chatCollapsed) _unreadMessages = 0;
                  }),
                ),
                const SizedBox(height: 8),
              ],
              if (_emotesOpen) ...[
                _EmotePicker(onPick: _sendEmote),
                const SizedBox(height: 8),
              ],
              if (_typers.isNotEmpty) ...[
                _TypingLine(
                  names: [for (final id in _typers.keys) _nameInRoom(id)],
                ),
                const SizedBox(height: 4),
              ],
              _ChatInput(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
                emotesOpen: _emotesOpen,
                onToggleEmotes: () =>
                    setState(() => _emotesOpen = !_emotesOpen),
              ),
            ],
          ),
        ),
    ];
  }
}

/// A framed square HUD button (tasks, inventory, leaderboard), with an
/// optional red "!" badge on its corner.
class _HudIcon extends StatelessWidget {
  const _HudIcon({
    required this.asset,
    required this.label,
    required this.onTap,
    this.badge = false,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: badge ? '$label (new)' : label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size * 99 / 90,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    asset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                if (badge)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Image.asset(
                      AppImages.hudBadge,
                      width: 17,
                      height: 17,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the tavern loads: the tavern itself, dimmed, with the room's
/// name, what's being prepared and a brass progress bar.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({super.key, required this.step, required this.progress});

  final int step;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final line =
        AppStrings.tavernLoadingSteps[step.clamp(
          0,
          AppStrings.tavernLoadingSteps.length - 1,
        )];
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF120B07)),
        // The room in the background, dark and blurred.
        Opacity(
          opacity: 0.35,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Image.asset(
              AppImages.tavernRoom,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.tavernRoomName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFE3A3),
                      shadows: const [
                        Shadow(blurRadius: 8, color: Color(0xFF000000)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Brass-framed bar, filling with warm firelight.
                  Container(
                    height: 16,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1A10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4A86A),
                        width: 1.5,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 250),
                        builder: (context, value, _) => FractionallySizedBox(
                          widthFactor: value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE07A2E), Color(0xFFFFC966)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFF1E3C4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Swift 24s" with the drink's mug, while a drink's effect lasts.
class _EffectChip extends StatelessWidget {
  const _EffectChip({required this.drink, required this.seconds});

  final Drink drink;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xE61B1712),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD4A86A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            drink.asset,
            width: 20,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 5),
          Text(
            '${drink.effectName}  ${seconds}s',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFE3A3),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Panel {
  none,
  players,
  playerCard,
  report,
  noticeBoard,
  directChat,
  bar,
  leaderboard,
  tasks,
  inventory,
}

/// The reactions, as big tappable pictures above the chat box. They share
/// the row's width, up to 48 px each.
class _EmotePicker extends StatelessWidget {
  const _EmotePicker({required this.onPick});

  final void Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emote in emotes)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 48),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Tooltip(
                    message: emote.label,
                    child: Semantics(
                      button: true,
                      label: emote.label,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => onPick(emote.id),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(
                            emote.asset,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTitle extends StatelessWidget {
  const _RoomTitle({
    required this.onBack,
    required this.playerCount,
    required this.onShowPlayers,
  });

  final VoidCallback onBack;
  final int playerCount;
  final VoidCallback onShowPlayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: AppStrings.leaveRoomButton,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: AppColors.ink,
          ),
          Text(
            AppStrings.tavernRoomName,
            style: GoogleFonts.lora(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 6),
          // The live count doubles as the "who's here" button.
          Tooltip(
            message: AppStrings.showPlayers,
            child: InkWell(
              onTap: onShowPlayers,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 16, color: AppColors.ink),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.playerCount(
                        playerCount,
                        RoomService.maxPlayers,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Icon(Icons.expand_more, size: 16, color: AppColors.ink),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final IconData? icon;

  /// A small chip (for prompts that shouldn't hide the room).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: compact ? 10 : 11,
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? 0.3 : 0.6,
    );
    final buttonStyle = OutlinedButton.styleFrom(
      backgroundColor: filled ? AppColors.ink : AppColors.parchment,
      foregroundColor: filled ? AppColors.onInk : AppColors.ink,
      side: BorderSide(color: AppColors.ink),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
      minimumSize: compact ? const Size(0, 26) : null,
      tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: compact ? VisualDensity.compact : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    );
    final iconData = icon;
    if (iconData != null) {
      return SizedBox(
        height: compact ? 26 : 36,
        child: OutlinedButton.icon(
          style: buttonStyle,
          onPressed: onPressed,
          icon: Icon(iconData, size: compact ? 13 : 16),
          label: Text(label, style: style),
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? AppColors.ink : AppColors.parchment,
          foregroundColor: filled ? AppColors.onInk : AppColors.ink,
          side: BorderSide(color: AppColors.ink),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Recent chat with a header bar that folds the messages down out of the way
/// (to see more of the tavern) and opens them back up.
class _ChatLog extends StatelessWidget {
  const _ChatLog({
    required this.messages,
    required this.collapsed,
    required this.unread,
    required this.onToggle,
  });

  final List<ChatMessage> messages;
  final bool collapsed;

  /// Messages from others that arrived while folded.
  final int unread;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = collapsed && unread > 0
        ? AppStrings.chatNewMessages(unread)
        : AppStrings.chatTitle;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: !collapsed,
            label: collapsed ? AppStrings.showChat : AppStrings.hideChat,
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.parchment.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.parchment,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: collapsed
                            ? AppStrings.showChat
                            : AppStrings.hideChat,
                        child: Icon(
                          collapsed
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 22,
                          color: AppColors.parchment,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: _messageList(),
            ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${message.senderName}: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: message.body),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.parchment,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Mira is typing…" in a small dark pill above the chat box.
class _TypingLine extends StatelessWidget {
  const _TypingLine({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          AppStrings.chatTyping(names),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.parchment,
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.emotesOpen,
    required this.onToggleEmotes,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final bool emotesOpen;
  final VoidCallback onToggleEmotes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          selected: emotesOpen,
          label: AppStrings.emotesButton,
          excludeSemantics: true,
          child: Tooltip(
            message: AppStrings.emotesButton,
            child: SizedBox(
              width: 40,
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: emotesOpen
                      ? AppColors.ink
                      : AppColors.parchment,
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: AppColors.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onToggleEmotes,
                child: const Text('😊', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              maxLength: 200,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: AppStrings.chatHint,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                prefixIcon: Icon(
                  Icons.chat_bubble_outline,
                  size: 17,
                  color: AppColors.ink.withValues(alpha: 0.5),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: isSending ? null : onSend,
            child: isSending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onInk,
                    ),
                  )
                : Icon(Icons.send, size: 18, color: AppColors.onInk),
          ),
        ),
      ],
    );
  }
}
