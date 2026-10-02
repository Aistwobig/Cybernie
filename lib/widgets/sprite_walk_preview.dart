import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
class SpriteWalkPreview extends StatefulWidget {
  const SpriteWalkPreview({
    super.key,
    required this.assetPath,
    this.sideAssetPath,
    this.facing,
    this.animate = true,
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

  /// Optional 8 x 2 sheet used when facing left (row 0) or right (row 1),
  /// e.g. a character's dedicated side-run cycle. Its frames must be the
  /// same size as [assetPath]'s.
  final String? sideAssetPath;

  /// When set, the character keeps walking in place facing this way
  /// instead of turning through [directionOrder].
  final SpriteDirection? facing;

  /// False shows a still standing frame (e.g. character picker tiles).
  final bool animate;
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

class _SpriteWalkPreviewState extends State<SpriteWalkPreview> {
  ui.Image? _sheet;
  ui.Image? _sideSheet;
  Timer? _timer;

  int _directionIndex = 0;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final sheet = await _decode(widget.assetPath);
    final side = widget.sideAssetPath == null
        ? null
        : await _decode(widget.sideAssetPath!);
    if (!mounted) return;
    setState(() {
      _sheet = sheet;
      _sideSheet = side;
    });
    _startLoop();
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  void _startLoop() {
    _timer?.cancel();
    if (!widget.animate) return;
    _timer = Timer.periodic(widget.frameDuration, (_) {
      setState(() {
        _frameIndex++;
        if (_frameIndex >= widget.columns) {
          _frameIndex = 0;
          if (widget.facing == null) {
            _directionIndex =
                (_directionIndex + 1) % widget.directionOrder.length;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) {
      return const SizedBox.shrink();
    }

    final direction =
        widget.facing ?? widget.directionOrder[_directionIndex];
    final side = _sideSheet;
    final useSide =
        side != null &&
        (direction == SpriteDirection.west || direction == SpriteDirection.east);

    return CustomPaint(
      painter: _SpritePainter(
        sheet: useSide ? side : sheet,
        columns: widget.columns,
        rows: useSide ? 2 : widget.rows,
        col: _frameIndex,
        row: useSide
            ? (direction == SpriteDirection.west ? 0 : 1)
            : _rowForDirection[direction]!,
      ),
      size: Size.infinite,
    );
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

    // BoxFit.contain the cell into the available size, centered.
    final scale = (size.width / cellWidth < size.height / cellHeight)
        ? size.width / cellWidth
        : size.height / cellHeight;
    final destWidth = cellWidth * scale;
    final destHeight = cellHeight * scale;
    final dstRect = Rect.fromLTWH(
      (size.width - destWidth) / 2,
      (size.height - destHeight) / 2,
      destWidth,
      destHeight,
    );

    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(sheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.col != col || oldDelegate.row != row || oldDelegate.sheet != sheet;
  }
}
