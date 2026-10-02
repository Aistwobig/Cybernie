import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/corner_framed_box.dart';

/// Sign in and register both go through Google. A new player's account and
/// profile are created on their first Google sign-in, so "Register" just
/// opens the same Google flow.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      _authSubscription = AuthService.authChanges.listen((state) {
        if (state.event == AuthChangeEvent.signedIn && mounted) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      // On web the page navigates away to Google here; the app reloads
      // signed in when Google sends the player back.
      await AuthService.signInWithGoogle();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.googleSignInError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  TextStyle get _titleStyle => GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: 2,
      );

  TextStyle get _subtitleStyle => GoogleFonts.cinzel(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.text.withValues(alpha: 0.7),
        letterSpacing: 2,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: CornerFramedBox(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            AppColors.text,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            AppImages.logo,
                            width: 28,
                            height: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(AppStrings.appName, style: _titleStyle),
                        const SizedBox(height: 4),
                        Text(AppStrings.tagline, style: _subtitleStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    AppStrings.signInPrompt,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.text.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _isSigningIn ? null : _continueWithGoogle,
                      child: _isSigningIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _GoogleBadge(),
                                const SizedBox(width: 10),
                                Text(
                                  AppStrings.signInWithGoogle,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: AppColors.onAccent,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.text.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.text.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      AppStrings.safetyNote,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.text.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      AppStrings.noAccountPrompt,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.text),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _isSigningIn ? null : _continueWithGoogle,
                      child: Text(
                        AppStrings.registerWithGoogle,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small white circle with a "G", marking the button as Google sign-in.
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.onAccent,
          height: 1,
        ),
      ),
    );
  }
}
