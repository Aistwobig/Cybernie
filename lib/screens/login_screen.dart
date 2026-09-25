import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  // Text styles specific to this screen (dark ink on a light background,
  // unlike the splash screen's light-on-dark CyberniStyles).
  TextStyle get _titleStyle => GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 2,
      );

  TextStyle get _subtitleStyle => GoogleFonts.cinzel(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.ink.withValues(alpha: 0.7),
        letterSpacing: 2,
      );

  TextStyle get _fieldLabelStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.ink.withValues(alpha: 0.7),
        letterSpacing: 1,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _CornerFramedBox(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + title block
                  Center(
                    child: Column(
                      children: [
                        Image.asset(AppImages.logo, width: 28, height: 28),
                        const SizedBox(height: 10),
                        Text(AppStrings.appName, style: _titleStyle),
                        const SizedBox(height: 4),
                        Text(AppStrings.tagline, style: _subtitleStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Username
                  Text(AppStrings.usernameLabel, style: _fieldLabelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.usernameHint,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  Text(AppStrings.passwordLabel, style: _fieldLabelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: AppStrings.passwordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.ink.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Log in button
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        // TODO: wire up real authentication once the backend
                        // exists. For now this is just a placeholder tap.
                      },
                      child: Text(
                        AppStrings.logInButton,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Safety note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.ink.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      AppStrings.safetyNote,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.ink.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Register prompt
                  Center(
                    child: Text(
                      AppStrings.noAccountPrompt,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.ink),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.register);
                      },
                      child: Text(
                        AppStrings.registerButton,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.ink,
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

/// Draws a thin rounded border around [child], with a small ornamental
/// corner mark at each corner — an approximation of the dashed-frame look
/// in the mockup using plain widgets (no extra packages).
class _CornerFramedBox extends StatelessWidget {
  const _CornerFramedBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.ink.withValues(alpha: 0.25),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
        const Positioned(top: 10, left: 10, child: _CornerMark()),
        const Positioned(
          top: 10,
          right: 10,
          child: _CornerMark(),
        ),
        const Positioned(bottom: 10, left: 10, child: _CornerMark()),
        const Positioned(bottom: 10, right: 10, child: _CornerMark()),
      ],
    );
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.add,
      size: 12,
      color: AppColors.ink.withValues(alpha: 0.3),
    );
  }
}
