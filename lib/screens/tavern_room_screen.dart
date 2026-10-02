import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../game/tavern_game.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../services/room_service.dart';
import '../game/tavern_map.dart';
import '../theme/app_theme.dart';

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
    characterSheet: AppImages.characterMenAnim,
  );
  final FocusNode _gameFocus = FocusNode();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  ChatService? _chat;
  RoomService? _room;
  bool _isSending = false;
  int _playersInRoom = 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _enterRoom();
    _connectChat();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _game.onLocalMove = null;
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
    } catch (_) {
      // Keep the default name.
    }
    if (!mounted) return;
    _game.playerName = name;

    final room = RoomService(_roomId);
    _room = room;
    _game.onLocalMove = (x, y, facing, moving) => room.sendMove(
      PlayerMove(
        playerId: room.myId,
        x: x,
        y: y,
        facing: facing.index,
        moving: moving,
      ),
    );

    await room.join(
      name: name,
      x: TavernMap.spawnPoint.dx,
      y: TavernMap.spawnPoint.dy,
      onPlayers: (others) {
        _game.syncOtherPlayers([
          for (final p in others) (id: p.id, name: p.name, x: p.x, y: p.y),
        ]);
        if (mounted) setState(() => _playersInRoom = others.length + 1);
      },
      onMove: (move) => _game.moveOtherPlayer(
        move.playerId,
        move.x,
        move.y,
        move.facing,
        move.moving,
      ),
      onSomeoneJoined: _game.broadcastPosition,
      onError: () => _showSnack(AppStrings.roomConnectionError),
    );
  }

  Future<void> _connectChat() async {
    if (!AuthService.isSignedIn) return;
    final chat = ChatService(_roomId);
    _chat = chat;
    chat.subscribe((message) {
      if (!mounted || _messages.any((m) => m.id == message.id)) return;
      setState(() => _messages.add(message));
      // Our own bubble is shown as soon as we send; show everyone else's.
      if (message.senderId != chat.myId) {
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
    return Stack(
      children: [
        Positioned.fill(
          child: GameWidget(game: _game, focusNode: _gameFocus),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _RoomTitle(onBack: _leaveRoom, playerCount: _playersInRoom),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              if (kDebugMode) ...[
                _HudButton(
                  label: AppStrings.hitboxesButton,
                  onPressed: () => setState(_game.toggleHitboxes),
                  filled: _game.showingHitboxes,
                ),
                const SizedBox(width: 8),
              ],
              _HudButton(
                label: AppStrings.leaveRoomButton,
                onPressed: _leaveRoom,
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_messages.isNotEmpty) ...[
                _ChatLog(
                  messages: _messages.length > _visibleMessages
                      ? _messages.sublist(_messages.length - _visibleMessages)
                      : _messages,
                ),
                const SizedBox(height: 8),
              ],
              _ChatInput(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomTitle extends StatelessWidget {
  const _RoomTitle({required this.onBack, required this.playerCount});

  final VoidCallback onBack;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(right: 14),
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
          const SizedBox(width: 10),
          Icon(
            Icons.people_outline,
            size: 16,
            color: AppColors.ink.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            AppStrings.playerCount(playerCount, RoomService.maxPlayers),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink.withValues(alpha: 0.7),
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
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? AppColors.ink : AppColors.parchment,
          foregroundColor: filled ? Colors.white : AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
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

class _ChatLog extends StatelessWidget {
  const _ChatLog({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
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
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
