import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../utils/last_seen.dart';
import '../widgets/fantasy_ui.dart';
import '../widgets/player_avatar.dart';

/// Friends list: real players you've added, with their photo, an online dot
/// and when they were last active. Online friends are listed first.
/// The "+" button opens Add Friends (search players, answer requests).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<Profile> _friends = [];
  int _pendingRequests = 0;
  bool _isLoading = true;
  bool _loadFailed = false;
  Timer? _refreshTimer;

  /// Players we're not connected to yet. Null while loading.
  List<Profile>? _suggestions;

  /// Suggested players we just sent a request to (shown as "Pending").
  final Set<String> _requested = {};
  final Set<String> _sending = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    // Keep online dots and "Active ... ago" current while the screen is open.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadFriends(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (!AuthService.isSignedIn) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final entries = await FriendsService.fetchAll();
      if (!mounted) return;
      final now = DateTime.now();
      final friends = [
        for (final e in entries)
          if (e.status == FriendStatus.friends) e.profile,
      ]..sort((a, b) => _compareFriends(a, b, now));
      setState(() {
        _friends = friends;
        _pendingRequests = entries
            .where((e) => e.status == FriendStatus.requestReceived)
            .length;
        _isLoading = false;
        _loadFailed = false;
      });
      await _loadSuggestions({for (final e in entries) e.profile.id});
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Everyone else who has signed in, minus [connected] (friends and
  /// requests either way). Players we just added stay listed as Pending.
  Future<void> _loadSuggestions(Set<String> connected) async {
    try {
      final exclude = connected.difference(_requested);
      final players = await FriendsService.suggestions(exclude: exclude);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _suggestions = players..sort((a, b) => _compareFriends(a, b, now));
      });
    } catch (_) {
      if (mounted && _suggestions == null) {
        setState(() => _suggestions = const []);
      }
    }
  }

  Future<void> _sendRequest(Profile player) async {
    if (_sending.contains(player.id)) return;
    setState(() => _sending.add(player.id));
    try {
      await FriendsService.sendRequest(player.id);
      if (mounted) setState(() => _requested.add(player.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.friendActionError)),
        );
      }
      // They may have sent us a request at the same moment; refresh.
      _loadFriends();
    } finally {
      if (mounted) setState(() => _sending.remove(player.id));
    }
  }

  bool _matchesQuery(Profile p) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        p.displayName.toLowerCase().contains(q) ||
        p.username.toLowerCase().contains(q);
  }

  /// Online first, then most recently active, then by name.
  static int _compareFriends(Profile a, Profile b, DateTime now) {
    final online = (b.isOnline(now) ? 1 : 0) - (a.isOnline(now) ? 1 : 0);
    if (online != 0) return online;
    final seenA = a.lastSeenAt ?? DateTime(2000);
    final seenB = b.lastSeenAt ?? DateTime(2000);
    final seen = seenB.compareTo(seenA);
    if (seen != 0) return seen;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  Future<void> _openAddFriends() async {
    await Navigator.of(context).pushNamed('/friends/add');
    if (mounted) _loadFriends();
  }

  Future<void> _showFriend(Profile friend) async {
    final removed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => _FriendSheet(friend: friend),
    );
    if (removed == true) _loadFriends();
  }

  List<Profile> get _filteredFriends => _friends.where(_matchesQuery).toList();

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
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FantasyTitleBar(
                  title: AppStrings.friendsTitle,
                  trailing: FramedIconButton(
                    icon: Icons.add,
                    tooltip: AppStrings.addFriendsTitle,
                    badgeCount: _pendingRequests,
                    onPressed: _openAddFriends,
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
                    child: Stack(
                      children: [
                        // The lamp-post terrace sits behind the list.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.45,
                              child: ShaderMask(
                                shaderCallback: (rect) => const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.white],
                                  stops: [0, 0.35],
                                ).createShader(rect),
                                blendMode: BlendMode.dstIn,
                                child: Image.asset(
                                  AppImages.friendsFooterScene,
                                  fit: BoxFit.fitWidth,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                              child: SearchField(
                                controller: _searchController,
                                hintText: AppStrings.searchFriendsHint,
                                onChanged: (v) => setState(() => _query = v),
                              ),
                            ),
                            Expanded(child: _buildList()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const FantasyBottomNav(currentIndex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
      );
    }
    if (_loadFailed && _friends.isEmpty) {
      return _Message(
        text: AppStrings.friendsLoadError,
        actionLabel: AppStrings.retryButton,
        onAction: () {
          setState(() => _isLoading = true);
          _loadFriends();
        },
      );
    }
    final now = DateTime.now();
    final friends = _filteredFriends;
    final suggestions = _suggestions?.where(_matchesQuery).toList();
    final searching = _query.trim().isNotEmpty;

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _loadFriends,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          // --- Your friends ---
          if (_friends.isEmpty)
            _InlineNote(
              text: AppStrings.noFriendsYetShort,
              actionLabel: AppStrings.findPlayersButton,
              onAction: _openAddFriends,
            )
          else ...[
            _SectionLabel(AppStrings.yourFriendsHeader(_friends.length)),
            if (friends.isEmpty)
              _InlineNote(text: AppStrings.noFriendsMatch(_query.trim()))
            else
              for (final friend in friends)
                PlayerRow(
                  profile: friend,
                  subtitle: lastSeenLabel(friend, now),
                  isOnline: friend.isOnline(now),
                  onTap: () => _showFriend(friend),
                  trailing: FramedIconButton(
                    icon: Icons.chevron_right,
                    tooltip: AppStrings.viewFriend(friend.displayName),
                    dark: true,
                    size: 40,
                    onPressed: () => _showFriend(friend),
                  ),
                ),
          ],

          // --- Everyone else who has signed in ---
          const SizedBox(height: 12),
          _SectionLabel(AppStrings.suggestedHeader),
          if (suggestions == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.ink,
                  ),
                ),
              ),
            )
          else if (suggestions.isEmpty)
            _InlineNote(
              text: searching
                  ? AppStrings.noPlayersMatch(_query.trim())
                  : AppStrings.noSuggestions,
            )
          else
            for (final player in suggestions)
              PlayerRow(
                profile: player,
                subtitle: lastSeenLabel(player, now),
                isOnline: player.isOnline(now),
                trailing: _requested.contains(player.id)
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          AppStrings.pendingLabel,
                          style: FantasyText.mono(size: 13),
                        ),
                      )
                    : FramedTextButton(
                        label: AppStrings.addButton,
                        onPressed: _sending.contains(player.id)
                            ? null
                            : () => _sendRequest(player),
                      ),
              ),
        ],
      ),
    );
  }
}

