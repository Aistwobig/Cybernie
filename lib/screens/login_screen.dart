import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/corner_framed_box.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

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
                            AppColors.ink,
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
                  const SizedBox(height: 32),
                  Text(AppStrings.usernameLabel, style: _fieldLabelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.usernameHint,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        // No real auth backend yet — for now, logging in just
                        // takes you to the Welcome screen.
                        Navigator.of(context).pushReplacementNamed('/welcome');
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
                        Navigator.of(context).pushReplacementNamed('/register');
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