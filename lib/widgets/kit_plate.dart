import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bubble('assets/images/bj_bubble.png', Rect.fromLTWH(124, 36, 146, 26)),

  // The table frames (assets/sheets/original_blackjack_frames.png).

  /// The big bet panel, brass corners and side studs.
  panel('assets/images/bjf_panel.png', Rect.fromLTWH(95, 230, 595, 330)),

  /// Red banner with pointed ends (a hand lost).
  banner('assets/images/bjf_banner_red.png', Rect.fromLTWH(62, 32, 439, 66)),

  /// Dark button with corner rivets.
  button('assets/images/bjf_btn_small.png', Rect.fromLTWH(42, 42, 183, 54)),

  /// Gold button (Deal, Hit, Stand).
  goldButton('assets/images/bjf_btn_gold.png', Rect.fromLTWH(48, 48, 461, 69)),

  /// Dark tag with an arrow on its right, pointing at the cards.
  tag('assets/images/bjf_tag.png', Rect.fromLTWH(42, 46, 350, 78)),

  // The tavern HUD (assets/sheets/original_tavern_hud_kit2.png).

  /// Riveted plate (player count, coins).
  hudPlate('assets/images/th_count.png', Rect.fromLTWH(56, 50, 232, 40)),

  /// The long riveted board behind the chat log.
  hudPanel('assets/images/th_panel.png', Rect.fromLTWH(80, 70, 1211, 96)),

  /// The "Chat" tab, a big rivet on its left.
  hudTab('assets/images/th_chat_tab.png', Rect.fromLTWH(110, 52, 260, 40)),

  /// The message box, with its send button on the right.
  hudInput('assets/images/th_input.png', Rect.fromLTWH(120, 52, 880, 44));

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
    this.opacity = 1,
  });

  final Kit kit;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Higher = smaller corners (source pixels per logical pixel).
  final double scale;
  final double? width;
  final double? height;

  /// How solid the frame is drawn (the child stays fully visible).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // Painted with Canvas.drawImageNine rather than DecorationImage's
    // centerSlice, which asserts on non power-of-two scales (rounding).
    return CustomPaint(
      painter: _NinePainter(kit, scale, opacity),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Starts loading every frame, so none pops in late (call when a screen
/// using them opens).
Future<void> preloadKitFrames() =>
    Future.wait([for (final kit in Kit.values) _loadFrame(kit.asset)]);

/// Loaded frame images, shared by every plate.
final Map<String, ui.Image> _frames = {};
final Map<String, Future<ui.Image>> _loading = {};
final ValueNotifier<int> _framesLoaded = ValueNotifier(0);

Future<ui.Image> _loadFrame(String asset) => _loading[asset] ??= () async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final image = (await codec.getNextFrame()).image;
  _frames[asset] = image;
  _framesLoaded.value++;
  return image;
}();

class _NinePainter extends CustomPainter {
  _NinePainter(this.kit, this.scale, this.opacity)
    : super(repaint: _framesLoaded) {
    if (!_frames.containsKey(kit.asset)) _loadFrame(kit.asset);
  }

  final Kit kit;
  final double scale;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final image = _frames[kit.asset];
    if (image == null || size.isEmpty) return;
    // Draw at source resolution, scaled down by [scale], so the corners
    // come out 1/[scale] of their pixel size.
    canvas
      ..save()
      ..scale(1 / scale);
    final dst = Rect.fromLTWH(0, 0, size.width * scale, size.height * scale);
    // The fixed edges can't be bigger than the box itself.
    final slice = kit.slice;
    if (dst.width >= image.width - slice.width &&
        dst.height >= image.height - slice.height) {
      canvas.drawImageNine(
        image,
        slice,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    } else {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NinePainter old) =>
      old.kit != kit || old.scale != scale || old.opacity != opacity;
}

/// The gold coin shown with coin amounts (the app's own drawn coin).
class KitCoin extends StatelessWidget {
  const KitCoin({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => CoinIcon(size: size);
}
