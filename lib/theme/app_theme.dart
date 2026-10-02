import 'package:flutter/material.dart';

/// Central place for colors and the overall Material theme.
///
/// Parchment and ink carry every screen. Ember, the candle glow from the
/// tavern art, is the one warm accent: it marks the way into the tavern and
/// live "who's here" signals, and nothing decorative.
class AppColors {
  static const parchment = Color(0xFFF5EFE0);
  static const parchmentDim = Color(0xFFDCD3BE);
  static const parchmentSoft = Color(0xFFE8DFC8);
  static const ink = Color(0xFF1B1712);

  /// Secondary text and inactive icons. 6.2:1 on parchment, so it stays
  /// readable at small sizes (faded ink at 40-50% alpha fell to ~2.5:1).
  static const inkMuted = Color(0xFF5E574C);

  /// Candle glow. A fill only, with ink text on it (6.5:1). It is 2.4:1
  /// against parchment, so ember surfaces carry an ink outline.
  static const ember = Color(0xFFE0873A);

  /// Ember for text and small marks on parchment (5.4:1).
  static const emberText = Color(0xFF9A4A12);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ember,
      primary: AppColors.ink,
      onPrimary: AppColors.parchment,
      secondary: AppColors.emberText,
      surface: AppColors.parchment,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
    ),
    // Keyboard focus and text selection follow the palette instead of
    // Material's default purple.
    focusColor: AppColors.ember.withValues(alpha: 0.35),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.ink,
      selectionColor: AppColors.ember.withValues(alpha: 0.35),
      selectionHandleColor: AppColors.emberText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
