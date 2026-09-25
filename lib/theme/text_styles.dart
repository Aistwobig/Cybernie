import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Shared text styles for the CYBERNIE brand.
/// Import this anywhere you need the title/subtitle/CTA look,
/// instead of redefining styles per screen.
class CyberniStyles {
  static TextStyle get title => GoogleFonts.cinzel(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.parchment,
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.6),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      );

  static TextStyle get subtitle => GoogleFonts.cinzel(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.parchmentDim,
        letterSpacing: 3,
      );

  static TextStyle get cta => GoogleFonts.cinzel(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.parchmentSoft,
        letterSpacing: 3,
      );
}
