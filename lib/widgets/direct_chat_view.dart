import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_strings.dart';
import '../constants/emotes.dart';
import '../models/profile.dart';
import '../services/direct_message_service.dart';
import '../theme/app_theme.dart';

/// A private conversation with [friend]: the messages, newest at the bottom,
/// and a box to write text or send one of the game's emotes.
///
/// Tap one of your own messages to edit (text only) or delete it.
///
/// Used full screen from Friends and inside a tavern panel ([compact]).
class DirectChatView extends StatefulWidget {
  const DirectChatView({super.key, required this.friend, this.compact = false});

  final Profile friend;

  /// Smaller spacing and emotes, for the tavern's side panel.
  final bool compact;

  @override
  State<DirectChatView> createState() => _DirectChatViewState();
}

class _DirectChatViewState extends State<DirectChatView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<DirectMessage> _messages = [];
  DirectMessageFeed? _feed;

  bool _loading = true;
  String? _loadError;
  bool _sending = false;
  bool _emotesOpen = false;

  /// One of our messages that was tapped, showing Edit / Delete.
  int? _selectedId;

  /// The message being edited, if any; sending then saves the edit.
  DirectMessage? _editing;

  String get _friendId => widget.friend.id;

  @override
  void initState() {
    super.initState();
    _feed = DirectMessageService.listen(
      onNew: (m) {
        if (m.senderId == _friendId) _put(m);
      },
      onEdited: (m) {
        if (m.isWith(_friendId)) _put(m);
      },
      onDeleted: _drop,
    );
    _load();
  }

  @override
  void dispose() {
    _feed?.close();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await DirectMessageService.fetchConversation(_friendId);
      if (!mounted) return;
      setState(() {
        // Keep anything that arrived live while loading.
        final known = {for (final m in messages) m.id};
        _messages
          ..removeWhere((m) => known.contains(m.id))
          ..insertAll(0, messages);
        _sortMessages();
        _loading = false;
        _loadError = null;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      // 42P01 / PGRST205: the direct_messages table hasn't been created.
      final missing = error.code == '42P01' || error.code == 'PGRST205';
      setState(() {
        _loading = false;
        _loadError = missing ? AppStrings.dmNotSetUp : AppStrings.dmLoadError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppStrings.dmLoadError;
      });
    }
  }

  void _sortMessages() =>
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Adds [message], or replaces it if we already have it (an edit).
  void _put(DirectMessage message) {
    if (!mounted) return;
    setState(() {
      final i = _messages.indexWhere((m) => m.id == message.id);
      if (i >= 0) {
        _messages[i] = message;
      } else {
        _messages.add(message);
        _sortMessages();
      }
    });
  }

  void _drop(int id) {
    if (!mounted || !_messages.any((m) => m.id == id)) return;
    setState(() {
      _messages.removeWhere((m) => m.id == id);
      if (_selectedId == id) _selectedId = null;
      if (_editing?.id == id) _stopEditing();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await action();
    } catch (_) {
      _showSnack(AppStrings.dmSendError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final editing = _editing;
    await _run(() async {
      if (editing != null) {
        if (text != editing.body) {
          _put(await DirectMessageService.edit(editing.id, text));
        }
        if (mounted) setState(_stopEditing);
      } else {
        _put(await DirectMessageService.sendText(_friendId, text));
      }
      _controller.clear();
    });
  }

  Future<void> _sendEmote(Emote emote) => _run(() async {
    _put(await DirectMessageService.sendEmote(_friendId, emote.id));
    if (mounted) setState(() => _emotesOpen = false);
  });

  void _startEditing(DirectMessage message) {
    setState(() {
      _editing = message;
      _selectedId = null;
      _emotesOpen = false;
      _controller.text = message.body ?? '';
    });
    _inputFocus.requestFocus();
  }

  void _stopEditing() {
    _editing = null;
    _controller.clear();
  }

  Future<void> _delete(DirectMessage message) async {
    setState(() => _selectedId = null);
    try {
      await DirectMessageService.delete(message.id);
      _drop(message.id);
    } catch (_) {
      _showSnack(AppStrings.dmDeleteError);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 10.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildMessages(pad)),
        if (_editing != null)
          _EditingBar(onCancel: () => setState(_stopEditing)),
        if (_emotesOpen)
          _EmoteRow(
            compact: widget.compact,
            enabled: !_sending,
            onPick: _sendEmote,
          ),
        _Composer(
          controller: _controller,
          focusNode: _inputFocus,
          hint: AppStrings.dmHint(widget.friend.displayName),
          sending: _sending,
          editing: _editing != null,
          emotesOpen: _emotesOpen,
          compact: widget.compact,
          onToggleEmotes: () => setState(() {
            _emotesOpen = !_emotesOpen;
            if (_emotesOpen) _editing = null;
          }),
          onSend: _sendText,
        ),
      ],
    );
  }

  Widget _buildMessages(double pad) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ink,
          ),
        ),
      );
    }
    final error = _loadError;
    if (error != null) {
      return _Note(
        text: error,
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    if (_messages.isEmpty) {
      return _Note(text: AppStrings.dmEmpty(widget.friend.displayName));
    }

    final me = DirectMessageService.myId;
    // Reversed so the list starts at the newest message.
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.fromLTRB(pad, 10, pad, 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final mine = message.senderId == me;
        return _MessageTile(
          message: message,
          mine: mine,
          compact: widget.compact,
          selected: _selectedId == message.id,
          onTap: mine
              ? () => setState(() {
                  _selectedId = _selectedId == message.id ? null : message.id;
                })
              : null,
          onEdit: () => _startEditing(message),
          onDelete: () => _delete(message),
        );
      },
    );
  }
}

