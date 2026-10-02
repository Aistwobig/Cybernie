import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Draws a thin rounded border around [child], with ornamental 'L' shaped
/// corner brackets inside the frame to match the pixel-art/fantasy aesthetic.
class CornerFramedBox extends StatelessWidget {
  const CornerFramedBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.text.withValues(alpha: 0.25),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
        // Positioned corner brackets inset slightly from the border
        const Positioned(top: 6, left: 6, child: _CornerBracket(alignment: Alignment.topLeft)),
        const Positioned(top: 6, right: 6, child: _CornerBracket(alignment: Alignment.topRight)),
        const Positioned(bottom: 6, left: 6, child: _CornerBracket(alignment: Alignment.bottomLeft)),
        const Positioned(bottom: 6, right: 6, child: _CornerBracket(alignment: Alignment.bottomRight)),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final Alignment alignment;
  const _CornerBracket({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.text.withValues(alpha: 0.45);
    const double size = 8.0;
    const double strokeWidth = 1.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
              ? BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
        ),
      ),
    );
  }
}