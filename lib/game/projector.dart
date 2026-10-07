import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// The projector screen upstairs: shows the shared screen (letterboxed to
/// fit), says whose it is, and offers "Share screen" / "Stop sharing" and
/// "Full screen" while the mouse is over it, or for a few seconds after a
/// tap on touch screens.
class ProjectorScreen extends PositionComponent
    with TapCallbacks, HoverCallbacks {
  ProjectorScreen({required Rect area})
    : super(
        position: Vector2(area.left, area.top),
        size: Vector2(area.width, area.height),
        // Over the map (it's on the back wall), under everyone.
        priority: 1,
      );

  /// Called when "Share screen" / "Stop sharing" or "Full screen" is
  /// chosen.
  VoidCallback? onShareTap;
  VoidCallback? onFullScreenTap;

  /// Whose screen is showing ("" while nobody shares), and whether it's
  /// ours.
  String sharerName = '';
  bool sharingIsMine = false;
  bool get _active => sharerName.isNotEmpty;

  ui.Image? _frame;

  /// The newest frame (disposed here once replaced or unused).
  set frame(ui.Image? image) {
    _frame?.dispose();
    _frame = image;
  }

  /// Where the shared picture goes, in map pixels: above the caption, and
  /// nowhere while nobody shares or the buttons are showing (the phone app
  /// places the live video there, over everything drawn here).
  Rect? get videoArea => !_active || _showControls
      ? null
      : Rect.fromLTWH(position.x, position.y, size.x, size.y - 11);

  bool _hovered = false;
  double _controlsLeft = 0;
  bool get _showControls => _hovered || _controlsLeft > 0;

  Rect _shareButton = Rect.zero;
  Rect _fullButton = Rect.zero;

  @override
  void update(double dt) {
    if (_controlsLeft > 0) _controlsLeft -= dt;
    if (!_active) frame = null;
  }

  @override
  void onHoverEnter() => _hovered = true;

  @override
  void onHoverExit() => _hovered = false;

  @override
  void onTapUp(TapUpEvent event) {
    final at = event.localPosition.toOffset();
    if (_showControls) {
      if (_shareButton.contains(at)) {
        onShareTap?.call();
        return;
      }
      if (_active && _fullButton.contains(at)) {
        onFullScreenTap?.call();
        return;
      }
    }
    // A tap anywhere else on the screen shows the buttons for a while.
    _controlsLeft = 4;
  }

  static final _caption = TextPaint(
    style: const TextStyle(
      fontSize: 7,
      fontWeight: FontWeight.w800,
      color: Color(0xFFF5E6C8),
    ),
  );
  static final _buttonText = TextPaint(
    style: const TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.w800,
      color: Color(0xFF2A1408),
    ),
  );

  @override
  void render(Canvas canvas) {
    final box = size.toRect();
    final frame = _frame;
    if (_active) {
      // The dark of a projector showing something, then the picture.
      canvas.drawRect(box, Paint()..color = const Color(0xFF14100C));
      if (frame != null) {
        final fw = frame.width.toDouble(), fh = frame.height.toDouble();
        final scale = math.min(box.width / fw, box.height / fh);
        final dest = Rect.fromCenter(
          center: box.center,
          width: fw * scale,
          height: fh * scale,
        );
        canvas.drawImageRect(
          frame,
          Rect.fromLTWH(0, 0, fw, fh),
          dest,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      // Whose screen it is, along the bottom.
      final label = sharingIsMine
          ? 'You are sharing your screen'
          : '$sharerName is sharing';
      final strip = Rect.fromLTWH(0, box.height - 11, box.width, 11);
      canvas.drawRect(strip, Paint()..color = const Color(0x99000000));
      _caption.render(
        canvas,
        label,
        Vector2(box.width / 2, box.height - 5.5),
        anchor: Anchor.center,
      );
    }
    if (!_showControls) {
      _shareButton = Rect.zero;
      _fullButton = Rect.zero;
      return;
    }
    // A soft shade, and the buttons in the middle.
    canvas.drawRect(box, Paint()..color = const Color(0x55000000));
    final shareLabel = sharingIsMine ? 'Stop sharing' : 'Share screen';
    const h = 16.0, gap = 6.0, w = 70.0;
    final showFull = _active;
    final total = showFull ? w * 2 + gap : w;
    var left = box.center.dx - total / 2;
    final top = box.center.dy - h / 2 - 4;
    _shareButton = Rect.fromLTWH(left, top, w, h);
    _drawButton(canvas, _shareButton, shareLabel, Icons.screen_share);
    if (showFull) {
      left += w + gap;
      _fullButton = Rect.fromLTWH(left, top, w, h);
      _drawButton(canvas, _fullButton, 'Full screen', Icons.fullscreen);
    } else {
      _fullButton = Rect.zero;
    }
  }

  void _drawButton(Canvas canvas, Rect r, String text, IconData icon) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    canvas
      ..drawRRect(
        rr.shift(const Offset(0, 1)),
        Paint()..color = const Color(0x88000000),
      )
      ..drawRRect(rr, Paint()..color = const Color(0xFFFFD027))
      ..drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFF7A4A12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    // The icon (from the Material icon font), then the text.
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 9,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: const Color(0xFF2A1408),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(r.left + 5, r.center.dy - iconPainter.height / 2),
    );
    _buttonText.render(
      canvas,
      text,
      Vector2(r.left + 16, r.center.dy),
      anchor: Anchor.centerLeft,
    );
  }

  @override
  void onRemove() {
    frame = null;
    super.onRemove();
  }
}