/// Search box in its ornate frame. Shared with the Add Friends screen.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FantasyCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: FantasyText.mono(size: 15, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: hintText,
          hintStyle: FantasyText.mono(size: 15),
          prefixIcon: const Icon(Icons.search, size: 24, color: AppColors.ink),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// One player in an ornate frame: photo in a brown ring with a status dot,
/// name, a status line, and [trailing] (a chevron, ADD, or request buttons).
/// A faint castle watermark sits behind the right side.
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.profile,
    required this.subtitle,
    required this.isOnline,
    this.trailing,
    this.onTap,
  });

  final Profile profile;
  final String subtitle;
  final bool isOnline;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// flower_banner.png is 2169 x 725.
  static const double _bannerAspect = 2169 / 725;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FantasyCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: LayoutBuilder(
              // Rows take the flower banner's 3:1 shape so its flowers,
              // gold line and lantern sit where they were drawn.
              builder: (context, constraints) => ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxWidth / _bannerAspect,
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Opacity(
                            opacity: 0.9,
                            child: Image.asset(
                              AppImages.flowerBanner,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 14, 24),
                      child: Row(
                        children: [
                          _RingedAvatar(
                            photoUrl: profile.avatarUrl,
                            isOnline: isOnline,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName.isEmpty
                                      ? AppStrings.profilePlayerName
                                      : profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FantasyText.name(size: 20),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOnline
                                            ? AppColors.online
                                            : AppColors.parchmentDim,
                                        border: isOnline
                                            ? null
                                            : Border.all(
                                                color: AppColors.navMuted,
                                                width: 1,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: FantasyText.mono(size: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 8),
                            trailing!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round photo in a warm brown ring, with a small status dot.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.photoUrl, required this.isOnline});

  final String? photoUrl;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 64,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: AppColors.frameBrown, width: 2),
            ),
            child: PlayerAvatar(photoUrl: photoUrl, radius: 27),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.online : AppColors.parchmentDim,
                border: Border.all(color: AppColors.card, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A friend's card: big photo, name, username, status, and Remove friend.
/// Pops `true` if the friend was removed.
class _FriendSheet extends StatefulWidget {
  const _FriendSheet({required this.friend});

  final Profile friend;

  @override
  State<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<_FriendSheet> {
  bool _confirming = false;
  bool _removing = false;

  Future<void> _remove() async {
    if (!_confirming) {
      setState(() => _confirming = true);
      return;
    }
    setState(() => _removing = true);
    try {
      await FriendsService.remove(widget.friend.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _removing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.friendActionError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final online = friend.isOnline();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(
              photoUrl: friend.avatarUrl,
              radius: 40,
              isOnline: online,
            ),
            const SizedBox(height: 12),
            Text(
              friend.displayName,
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (friend.username.isNotEmpty)
              Text(
                '@${friend.username}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.ink.withValues(alpha: 0.55),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              lastSeenLabel(friend),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: online
                    ? const Color(0xFF1E9E5A)
                    : AppColors.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _removing ? null : _remove,
                child: Text(
                  _confirming
                      ? AppStrings.confirmRemoveFriend
                      : AppStrings.removeFriendButton,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tracked heading above a group of players.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: FantasyText.mono(
          size: 12.5,
          color: AppColors.ink,
          weight: FontWeight.w700,
          spacing: 2.5,
        ),
      ),
    );
  }
}

/// A one-line note inside the list, with an optional action.
class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.courierPrime(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.courierPrime(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.courierPrime(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.courierPrime(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
