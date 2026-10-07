import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/profile_link.dart';
import 'fantasy_ui.dart';

/// Shows a QR code of the player's profile link. Scanning it with any
/// phone camera opens the app on their profile, where others can add them.
class ProfileQrDialog extends StatelessWidget {
  const ProfileQrDialog({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  final String playerId;
  final String playerName;

  static Future<void> show(
    BuildContext context, {
    required String playerId,
    required String playerName,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ProfileQrDialog(playerId: playerId, playerName: playerName),
  );

  @override
  Widget build(BuildContext context) {
    final link = ProfileLink.url(playerId);
    return Dialog(
      backgroundColor: AppColors.parchment,
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.qrTitle, style: FantasyText.name(size: 20)),
            const SizedBox(height: 4),
            Text(
              playerName,
              style: FantasyText.mono(size: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 14),
            // White behind the code, so any camera can read it (night mode
            // included).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.frameBrown, width: 2),
              ),
              child: Semantics(
                image: true,
                label: AppStrings.qrTitle,
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF2A1408),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF2A1408),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.qrHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.linkCopied)),
                      );
                    }
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text(AppStrings.copyLinkButton),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                  child: const Text(AppStrings.closeButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
