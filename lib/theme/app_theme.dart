import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day (parchment) or night mode, chosen from the Home menu and remembered
/// on this device.
class ThemeModeController {
  ThemeModeController._();

  static const String _key = 'night_mode';

  /// True while night mode is on. MaterialApp listens to this.
  static final ValueNotifier<bool> night = ValueNotifier<bool>(false);

  /// Reads the saved choice. Call before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      night.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      // No storage (e.g. private browsing): start in day mode.
    }
  }

  static Future<void> toggle() async {
    night.value = !night.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, night.value);
    } catch (_) {}
  }
}

/// Central place for colors and the overall Material theme.
/// Every color has a day and a night value; screens read them through these
/// getters, so switching modes recolors the whole app.
class AppColors {
  static bool get _night => ThemeModeController.night.value;

  /// Page background.
  static Color get parchment =>
      _night ? const Color(0xFF0F1424) : const Color(0xFFF5EFE0);
  static Color get parchmentDim =>
      _night ? const Color(0xFF2A3147) : const Color(0xFFDCD3BE);
  static Color get parchmentSoft =>
      _night ? const Color(0xFF1A2033) : const Color(0xFFE8DFC8);

  /// Main text and icons.
  static Color get ink =>
      _night ? const Color(0xFFF1E6CF) : const Color(0xFF1B1712);

  /// Text and icons drawn on an [ink]-filled surface (filled buttons).
  static Color get onInk => _night ? const Color(0xFF141A2B) : Colors.white;

  // Fantasy UI kit (matches the pixel-art frames and castle art).
  /// Lighter parchment inside framed cards and the bottom bar.
  static Color get card =>
      _night ? const Color(0xFF171D2E) : const Color(0xFFFBF7EC);

  /// Secondary text (6.7:1 on [card] by day, 8:1 by night).
  static Color get inkMuted =>
      _night ? const Color(0xFFBDB09A) : const Color(0xFF5E574C);

  /// Inactive bottom-bar tabs (4.6:1 on [card] by day, 5:1 by night).
  static Color get navMuted =>
      _night ? const Color(0xFF948A7C) : const Color(0xFF7A6E62);

  /// Warm brown of the frame art (gold by night), for rings and accents.
  static Color get frameBrown =>
      _night ? const Color(0xFFD4A86A) : const Color(0xFF6B4A2E);

  /// Background of the chosen character tile (its name is drawn in cream).
  static Color get selectedTile =>
      _night ? const Color(0xFF5A4426) : const Color(0xFF241A13);

  static Color get online =>
      _night ? const Color(0xFF4CC27A) : const Color(0xFF2E8B4E);

  /// Tint for painted scenes (castles, courtyards, the tavern) at night:
  /// darker and cooler, so lanterns still glow. Null by day.
  static ColorFilter? get sceneFilter => _night
      ? const ColorFilter.matrix([
          0.48, 0, 0, 0, 0, //
          0, 0.52, 0, 0, 2, //
          0, 0, 0.68, 0, 14, //
          0, 0, 0, 1, 0,
        ])
      : null;

  /// For thin dark-brown line art (dividers), which would vanish on the
  /// night background: drawn in gold instead. Null by day.
  static ColorFilter? get lineArtFilter =>
      _night ? ColorFilter.mode(frameBrown, BlendMode.srcIn) : null;
}

/// Applies [AppColors.sceneFilter] (or [AppColors.lineArtFilter] when
/// [lineArt] is true) to [child] at night; does nothing by day.
class NightTint extends StatelessWidget {
  const NightTint({super.key, required this.child, this.lineArt = false});

  final Widget child;
  final bool lineArt;

  @override
  Widget build(BuildContext context) {
    final filter = lineArt ? AppColors.lineArtFilter : AppColors.sceneFilter;
    return filter == null
        ? child
        : ColorFiltered(colorFilter: filter, child: child);
  }
}

class AppTheme {
  static ThemeData get theme {
    final night = ThemeModeController.night.value;
    return ThemeData(
      useMaterial3: true,
      brightness: night ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.parchment,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: night ? Brightness.dark : Brightness.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: night ? AppColors.parchmentSoft : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
}
