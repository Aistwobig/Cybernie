import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Plays a directional walk-cycle from a single sprite sheet.
///
/// Expects an 8-column x 4-row grid where each row is a facing direction:
///   row 0 = South (front)
///   row 1 = North (back)
///   row 2 = West  (left)
///   row 3 = East  (right)
///
/// Cycles South -> West -> North -> East -> South, 8 frames per direction,
/// looping forever. Drawn with a CustomPainter (nearest-neighbor / no
/// filtering) so pixel art stays crisp instead of getting blurred by
/// BoxFit scaling.
///
/// Driven by a [Ticker], so it pauses automatically while another screen
/// covers it. With the system's reduce-motion setting on, it stands still
/// facing south.
class SpriteWalkPreview extends StatefulWidget {
  const SpriteWalkPreview({
    super.key,
    required this.assetPath,
    this.semanticLabel,
    this.columns = 8,
    this.rows = 4,
    this.frameDuration = const Duration(milliseconds: 110),
    this.directionOrder = const [
      SpriteDirection.south,
      SpriteDirection.west,
      SpriteDirection.north,
      SpriteDirection.east,
    ],
  });

  final String assetPath;

  /// Read out by screen readers; null hides the sprite from them.
  final String? semanticLabel;
  final int columns;
  final int rows;
  final Duration frameDuration;
  final List<SpriteDirection> directionOrder;

  @override
  State<SpriteWalkPreview> createState() => _SpriteWalkPreviewState();
}

enum SpriteDirection { south, north, west, east }

// Row index of each direction within the sheet, per the layout described
// above (South=0, North=1, West=2, East=3).
const Map<SpriteDirection, int> _rowForDirection = {
  SpriteDirection.south: 0,
  SpriteDirection.north: 1,
  SpriteDirection.west: 2,
  SpriteDirection.east: 3,
};

class _SpriteWalkPreviewState extends State<SpriteWalkPreview>
    with SingleTickerProviderStateMixin {
  ui.Image? _sheet;
  bool _failed = false;
  late final Ticker _ticker = createTicker(_onTick);

  int _directionIndex = 0;
  int _frameIndex = 0;
  int _stepsShown = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  Future<void> _loadImage() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _sheet = frame.image);
      _syncMotion();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Walks only when the sheet is ready and motion is allowed.
  void _syncMotion() {
    if (_sheet == null) return;
    if (_reduceMotion) {
      // Called right before a rebuild (dependency change or just after the
      // sheet loaded), so plain assignment is enough.
      _ticker.stop();
      _frameIndex = 0;
      _directionIndex = 0;
    } else if (!_ticker.isActive) {
      _stepsShown = 0;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final steps = elapsed.inMicroseconds ~/ widget.frameDuration.inMicroseconds;
    if (steps == _stepsShown) return;
    final advance = steps - _stepsShown;
    _stepsShown = steps;
    setState(() {
      for (var i = 0; i < advance; i++) {
        _frameIndex++;
        if (_frameIndex >= widget.columns) {
          _frameIndex = 0;
          _directionIndex =
              (_directionIndex + 1) % widget.directionOrder.length;
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    final Widget content;
    if (_failed) {
      content = const Center(
        child: Icon(Icons.person, size: 72, color: Color(0x551B1712)),
      );
    } else {
      final direction = widget.directionOrder[_directionIndex];
      content = AnimatedOpacity(
        opacity: sheet == null ? 0 : 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: sheet == null
            ? const SizedBox.expand()
            : CustomPaint(
                painter: _SpritePainter(
                  sheet: sheet,
                  columns: widget.columns,
                  rows: widget.rows,
                  col: _frameIndex,
                  row: _rowForDirection[direction]!,
                ),
                size: Size.infinite,
              ),
      );
    }

    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: content);
    return Semantics(image: true, label: label, child: content);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.sheet,
    required this.columns,
    required this.rows,
    required this.col,
    required this.row,
  });

  final ui.Image sheet;
  final int columns;
  final int rows;
  final int col;
  final int row;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = sheet.width / columns;
    final cellHeight = sheet.height / rows;

    final srcRect = Rect.fromLTWH(
      col * cellWidth,
      row * cellHeight,
      cellWidth,
      cellHeight,
    );

    // BoxFit.contain the cell into the available size, centered. The scale
    // snaps down to a quarter step: an odd scale like 0.82 makes
    // nearest-neighbor pixels uneven, so edges shimmer as frames change.
    final fit = (size.width / cellWidth < size.height / cellHeight)
        ? size.width / cellWidth
        : size.height / cellHeight;
    final scale = fit >= 0.25 ? (fit * 4).floorToDouble() / 4 : fit;
    final destWidth = cellWidth * scale;
    final destHeight = cellHeight * scale;
    final dstRect = Rect.fromLTWH(
      ((size.width - destWidth) / 2).roundToDouble(),
      ((size.height - destHeight) / 2).roundToDouble(),
      destWidth,
      destHeight,
    );

    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(sheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.col != col ||
        oldDelegate.row != row ||
        oldDelegate.sheet != sheet;
  }
}
