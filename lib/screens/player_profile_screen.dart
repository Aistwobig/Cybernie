import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../constants/characters.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';
import '../utils/last_seen.dart';
import '../widgets/fantasy_ui.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sprite_walk_preview.dart';
import 'direct_chat_screen.dart';

/// Another player's profile: photo, name, character, bio, whether they're
/// online (or when they were last active), and Add friend / Message.
/// Opened by tapping a player, or by scanning their profile QR code.
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key, required this.playerId});

  final String playerId;

  /// Opens [playerId]'s profile on top of the current screen.
  static Future<void> open(BuildContext context, String playerId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerProfileScreen(playerId: playerId),
        ),
      );

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Profile? _profile;
  FriendStatus? _status;
  bool _loadFailed = false;
  bool _busy = false;

  bool get _isMe =>
      AuthService.isSignedIn && widget.playerId == FriendsService.myId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ProfileService.fetchById(widget.playerId);
      var status = FriendStatus.none;
      if (AuthService.isSignedIn && !_isMe) {
        final entries = await FriendsService.fetchAll();
        status =
            entries
                .where((e) => e.profile.id == widget.playerId)
                .map((e) => e.status)
                .firstOrNull ??
            FriendStatus.none;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _status = status;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _act(Future<void> Function() action, FriendStatus next) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _status = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.friendActionError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFriend(Profile profile) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.removeFriendTitle),
        content: Text(AppStrings.removeFriendConfirm(profile.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.removeFriendButton),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _act(() => FriendsService.remove(profile.id), FriendStatus.none);
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      AppNav.goHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CastleBackdrop(height: 200),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FantasyTitleBar(
                  title: AppStrings.playerProfileTitle,
                  leading: FramedIconButton(
                    icon: Icons.arrow_back,
                    tooltip: AppStrings.backButton,
                    onPressed: _back,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final profile = _profile;
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.playerProfileError,
                textAlign: TextAlign.center,
                style: FantasyText.mono(size: 14),
              ),
              const SizedBox(height: 12),
              FramedTextButton(
                label: AppStrings.retryButton,
                onPressed: () {
                  setState(() => _loadFailed = false);
                  _load();
                },
              ),
            ],
          ),
        ),
      );
    }
    if (profile == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
      );
    }

    final now = DateTime.now();
    final online = profile.isOnline(now);
    final character = characterAt(profile.characterIndex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Center(
          child: PlayerAvatar(
            photoUrl: profile.avatarUrl,
            radius: 48,
            isOnline: online,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: FantasyText.name(size: 24),
        ),
        if (profile.username.isNotEmpty)
          Text(
            '@${profile.username}',
            textAlign: TextAlign.center,
            style: FantasyText.mono(size: 13, color: AppColors.inkMuted),
          ),
        const SizedBox(height: 8),
        // Online, or when they were last active.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: online ? AppColors.online : AppColors.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              lastSeenLabel(profile, now),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: online ? AppColors.online : AppColors.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FantasyCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Their character, idling.
              SizedBox(
                width: 72,
                height: 88,
                child: _CharacterPreview(character: character),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.aboutLabel,
                      style: FantasyText.mono(
                        size: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.bio.isEmpty
                          ? AppStrings.noBioYet(profile.displayName)
                          : profile.bio,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.4,
                        fontStyle: profile.bio.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: profile.bio.isEmpty
                            ? AppColors.inkMuted
                            : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.playsAs(character.name),
                      style: FantasyText.mono(
                        size: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ..._actions(profile),
      ],
    );
  }

  List<Widget> _actions(Profile profile) {
    if (_isMe) {
      return [
        Text(
          AppStrings.thisIsYou,
          textAlign: TextAlign.center,
          style: FantasyText.mono(size: 13, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 10),
        FantasyButton(
          label: AppStrings.editMyProfile,
          onPressed: () => AppNav.goToTab(context, '/profile'),
        ),
      ];
    }
    if (!AuthService.isSignedIn) {
      return [
        Text(
          AppStrings.signInToAddFriends,
          textAlign: TextAlign.center,
          style: FantasyText.mono(size: 13, color: AppColors.inkMuted),
        ),
      ];
    }
    final id = profile.id;
    final status = _status ?? FriendStatus.none;
    final (String label, VoidCallback? onPressed) = switch (status) {
      FriendStatus.none => (
        AppStrings.addFriendButton,
        () => _act(
          () => FriendsService.sendRequest(id),
          FriendStatus.requestSent,
        ),
      ),
      FriendStatus.requestReceived => (
        AppStrings.acceptFriendButton,
        () =>
            _act(() => FriendsService.acceptRequest(id), FriendStatus.friends),
      ),
      FriendStatus.requestSent => (AppStrings.requestSentLabel, null),
      FriendStatus.friends => (AppStrings.alreadyFriendsLabel, null),
    };
    return [
      if (status == FriendStatus.friends)
        // Friends: message them.
        FantasyButton(
          label: AppStrings.messageButton,
          onPressed: () => DirectChatScreen.open(context, profile),
        )
      else
        FantasyButton(
          label: label,
          busy: _busy,
          onPressed: _busy ? null : onPressed,
        ),
      const SizedBox(height: 10),
      if (status == FriendStatus.friends)
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : () => _removeFriend(profile),
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: Text(
              AppStrings.removeFriendButton,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
            ),
          ),
        )
      else if (status == FriendStatus.requestSent)
        Text(
          AppStrings.requestSentHint(profile.displayName),
          textAlign: TextAlign.center,
          style: FantasyText.mono(size: 12, color: AppColors.inkMuted),
        ),
    ];
  }
}

/// A character's front-facing idle, as on the character picker.
class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({required this.character});

  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    final profileIdle = character.profileIdleSheet;
    return SpriteWalkPreview(
      assetPath: profileIdle ?? character.idleSheet ?? character.sheet,
      columns: profileIdle != null
          ? character.profileIdleFrames
          : character.frames,
      rows: profileIdle != null ? 1 : 4,
      facing: SpriteDirection.south,
      frameDuration: profileIdle != null
          ? Duration(milliseconds: character.profileIdleFrameMs)
          : Duration(microseconds: 200000 * 8 ~/ character.frames),
    );
  }
}
