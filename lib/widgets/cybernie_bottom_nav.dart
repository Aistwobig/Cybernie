import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';

/// The Home / Friends / Profile tab bar, shared by all three tab screens so
/// it never shifts size or style when switching tabs.
class CybernieBottomNav extends StatelessWidget {
  const CybernieBottomNav({super.key, required this.currentIndex});

  /// 0 = Home, 1 = Friends, 2 = Profile.
  final int currentIndex;

  static const double _height = 60;

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        AppNav.goHome(context);
      case 1:
        AppNav.goToTab(context, '/friends');
      case 2:
        AppNav.goToTab(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.home_outlined, Icons.home, AppStrings.navHome),
      (Icons.people_outline, Icons.people, AppStrings.navFriends),
      (Icons.person_outline, Icons.person, AppStrings.navProfile),
    ];

    return Material(
      color: AppColors.parchment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
          SizedBox(
            height: _height,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _Tab(
                      icon: i == currentIndex ? tabs[i].$2 : tabs[i].$1,
                      label: tabs[i].$3,
                      isActive: i == currentIndex,
                      onTap: () => _onTap(context, i),
                    ),
                  ),
              ],
            ),
          ),
          // Keeps the bar clear of the iPhone home indicator.
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.ink : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The active tab carries a short ink bar above its icon.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isActive ? 24 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            // Tab labels grow with the system text size only up to 1.3x,
            // like the platform tab bars do; beyond that the fixed-height
            // bar would clip them. The screen reader still reads the label.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
