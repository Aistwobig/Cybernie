import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// "Select Room" screen, opened from the JOIN ROOM button on the welcome
/// screen. Lists the available rooms (just Bernie's Tavern for now) plus a
/// dashed "coming soon" placeholder for future rooms.
class SelectRoomScreen extends StatelessWidget {
  const SelectRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _RoomCard(
                    imagePath: AppImages.tavernRoom,
                    name: AppStrings.tavernRoomName,
                    details: AppStrings.tavernRoomDetails,
                    onJoin: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AppStrings.joiningTavern),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _ComingSoonTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                navigator.pushReplacementNamed('/welcome');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 22),
            color: AppColors.ink,
          ),
          const SizedBox(width: 2),
          Text(
            AppStrings.selectRoomTitle,
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
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.imagePath,
    required this.name,
    required this.details,
    required this.onJoin,
  });

  final String imagePath;
  final String name;
  final String details;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.parchment,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.ink.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room thumbnail with its own thin frame and corner marks.
              Stack(
                children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: AppColors.ink.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.asset(imagePath, fit: BoxFit.cover),
                    ),
                  ),
                  ..._cornerBrackets(
                    inset: 2,
                    size: 6,
                    stroke: 1.2,
                    color: AppColors.parchment.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: GoogleFonts.lora(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: onJoin,
                  child: Text(
                    AppStrings.joinButton,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Dark ornamental brackets sitting on the card's outer corners.
        ..._cornerBrackets(
          inset: -1,
          size: 9,
          stroke: 2,
          color: AppColors.ink,
        ),
      ],
    );
  }
}

/// Four 'L' shaped brackets, one per corner of the enclosing [Stack].
List<Widget> _cornerBrackets({
  required double inset,
  required double size,
  required double stroke,
  required Color color,
}) {
  Widget bracket({bool top = false, bool left = false}) {
    final side = BorderSide(color: color, width: stroke);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
        ),
      ),
    );
  }

  return [
    Positioned(top: inset, left: inset, child: bracket(top: true, left: true)),
    Positioned(top: inset, right: inset, child: bracket(top: true)),
    Positioned(bottom: inset, left: inset, child: bracket(left: true)),
    Positioned(bottom: inset, right: inset, child: bracket()),
  ];
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: SizedBox(
        height: 96,
        child: Center(
          child: Text(
            AppStrings.moreRoomsComingSoon,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );

    for (final metric in border.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 5 < metric.length ? distance + 5 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