/// One message: a bubble (ours on the right, theirs on the left) or an
/// emote picture, with the time and an "edited" mark underneath.
class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.mine,
    required this.compact,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final DirectMessage message;
  final bool mine;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final emote = message.isEmote ? emoteById(message.emote!) : null;
    final maxWidth = compact ? 210.0 : 280.0;

    final Widget content;
    if (message.isEmote) {
      final size = compact ? 52.0 : 72.0;
      content = emote == null
          ? Text(message.emote!, style: TextStyle(fontSize: size * 0.6))
          : Semantics(
              label: emote.label,
              image: true,
              child: Image.asset(
                emote.asset,
                width: size,
                height: size,
                filterQuality: FilterQuality.medium,
              ),
            );
    } else {
      content = Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 3),
            bottomRight: Radius.circular(mine ? 3 : 12),
          ),
          border: mine
              ? null
              : Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.frameBrown.withValues(alpha: 0.6),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          message.body ?? '',
          style: GoogleFonts.inter(
            fontSize: compact ? 13 : 14.5,
            height: 1.35,
            color: mine ? AppColors.onInk : AppColors.ink,
          ),
        ),
      );
    }

    final meta = [
      _timeLabel(message.createdAt),
      if (message.editedAt != null) AppStrings.dmEdited,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Semantics(
            button: onTap != null,
            hint: onTap != null ? AppStrings.dmMessageActionsHint : null,
            child: GestureDetector(onTap: onTap, child: content),
          ),
          const SizedBox(height: 3),
          Text(
            meta,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isEmote)
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      label: AppStrings.dmEdit,
                      onTap: onEdit,
                    ),
                  const SizedBox(width: 6),
                  _ActionChip(
                    icon: Icons.delete_outline,
                    label: AppStrings.dmDelete,
                    color: const Color(0xFFB3261E),
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "14:05" today, "Oct 3, 14:05" before that.
  static String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final today =
        time.year == now.year && time.month == now.month && time.day == now.day;
    if (today) return hhmm;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}, $hhmm';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.ink;
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: fg.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Editing message" with a cancel button, above the text box.
class _EditingBar extends StatelessWidget {
  const _EditingBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      color: AppColors.parchmentDim.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 15, color: AppColors.ink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppStrings.dmEditing,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.cancelButton,
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.ink,
          ),
        ],
      ),
    );
  }
}

/// The game's emotes; tapping one sends it.
class _EmoteRow extends StatelessWidget {
  const _EmoteRow({
    required this.compact,
    required this.enabled,
    required this.onPick,
  });

  final bool compact;
  final bool enabled;
  final void Function(Emote emote) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.ink.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emote in emotes)
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 40 : 52),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Tooltip(
                    message: emote.label,
                    child: Semantics(
                      button: true,
                      label: emote.label,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: enabled ? () => onPick(emote) : null,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sending,
    required this.editing,
    required this.emotesOpen,
    required this.compact,
    required this.onToggleEmotes,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool sending;
  final bool editing;
  final bool emotesOpen;
  final bool compact;
  final VoidCallback onToggleEmotes;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, 6, compact ? 6 : 10, compact ? 6 : 10),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        border: Border(
          top: BorderSide(color: AppColors.ink.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: AppStrings.emotesButton,
            isSelected: emotesOpen,
            onPressed: editing ? null : onToggleEmotes,
            icon: const Icon(Icons.emoji_emotions_outlined),
            selectedIcon: const Icon(Icons.emoji_emotions),
            color: AppColors.ink,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: DirectMessageService.maxLength,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
              onPressed: sending ? null : onSend,
              child: sending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onInk,
                      ),
                    )
                  : Icon(
                      editing ? Icons.check : Icons.send,
                      size: 18,
                      color: AppColors.onInk,
                      semanticLabel: editing
                          ? AppStrings.dmSaveEdit
                          : AppStrings.dmSend,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred line of text in the message area, with an optional retry.
class _Note extends StatelessWidget {
  const _Note({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.6),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  AppStrings.retryButton,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
