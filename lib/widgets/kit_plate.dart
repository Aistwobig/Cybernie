import 'package:flutter/material.dart';

import 'coin_chip.dart';

/// The ornate frames from Bernie's blackjack UI kit
/// (assets/sheets/original_blackjack_ui_kit.png), drawn as nine-slices:
/// the corners stay crisp and the middle stretches to fit.
enum Kit {
  dark('assets/images/bj_plate_dark.png', Rect.fromLTWH(24, 23, 189, 42)),
  cream('assets/images/bj_plate_cream.png', Rect.fromLTWH(24, 15, 206, 49)),
  red('assets/images/bj_plate_red.png', Rect.fromLTWH(18, 13, 113, 21)),
  green('assets/images/bj_plate_green.png', Rect.fromLTWH(18, 13, 162, 23)),
  gold('assets/images/bj_plate_gold.png', Rect.fromLTWH(16, 10, 51, 22)),

  /// Bernie's speech bubble: name tag top left, tail on the left.
  bubble('assets/images/bj_bubble.png', Rect.fromLTWH(124, 36, 146, 26));

  const Kit(this.asset, this.slice);

  final String asset;
  final Rect slice;
}

class KitPlate extends StatelessWidget {
  const KitPlate({
    super.key,
    required this.kit,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.scale = 2.4,
    this.width,
    this.height,
  });

  final Kit kit;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Higher = smaller corners (source pixels per logical pixel).
  final double scale;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(kit.asset),
          centerSlice: kit.slice,
          scale: scale,
          filterQuality: FilterQuality.medium,
        ),
      ),
      child: child,
    );
  }
}

/// The gold coin shown with coin amounts (the app's own drawn coin).
class KitCoin extends StatelessWidget {
  const KitCoin({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => CoinIcon(size: size);
}
