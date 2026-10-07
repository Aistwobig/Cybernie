import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _auth;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // The saved session can finish restoring (or renewing) just after this
    // screen opened: then go straight in, no sign-in needed.
    if (SupabaseConfig.isConfigured) {
      try {
        _auth = AuthService.authChanges.listen((state) {
          if (state.session != null) _go('/welcome');
        });
      } catch (_) {
        // Supabase isn't started (e.g. in tests): nothing to listen to.
      }
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  void _go(String route) {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _goToLogin(BuildContext context) {
    // Already signed in (or just returned from Google): skip the login screen.
    _go(AuthService.isSignedIn ? '/welcome' : '/login');
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
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Image.asset(AppImages.splashBg, fit: BoxFit.cover),
            ),
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
                  Image.asset(AppImages.logo, width: 40, height: 40),
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
                child: _TapToContinue(onTap: () => _goToLogin(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
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
                Icon(
                  Icons.diamond_outlined,
                  size: 9,
                  color: _hovering ? Colors.white : AppColors.parchmentSoft,
                ),
                const SizedBox(width: 10),
                Text(AppStrings.tapToContinue),
                const SizedBox(width: 10),
                Icon(
                  Icons.diamond_outlined,
                  size: 9,
                  color: _hovering ? Colors.white : AppColors.parchmentSoft,
                ),
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
    return Container(width: 18, height: 1, color: AppColors.parchmentDim);
  }
}
