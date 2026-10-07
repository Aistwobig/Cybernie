import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared text styles for the CYBERNIE brand. They sit on the dark splash
/// photo, so they keep their light parchment colours in night mode too.
/// Import this anywhere you need the title/subtitle/CTA look,
/// instead of redefining styles per screen.
class CyberniStyles {
  static const Color brandLight = Color(0xFFF5EFE0);
  static const Color brandDim = Color(0xFFDCD3BE);
  static const Color brandSoft = Color(0xFFE8DFC8);

  static TextStyle get title => GoogleFonts.cinzel(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: brandLight,
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
    color: brandDim,
    letterSpacing: 3,
  );

  static TextStyle get cta => GoogleFonts.cinzel(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: brandSoft,
    letterSpacing: 3,
  );
}
