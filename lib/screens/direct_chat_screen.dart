import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../utils/last_seen.dart';
import '../widgets/direct_chat_view.dart';
import '../widgets/player_avatar.dart';

/// A private chat with one friend, opened from the Friends screen.
class DirectChatScreen extends StatelessWidget {
  const DirectChatScreen({super.key, required this.friend});

  final Profile friend;

  /// Opens the chat with [friend] on top of the current screen.
  static Future<void> open(BuildContext context, Profile friend) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DirectChatScreen(friend: friend),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final online = friend.isOnline();

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: AppStrings.backButton,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 22),
                    color: AppColors.ink,
                  ),
                  PlayerAvatar(
                    photoUrl: friend.avatarUrl,
                    radius: 20,
                    isOnline: online,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            friend.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          lastSeenLabel(friend),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: online
                                ? AppColors.online
                                : AppColors.ink.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
            Expanded(child: DirectChatView(friend: friend)),
          ],
        ),
      ),
    );
  }
}
