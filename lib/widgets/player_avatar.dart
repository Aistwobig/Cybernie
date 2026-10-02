import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A round player photo, or a plain person icon until they've imported one.
/// Optionally shows an online dot in the corner.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 18,
    this.isOnline,
  });

  final String? photoUrl;
  final double radius;

  /// Null hides the status dot.
  final bool? isOnline;

  static const Color onlineGreen = Color(0xFF3DDC84);

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.surfaceRaised,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: radius * 1.25,
        color: AppColors.text.withValues(alpha: 0.45),
      ),
    );
    final url = photoUrl;

    final photo = ClipOval(
      child: url == null || url.isEmpty
          ? placeholder
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );

    final online = isOnline;
    if (online == null) return photo;

    final dot = radius * 0.55;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          photo,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online
                    ? onlineGreen
                    : AppColors.text.withValues(alpha: 0.35),
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
