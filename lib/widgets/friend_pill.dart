import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Where a player stands with you, as the small pill on a player row.
enum FriendPillState { add, requested, friends }

/// The friend button on player rows, as on the landing page: a gold "Add"
/// pill that, once tapped, presses in and becomes a soft "Requested ✓";
/// friends get a green "Friends ✓". At night the colours are exactly the
/// landing page's; by day the soft ones use the day ink instead.
class FriendPill extends StatefulWidget {
  const FriendPill({
    super.key,
    required this.state,
    this.onAdd,
    this.busy = false,
  });

  final FriendPillState state;

  /// Sends the request (only for [FriendPillState.add]).
  final VoidCallback? onAdd;

  /// The request is on its way: shown pressed in.
  final bool busy;

  @override
  State<FriendPill> createState() => _FriendPillState();
}

class _FriendPillState extends State<FriendPill> {
  bool _pressed = false;

  static const Color _gold = Color(0xFFFFD027);
  static const Color _goldInk = Color(0xFF2A1408);

  bool get _night => ThemeModeController.night.value;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state == FriendPillState.friends) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          AppStrings.friendsPill,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _night ? const Color(0xFF7BE38C) : const Color(0xFF2E8B3E),
          ),
        ),
      );
    }

    final add = state == FriendPillState.add;
    final Color bg = add
        ? _gold
        : (_night
              ? const Color(0x2EF5E6C8)
              : AppColors.ink.withValues(alpha: 0.1));
    final Color fg = add
        ? _goldInk
        : (_night ? const Color(0xFFF5E6C8) : AppColors.ink);
    final canTap = add && !widget.busy && widget.onAdd != null;

    return Semantics(
      button: add,
      label: add ? AppStrings.addFriendButton : AppStrings.requestedPill,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
        onTapUp: canTap
            ? (_) {
                setState(() => _pressed = false);
                widget.onAdd!();
              }
            : null,
        child: MouseRegion(
          cursor: canTap ? SystemMouseCursors.click : MouseCursor.defer,
          child: AnimatedScale(
            // Presses in when tapped, and sits slightly smaller once sent.
            scale: _pressed || widget.busy ? 0.88 : (add ? 1 : 0.96),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  add ? AppStrings.addPill : AppStrings.requestedPill,
                  key: ValueKey(add),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
