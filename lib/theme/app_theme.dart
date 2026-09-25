import 'package:flutter/material.dart';

/// Central place for colors and the overall Material theme.
/// Change the seed color here and every screen updates with it.
class AppColors {
  static const parchment = Color(0xFFF5EFE0);
  static const parchmentDim = Color(0xFFDCD3BE);
  static const parchmentSoft = Color(0xFFE8DFC8);
  static const ink = Color(0xFF1B1712);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
      );
}
