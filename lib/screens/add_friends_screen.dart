import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../models/profile.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../utils/last_seen.dart';
import 'friends_screen.dart' show PlayerRow, SearchField;

/// Add Friends: search every player who has signed in, send requests, and
/// accept or decline the requests other players sent you.
class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// Our connection to each player we have a friendship row with.
  Map<String, FriendStatus> _statusById = {};

  /// Requests other players sent us, and ones we sent that are waiting.
  List<Profile> _requests = [];
  List<Profile> _sent = [];
  List<Profile> _results = [];
  bool _isSearching = false;

  /// Players whose button is mid-request, so it can't be tapped twice.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    try {
      final entries = await FriendsService.fetchAll();
      if (!mounted) return;
      setState(() {
        _statusById = {for (final e in entries) e.profile.id: e.status};
        _requests = [
          for (final e in entries)
            if (e.status == FriendStatus.requestReceived) e.profile,
        ];
        _sent = [
          for (final e in entries)
            if (e.status == FriendStatus.requestSent) e.profile,
        ];
      });
    } catch (_) {
      _showError();
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final query = _query.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await FriendsService.searchPlayers(query);
      // Ignore answers to an older query the player has typed past.
      if (!mounted || query != _query.trim()) return;
      setState(() => _results = results);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Runs a friend action for [player], then refreshes requests and buttons.
  Future<void> _act(Profile player, Future<void> Function() action) async {
    if (_busy.contains(player.id)) return;
    setState(() => _busy.add(player.id));
    try {
      await action();
      await _loadConnections();
    } catch (_) {
      // e.g. they sent us a request at the same moment; reload to show it.
      await _loadConnections();
      _showError();
    } finally {
      if (mounted) setState(() => _busy.remove(player.id));
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.friendActionError)));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SearchField(
                controller: _searchController,
                hintText: AppStrings.searchPlayersHint,
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.ink,
                onRefresh: _loadConnections,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                  children: [
                    // Search results first while searching.
                    if (_query.trim().isNotEmpty) ...[
                      _SectionLabel(AppStrings.resultsHeader),
                      ..._buildResults(now),
                      const SizedBox(height: 8),
                    ],
                    // Requests to you: accept or decline.
                    _SectionLabel(
                      AppStrings.friendRequestsHeader(_requests.length),
                    ),
                    if (_requests.isEmpty)
                      const _Hint(AppStrings.noFriendRequests)
                    else
                      for (final player in _requests)
                        PlayerRow(
                          profile: player,
                          subtitle: lastSeenLabel(player, now),
                          isOnline: player.isOnline(now),
                          trailing: _requestButtons(player),
                        ),
                    const SizedBox(height: 8),
                    // Requests you sent that are still waiting: cancel.
                    _SectionLabel(AppStrings.sentRequestsHeader(_sent.length)),
                    if (_sent.isEmpty)
                      const _Hint(AppStrings.noSentRequests)
                    else
                      for (final player in _sent)
                        PlayerRow(
                          profile: player,
                          subtitle: lastSeenLabel(player, now),
                          isOnline: player.isOnline(now),
                          trailing: _sentButton(player),
                        ),
                  ],
                ),
              ),
            ),
            const _SafetyNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 22),
            color: AppColors.ink,
          ),
          const SizedBox(width: 2),
          Text(
            AppStrings.addFriendsTitle,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResults(DateTime now) {
    if (_isSearching && _results.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.ink,
              strokeWidth: 2,
            ),
          ),
        ),
      ];
    }
    if (_results.isEmpty) {
      return [_Hint(AppStrings.noPlayersMatch(_query.trim()))];
    }
    return [
      for (final player in _results)
        PlayerRow(
          profile: player,
          subtitle: player.username.isEmpty
              ? lastSeenLabel(player, now)
              : '@${player.username} · ${lastSeenLabel(player, now)}',
          isOnline: player.isOnline(now),
          trailing: _resultButton(player),
        ),
    ];
  }

  Widget _requestButtons(Profile player) {
    final busy = _busy.contains(player.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallButton(
          label: AppStrings.acceptButton,
          filled: true,
          onPressed: busy
              ? null
              : () =>
                    _act(player, () => FriendsService.acceptRequest(player.id)),
        ),
        const SizedBox(width: 6),
        _SmallButton(
          label: AppStrings.declineButton,
          onPressed: busy
              ? null
              : () => _act(player, () => FriendsService.remove(player.id)),
        ),
      ],
    );
  }

  /// Takes back a request we sent.
  Widget _sentButton(Profile player) {
    final busy = _busy.contains(player.id);
    return _SmallButton(
      label: AppStrings.cancelButton,
      onPressed: busy
          ? null
          : () => _act(player, () => FriendsService.remove(player.id)),
    );
  }

  Widget _resultButton(Profile player) {
    final busy = _busy.contains(player.id);
    switch (_statusById[player.id] ?? FriendStatus.none) {
      case FriendStatus.friends:
        return const _StatusText(AppStrings.friendsLabel);
      case FriendStatus.requestSent:
        return const _StatusText(AppStrings.pendingLabel);
      case FriendStatus.requestReceived:
        return _SmallButton(
          label: AppStrings.acceptButton,
          filled: true,
          onPressed: busy
              ? null
              : () =>
                    _act(player, () => FriendsService.acceptRequest(player.id)),
        );
      case FriendStatus.none:
        return _SmallButton(
          label: AppStrings.addButton,
          onPressed: busy
              ? null
              : () => _act(player, () => FriendsService.sendRequest(player.id)),
        );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    );
    const padding = EdgeInsets.symmetric(horizontal: 10);

    return SizedBox(
      height: 28,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.onInk,
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: Text(label, style: style),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: BorderSide(color: AppColors.ink),
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: Text(label, style: style),
            ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.ink.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.ink.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.15)),
      ),
      child: Text(
        AppStrings.friendSafetyNote,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          color: AppColors.ink.withValues(alpha: 0.6),
          height: 1.4,
        ),
      ),
    );
  }
}
