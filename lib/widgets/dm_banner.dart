import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../constants/emotes.dart';
import '../services/dm_notifier.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';

/// Wraps the whole app: when a private message arrives, a banner slides
/// down from the top with who sent it and what they said. Tap it to open
/// the conversation; it hides itself after a few seconds.
class DmBannerHost extends StatefulWidget {
  const DmBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<DmBannerHost> createState() => _DmBannerHostState();
}

class _DmBannerHostState extends State<DmBannerHost> {
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    DmNotifier.alert.addListener(_onAlert);
  }

  @override
  void dispose() {
    DmNotifier.alert.removeListener(_onAlert);
    _hide?.cancel();
    super.dispose();
  }

  void _onAlert() {
    _hide?.cancel();
    if (DmNotifier.alert.value != null) {
      _hide = Timer(const Duration(seconds: 5), DmNotifier.dismiss);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final alert = DmNotifier.alert.value;
    final top = MediaQuery.paddingOf(context).top + 10;
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          top: alert == null ? -120 : top,
          left: 0,
          right: 0,
          child: Center(
            child: alert == null
                ? const SizedBox.shrink()
                : _Banner(alert: alert),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.alert});

  final DmAlert alert;

  @override
  Widget build(BuildContext context) {
    final message = alert.message;
    final emote = message.emote == null ? null : emoteById(message.emote!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            liveRegion: true,
            label: AppStrings.dmBannerLabel(alert.from.displayName),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                DmNotifier.dismiss();
                DmNotifier.open(alert.from);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(
                  color: const Color(0xF22A1A10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFB8742E),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    PlayerAvatar(photoUrl: alert.from.avatarUrl, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble,
                                size: 13,
                                color: Color(0xFFFFD027),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  alert.from.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFF5E6C8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (message.isEmote)
                            Row(
                              children: [
                                if (emote != null) ...[
                                  Image.asset(emote.asset, height: 20),
                                  const SizedBox(width: 6),
                                ],
                                Text(AppStrings.dmBannerEmote, style: _preview),
                              ],
                            )
                          else
                            Text(
                              message.body ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _preview,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.closeButton,
                      onPressed: DmNotifier.dismiss,
                      icon: const Icon(Icons.close, size: 18),
                      color: const Color(0xCCF5E6C8),
                      visualDensity: VisualDensity.compact,
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

  static final TextStyle _preview = GoogleFonts.inter(
    fontSize: 13,
    height: 1.25,
    color: const Color(0xDDF5E6C8),
  );
}

/// The unread private message count on a button, e.g. Friends.
class DmUnreadBadge extends StatelessWidget {
  const DmUnreadBadge({super.key, required this.child, this.friendId});

  final Widget child;

  /// Only this friend's messages (null: everyone's).
  final String? friendId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: DmNotifier.unread,
      builder: (context, unread, _) {
        final count = friendId == null
            ? unread.values.fold(0, (a, b) => a + b)
            : unread[friendId] ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                top: -4,
                right: -6,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9412F),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.card, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
