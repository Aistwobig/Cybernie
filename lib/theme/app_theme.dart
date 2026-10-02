import 'package:flutter/material.dart';

/// Central place for colors and the overall Material theme.
/// Change the seed color here and every screen updates with it.
class AppColors {
  static const parchment = Color(0xFFF5EFE0);
  static const parchmentDim = Color(0xFFDCD3BE);
  static const parchmentSoft = Color(0xFFE8DFC8);
  static const ink = Color(0xFF1B1712);

  // Fantasy UI kit (matches the pixel-art frames and castle art).
  /// Lighter parchment inside framed cards and the bottom bar.
  static const card = Color(0xFFFBF7EC);

  /// Secondary text (6.7:1 on [card]).
  static const inkMuted = Color(0xFF5E574C);

  /// Inactive bottom-bar tabs (4.6:1 on [card]).
  static const navMuted = Color(0xFF7A6E62);

  /// Warm brown of the frame art, for rings and small accents.
  static const frameBrown = Color(0xFF6B4A2E);

  static const online = Color(0xFF2E8B4E);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.35)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.6)),
          ),
        ),
      );
}