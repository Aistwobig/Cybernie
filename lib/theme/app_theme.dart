import 'package:flutter/material.dart';

/// Central place for colors and the overall Material theme.
///
/// The palette comes from the splash screen's tavern art: near-black warm
/// shadows, candle-lit cream text and orange lantern glow.
class AppColors {
  // --- Tavern palette (used by every screen) -------------------------------
  static const background = Color(0xFF1A1310); // tavern shadows
  static const surface = Color(0xFF2A1E18); // cards, panels, fields
  static const surfaceRaised = Color(0xFF3A2A21); // placeholders, chips
  static const text = Color(0xFFF2E6D0); // candle-lit parchment
  static const textMuted = Color(0xFFC9B79A);
  static const accent = Color(0xFFE8822A); // lantern glow
  static const onAccent = Color(0xFF1A1310); // text on accent buttons
  static const danger = Color(0xFFC0473B); // red tavern banners
  static const online = Color(0xFF5BD68A);

  /// Thin gold-brown lines: borders and dividers.
  static Color get border => accent.withValues(alpha: 0.28);

  // --- Splash text colors (CyberniStyles) ----------------------------------
  static const parchment = Color(0xFFF5EFE0);
  static const parchmentDim = Color(0xFFDCD3BE);
  static const parchmentSoft = Color(0xFFE8DFC8);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.35),
      selectionHandleColor: AppColors.accent,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.4)),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
  );
}
