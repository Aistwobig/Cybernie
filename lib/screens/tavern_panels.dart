import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../constants/drinks.dart';
import '../models/profile.dart';
import '../services/friends_service.dart';
import '../services/notice_board_service.dart';
import '../services/profile_service.dart';
import '../services/report_service.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../utils/last_seen.dart';
import '../widgets/direct_chat_view.dart';
import '../widgets/player_avatar.dart';

// Side panels shown inside the tavern. They live in the room's own Stack
// (not as dialogs or bottom sheets) so they rotate with the room when it is
// drawn sideways in a portrait window.

/// Parchment panel with a title row and a close button.
class TavernPanel extends StatelessWidget {
  const TavernPanel({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.onBack,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.parchment,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: AppStrings.backButton,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: AppColors.ink,
                  )
                else
                  const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.closeButton,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.ink,
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.ink.withValues(alpha: 0.15)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

TextStyle _body({double size = 13, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: AppColors.ink);

TextStyle _muted({double size = 12}) => GoogleFonts.inter(
  fontSize: size,
  color: AppColors.ink.withValues(alpha: 0.6),
);

// --- Who's here --------------------------------------------------------------

/// Everyone in the room, you first. Tap someone to open their card.
class PlayersPanel extends StatelessWidget {
  const PlayersPanel({
    super.key,
    required this.myName,
    required this.myAvatarUrl,
    required this.others,
    required this.onSelect,
    required this.onClose,
  });

  final String myName;
  final String? myAvatarUrl;
  final List<RoomPlayer> others;
  final void Function(String playerId) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sorted = [...others]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return TavernPanel(
      title: AppStrings.playersHere(others.length + 1, RoomService.maxPlayers),
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          _PlayerTile(
            name: myName,
            avatarUrl: myAvatarUrl,
            trailing: Text(AppStrings.youLabel, style: _muted()),
          ),
          for (final player in sorted)
            _PlayerTile(
              name: player.name,
              avatarUrl: player.avatarUrl,
              onTap: () => onSelect(player.id),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.ink,
              ),
            ),
          if (others.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(AppStrings.aloneInRoom, style: _muted(size: 13)),
            ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.name,
    required this.avatarUrl,
    required this.trailing,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            PlayerAvatar(photoUrl: avatarUrl, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(size: 14, weight: FontWeight.w600),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// --- Player card -------------------------------------------------------------

/// Another player's photo, name and username, with friend and report actions.
class PlayerCardPanel extends StatefulWidget {
  const PlayerCardPanel({
    super.key,
    required this.playerId,
    required this.fallbackName,
    required this.onReport,
    required this.onClose,
    this.onBack,
    this.onMessage,
  });

  final String playerId;

  /// Opens a private chat; offered once you're friends.
  final void Function(Profile friend)? onMessage;

  /// Shown while the profile loads (the name from the room).
  final String fallbackName;
  final void Function(String playerId, String name) onReport;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  State<PlayerCardPanel> createState() => _PlayerCardPanelState();
}

class _PlayerCardPanelState extends State<PlayerCardPanel> {
  Profile? _profile;
  FriendStatus? _status;
  bool _loadFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerCardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId) {
      setState(() {
        _profile = null;
        _status = null;
        _loadFailed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.playerId;
    try {
      final results = await Future.wait([
        ProfileService.fetchById(id),
        FriendsService.fetchAll(),
      ]);
      if (!mounted || id != widget.playerId) return;
      final entries = results[1] as List<FriendEntry>;
      setState(() {
        _profile = results[0] as Profile;
        _status =
            entries
                .where((e) => e.profile.id == id)
                .map((e) => e.status)
                .firstOrNull ??
            FriendStatus.none;
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

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : widget.fallbackName;

    return TavernPanel(
      title: name,
      onClose: widget.onClose,
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          Center(
            child: PlayerAvatar(
              photoUrl: profile?.avatarUrl,
              radius: 36,
              isOnline: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (profile != null && profile.username.isNotEmpty)
            Text(
              '@${profile.username}',
              textAlign: TextAlign.center,
              style: _muted(),
            ),
          if (profile != null && profile.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile.bio,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          Text(
            AppStrings.inThisRoom,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E7A45),
            ),
          ),
          const SizedBox(height: 16),
          if (_loadFailed)
            Text(
              AppStrings.playerCardError,
              textAlign: TextAlign.center,
              style: _muted(size: 13),
            )
          else
            _friendAction(),
          if (_status == FriendStatus.friends &&
              profile != null &&
              widget.onMessage != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.ink,
                  side: BorderSide(color: AppColors.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => widget.onMessage!(profile),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(
                  AppStrings.messageButton,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => widget.onReport(widget.playerId, name),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(
              AppStrings.reportPlayer,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendAction() {
    final id = widget.playerId;
    final status = _status;

    if (status == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ink,
          ),
        ),
      );
    }

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

    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          disabledBackgroundColor: AppColors.parchmentDim,
          disabledForegroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _busy ? null : onPressed,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

// --- Report -------------------------------------------------------------------

/// Pick a reason (plus optional details) and file a report.
class ReportPanel extends StatefulWidget {
  const ReportPanel({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.roomId,
    required this.onClose,
    required this.onBack,
  });

  final String playerId;
  final String playerName;
  final String roomId;
  final VoidCallback onClose;
  final VoidCallback onBack;

  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  ReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ReportService.reportPlayer(
        reportedId: widget.playerId,
        roomId: widget.roomId,
        reason: reason,
        details: _details.text,
      );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.reportError)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TavernPanel(
      title: AppStrings.reportTitle(widget.playerName),
      onClose: widget.onClose,
      onBack: _sent ? null : widget.onBack,
      child: _sent ? _buildThanks() : _buildForm(),
    );
  }

  Widget _buildThanks() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: AppColors.ink),
          const SizedBox(height: 10),
          Text(
            AppStrings.reportThanks,
            textAlign: TextAlign.center,
            style: _body(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.reportThanksDetail,
            textAlign: TextAlign.center,
            style: _muted(size: 12.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: BorderSide(color: AppColors.ink),
              minimumSize: const Size(120, 44),
            ),
            onPressed: widget.onClose,
            child: Text(
              AppStrings.doneButton,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        Text(AppStrings.reportPrompt, style: _muted(size: 12.5)),
        const SizedBox(height: 8),
        RadioGroup<ReportReason>(
          groupValue: _reason,
          onChanged: (value) => setState(() => _reason = value),
          child: Column(
            children: [
              for (final reason in ReportReason.values)
                RadioListTile<ReportReason>(
                  value: reason,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.ink,
                  title: Text(reason.label, style: _body()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _details,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          style: _body(),
          decoration: const InputDecoration(
            hintText: AppStrings.reportDetailsHint,
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _reason == null || _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppStrings.sendReportButton,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// --- Notice board --------------------------------------------------------------

/// Read the room's notes, pin your own, take yours down.
class NoticeBoardPanel extends StatefulWidget {
  const NoticeBoardPanel({
    super.key,
    required this.roomId,
    required this.onClose,
  });

  final String roomId;
  final VoidCallback onClose;

  @override
  State<NoticeBoardPanel> createState() => _NoticeBoardPanelState();
}

class _NoticeBoardPanelState extends State<NoticeBoardPanel> {
  final TextEditingController _note = TextEditingController();
  List<NoticeNote>? _notes;
  bool _missing = false;
  bool _failed = false;
  bool _pinning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notes = await NoticeBoardService.fetch(widget.roomId);
      if (mounted) {
        setState(() {
          _notes = notes;
          _failed = false;
        });
      }
    } on NoticeBoardMissingException {
      if (mounted) setState(() => _missing = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pin() async {
    final text = _note.text.trim();
    if (text.isEmpty || _pinning) return;
    setState(() => _pinning = true);
    try {
      await NoticeBoardService.pin(widget.roomId, text);
      _note.clear();
      await _load();
    } catch (_) {
      _snack(AppStrings.noticeBoardError);
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  Future<void> _takeDown(NoticeNote note) async {
    try {
      await NoticeBoardService.takeDown(note.id);
      await _load();
    } catch (_) {
      _snack(AppStrings.noticeBoardError);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return TavernPanel(
      title: AppStrings.noticeBoardTitle,
      onClose: widget.onClose,
      child: _missing ? _buildMissing() : _buildBoard(),
    );
  }

  Widget _buildMissing() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          AppStrings.noticeBoardMissing,
          textAlign: TextAlign.center,
          style: _muted(size: 13),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final notes = _notes;
    final myId = NoticeBoardService.myId;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _note,
                  maxLength: NoticeBoardService.maxLength,
                  maxLines: 2,
                  minLines: 1,
                  style: _body(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _pin(),
                  decoration: const InputDecoration(
                    hintText: AppStrings.noticeBoardHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.onInk,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _pinning ? null : _pin,
                  child: Text(
                    AppStrings.pinNoteButton,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes == null
              ? Center(
                  child: _failed
                      ? TextButton(
                          onPressed: _load,
                          child: Text(
                            AppStrings.retryButton,
                            style: _body(weight: FontWeight.w700),
                          ),
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                )
              : notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      AppStrings.noticeBoardEmpty,
                      textAlign: TextAlign.center,
                      style: _muted(size: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _NoteCard(
                      note: note,
                      ago: timeAgo(note.createdAt, now),
                      onTakeDown: note.authorId == myId
                          ? () => _takeDown(note)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One pinned note: a slip of paper with the text, author and time.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.ago, this.onTakeDown});

  final NoticeNote note;
  final String ago;
  final VoidCallback? onTakeDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.parchmentSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.body, style: _body(size: 13.5)),
                const SizedBox(height: 4),
                Text('${note.authorName} · $ago', style: _muted(size: 11.5)),
              ],
            ),
          ),
          if (onTakeDown != null)
            IconButton(
              tooltip: AppStrings.takeDownNote,
              onPressed: onTakeDown,
              icon: const Icon(Icons.delete_outline, size: 19),
              color: AppColors.ink,
            ),
        ],
      ),
    );
  }
}

// --- Private messages ------------------------------------------------------------

/// A private chat with one friend, inside the tavern.
class DirectChatPanel extends StatelessWidget {
  const DirectChatPanel({
    super.key,
    required this.friend,
    required this.onClose,
    this.onBack,
  });

  final Profile friend;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return TavernPanel(
      title: friend.displayName,
      onClose: onClose,
      onBack: onBack,
      child: DirectChatView(friend: friend, compact: true),
    );
  }
}

// --- Bernie's bar --------------------------------------------------------------

/// Bernie's drinks menu, opened by tapping him. You order from the bar
/// itself: further away, the menu says to come closer.
class BarMenuPanel extends StatelessWidget {
  const BarMenuPanel({
    super.key,
    required this.atBar,
    required this.canOrder,
    required this.onOrder,
    required this.onClose,
  });

  /// Standing or sitting at the bar.
  final bool atBar;

  /// False for a moment after ordering, so drinks can't be spammed.
  final bool canOrder;
  final void Function(String drinkId) onOrder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TavernPanel(
      title: AppStrings.bernieName,
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        children: [
          Text(
            atBar ? AppStrings.bernieGreeting : AppStrings.bernieComeCloser,
            style: GoogleFonts.lora(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final drink in drinks)
            _DrinkTile(
              drink: drink,
              onOrder: atBar && canOrder ? () => onOrder(drink.id) : null,
            ),
        ],
      ),
    );
  }
}

class _DrinkTile extends StatelessWidget {
  const _DrinkTile({required this.drink, required this.onOrder});

  final Drink drink;
  final VoidCallback? onOrder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
            ),
            child: Image.asset(
              drink.asset,
              filterQuality: FilterQuality.none,
              semanticLabel: drink.name,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drink.name,
                  style: _body(size: 14, weight: FontWeight.w700),
                ),
                Text(drink.description, style: _muted(size: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.onInk,
                disabledBackgroundColor: AppColors.parchmentDim,
                disabledForegroundColor: AppColors.inkMuted,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: onOrder,
              child: Text(
                AppStrings.orderButton,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
