import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../constants/characters.dart';
import '../constants/emotes.dart';
import '../game/tavern_game.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../services/room_service.dart';
import '../services/sfx_service.dart';
import '../game/tavern_map.dart';
import '../theme/app_theme.dart';
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
  bool _chatCollapsed = false;
  int _unreadMessages = 0;

  /// The friend in the private chat panel, opened from their player card.
  Profile? _chatFriend;

  /// At the bar (can order from Bernie), and a short pause after ordering.
  bool _atBar = false;
  bool _justOrdered = false;
  Timer? _orderPause;
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
      ..onInteract = null;
    _orderPause?.cancel();
    _room?.leave();
    _chat?.dispose();
    _gameFocus.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Loads our name, then joins the room's live channel so we see the other
  /// players and they see us.
  Future<void> _enterRoom() async {
    if (!AuthService.isSignedIn) return;

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
    setState(() {
      _panel = _Panel.noticeBoard;
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
  void _orderDrink(String drinkId) {
    if (_justOrdered) return;
    _game.orderDrink(drinkId);
    SfxService.play(Sfx.coin);
    _orderPause?.cancel();
    setState(() => _justOrdered = true);
    _orderPause = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _justOrdered = false);
    });
    _closePanel();
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
      case _Panel.noticeBoard:
        return NoticeBoardPanel(roomId: _roomId, onClose: _closePanel);
      case _Panel.bar:
        return BarMenuPanel(
          atBar: _atBar,
          canOrder: !_justOrdered,
          onOrder: _orderDrink,
          onClose: _closePanel,
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
        ],
      ),
    );
  }

  List<Widget> _buildHud(BoxConstraints constraints, Widget? panel) {
    final panelWidth = constraints.maxWidth * 0.45 < 340
        ? constraints.maxWidth * 0.45
        : 340.0;

    return [
      // Leaving is the back arrow in the room title. In debug builds only,
      // the top-right corner holds the hitbox toggle.
      if (kDebugMode && _panel == _Panel.none)
        Positioned(
          top: 12,
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

enum _Panel { none, players, playerCard, report, noticeBoard, directChat, bar }

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
