import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../services/coin_service.dart';
import 'kit_plate.dart';

/// A small gold coin.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas
      ..drawCircle(c, r, Paint()..color = const Color(0xFF8A5A12))
      ..drawCircle(
        c,
        r * 0.86,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFFF0B3), Color(0xFFF2B53A), Color(0xFFC9861C)],
            stops: [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      )
      ..drawCircle(
        c,
        r * 0.58,
        Paint()
          ..color = const Color(0xFFB57514)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The player's coins in a dark pill (hidden until they've loaded).
class CoinChip extends StatelessWidget {
  const CoinChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: CoinService.coins,
      builder: (context, coins, _) {
        if (coins == null) return const SizedBox.shrink();
        return Semantics(
          label: AppStrings.coinsLabel(coins),
          excludeSemantics: true,
          // The kit's ornate dark plate with its gold coin.
          child: KitPlate(
            kit: Kit.dark,
            scale: 2.8,
            height: 38,
            padding: const EdgeInsets.fromLTRB(9, 0, 14, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppImages.hudCoin,
                  width: 24,
                  height: 24,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Text(
                  '$coins',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFE3A3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
