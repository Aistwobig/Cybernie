import 'dart:ui';
 
import 'package:flutter/material.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
 
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
 
  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goToLogin(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image with a slight blur for a softer, faded look.
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Image.asset(
                AppImages.splashBg,
                fit: BoxFit.cover,
              ),
            ),
 
            // Dark gradient fade on top of the blur so text stays legible.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
 
            Align(
              alignment: const Alignment(0, -0.15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppImages.logo,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(AppStrings.appName, style: CyberniStyles.title),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _OrnamentDash(),
                      const SizedBox(width: 8),
                      Text(AppStrings.tagline, style: CyberniStyles.subtitle),
                      const SizedBox(width: 8),
                      const _OrnamentDash(),
                    ],
                  ),
                ],
              ),
            ),
 
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: _TapToContinue(
                  onTap: () => _goToLogin(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
/// The "TAP TO CONTINUE" prompt as its own interactive widget.
/// On hover (web/desktop with a mouse), it lifts up, brightens to white,
/// and widens its letter spacing, with a pointer cursor.
class _TapToContinue extends StatefulWidget {
  const _TapToContinue({required this.onTap});
 
  final VoidCallback onTap;
 
  @override
  State<_TapToContinue> createState() => _TapToContinueState();
}
 
class _TapToContinueState extends State<_TapToContinue> {
  bool _hovering = false;
 
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        debugPrint('CTA hover: entered');
        setState(() => _hovering = true);
      },
      onExit: (_) {
        debugPrint('CTA hover: exited');
        setState(() => _hovering = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -6 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: CyberniStyles.cta.copyWith(
              color: _hovering ? Colors.white : AppColors.parchmentSoft,
              letterSpacing: _hovering ? 4 : 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_outlined,
                    size: 9,
                    color: _hovering ? Colors.white : AppColors.parchmentSoft),
                const SizedBox(width: 10),
                Text(AppStrings.tapToContinue),
                const SizedBox(width: 10),
                Icon(Icons.diamond_outlined,
                    size: 9,
                    color: _hovering ? Colors.white : AppColors.parchmentSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 
class _OrnamentDash extends StatelessWidget {
  const _OrnamentDash();
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 1,
      color: AppColors.parchmentDim,
    );
  }
}