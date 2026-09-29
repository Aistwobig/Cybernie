import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/corner_framed_box.dart';
import '../widgets/sprite_walk_preview.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _navIndex = 0;

  Future<void> _onNavTap(int index) async {
    if (index == _navIndex) return;

    if (index == 1) {
      // Friends tab: navigate to the Friends screen, then reset the nav
      // highlight back to Home once the user returns here.
      setState(() => _navIndex = 1);
      await Navigator.of(context).pushNamed('/friends');
      if (mounted) setState(() => _navIndex = 0);
      return;
    }

    if (index == 2) {
      setState(() => _navIndex = index);
      await Navigator.of(context).pushNamed('/profile');
      if (mounted) setState(() => _navIndex = 0);
      return;
    }

    // Home (0)
    setState(() => _navIndex = index);
  }

  TextStyle get _greetingStyle => GoogleFonts.cinzel(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  TextStyle get _fieldLabelStyle => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: AppColors.ink.withValues(alpha: 0.5),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false, // Handled manually in our custom bottom nav
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Top bar: greeting + menu icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.welcomeGreeting, style: _greetingStyle),
                  const Icon(Icons.menu, color: AppColors.ink, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Top continuous ornamental divider
            const _OrnamentalDivider(isTop: true),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // "CHARACTER PREVIEW" label
                    Center(
                      child: Text(
                        AppStrings.characterPreviewLabel,
                        style: _fieldLabelStyle,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Framed character preview box (Forced 1:1 Square)
                    const Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: CornerFramedBox(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: _CharacterBoxContent(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Join room button
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/rooms'),
                        child: Text(
                          AppStrings.joinRoomButton,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Custom Bottom Navigation Bar
            _buildCustomBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    final dividerColor = AppColors.ink.withValues(alpha: 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bottom divider with upward-pointing notches
        const _OrnamentalDivider(isTop: false),

        Container(
          color: AppColors.parchment,
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 0 ? Icons.home : Icons.home_outlined,
                  label: AppStrings.navHome,
                  isActive: _navIndex == 0,
                  onTap: () => _onNavTap(0),
                ),
              ),
              // Vertical Divider 1
              Container(width: 1, height: 32, color: dividerColor),
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 1 ? Icons.people : Icons.people_outline,
                  label: AppStrings.navFriends,
                  isActive: _navIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
              ),
              // Vertical Divider 2
              Container(width: 1, height: 32, color: dividerColor),
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 2 ? Icons.person : Icons.person_outline,
                  label: AppStrings.navProfile,
                  isActive: _navIndex == 2,
                  onTap: () => _onNavTap(2),
                ),
              ),
            ],
          ),
        ),
        // Ensures the bottom nav isn't blocked by the iOS swipe indicator
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

class _CharacterBoxContent extends StatelessWidget {
  const _CharacterBoxContent();

  @override
  Widget build(BuildContext context) {
    // Animated walk-cycle sprite sheet, replacing the old static
    // AppImages.characterMen. Cycles South -> West -> Back -> East -> South.
    return const SizedBox.expand(
      child: SpriteWalkPreview(assetPath: AppImages.characterMenAnim),
    );
  }
}

/// Custom Bottom Nav Tab Item
class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.ink
        : AppColors.ink.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom painted horizontal line that draws the small, continuous
/// bracket details at the edges precisely matching the mockup.
class _OrnamentalDivider extends StatelessWidget {
  final bool isTop;
  const _OrnamentalDivider({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      width: double.infinity,
      child: CustomPaint(
        painter: _DividerPainter(
          isTop: isTop,
          color: AppColors.ink.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  final bool isTop;
  final Color color;

  _DividerPainter({required this.isTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // If it's the top divider, the line sits at the top (0) and notches go down.
    // If it's the bottom divider, the line sits at the bottom and notches go up.
    final double y = isTop ? 0.0 : size.height;
    final double notchDir = isTop ? 1.0 : -1.0;

    const double notchHeight = 6.0;
    const double notchWidth = 8.0;
    const double margin = 24.0;

    final path = Path();

    path.moveTo(0, y);
    // Draw left flat line
    path.lineTo(margin, y);
    // Draw left notch
    path.lineTo(margin, y + (notchHeight * notchDir));
    path.lineTo(margin + notchWidth, y + (notchHeight * notchDir));
    path.lineTo(margin + notchWidth, y);
    // Draw middle flat line
    path.lineTo(size.width - margin - notchWidth, y);
    // Draw right notch
    path.lineTo(size.width - margin - notchWidth, y + (notchHeight * notchDir));
    path.lineTo(size.width - margin, y + (notchHeight * notchDir));
    path.lineTo(size.width - margin, y);
    // Draw right flat line
    path.lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
