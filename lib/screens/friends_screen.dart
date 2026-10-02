import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_strings.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../utils/last_seen.dart';
import '../widgets/cybernie_bottom_nav.dart';
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
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

  List<Profile> get _filteredFriends {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(q) ||
              f.username.toLowerCase().contains(q),
        )
        .toList();
  }

  TextStyle get _titleStyle => GoogleFonts.cinzel(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            // Top bar: "Friends" title + add-friend button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.friendsTitle, style: _titleStyle),
                  _AddFriendButton(
                    badgeCount: _pendingRequests,
                    onTap: _openAddFriends,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SearchField(
                controller: _searchController,
                hintText: AppStrings.searchFriendsHint,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(child: _buildList()),

            const CybernieBottomNav(currentIndex: 1),
          ],
        ),
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
    if (_friends.isEmpty) {
      return _Message(
        text: AppStrings.noFriendsYet,
        actionLabel: AppStrings.findPlayersButton,
        onAction: _openAddFriends,
      );
    }

    final friends = _filteredFriends;
    if (friends.isEmpty) {
      return _Message(text: AppStrings.noFriendsMatch(_query.trim()));
    }

    final now = DateTime.now();
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _loadFriends,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return PlayerRow(
            profile: friend,
            subtitle: lastSeenLabel(friend, now),
            isOnline: friend.isOnline(now),
            onTap: () => _showFriend(friend),
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.ink.withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }

}

/// Search field with the fine, squared outline used in the mockup.
/// Shared with the Add Friends screen.
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
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.65)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.ink.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 19,
            color: AppColors.ink.withValues(alpha: 0.65),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

/// One player row: photo with online dot, name, a status line and whatever
/// [trailing] is (a chevron, or buttons on the Add Friends screen).
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.ink.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            PlayerAvatar(
              photoUrl: profile.avatarUrl,
              radius: 20,
              isOnline: isOnline,
            ),
            const SizedBox(width: 12),
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
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isOnline ? FontWeight.w600 : FontWeight.w400,
                      color: isOnline
                          ? const Color(0xFF1E9E5A)
                          : AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Small bordered square "+" button that opens Add Friends, with a badge
/// showing how many friend requests are waiting.
class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.onTap, required this.badgeCount});

  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.addFriendsTitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink.withValues(alpha: 0.55)),
              ),
              child: const Icon(Icons.add, size: 18, color: AppColors.ink),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
              style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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

