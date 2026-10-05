import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../services/lottery_service.dart';
import '../services/sfx_service.dart';
import '../widgets/coin_chip.dart';

/// Bernie's lucky wheel, over the tavern. Press SPIN: the database draws
/// the prize, then the wheel spins and slows down onto it.
class LotteryOverlay extends StatefulWidget {
  const LotteryOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<LotteryOverlay> createState() => _LotteryOverlayState();
}

/// The slices around the wheel, clockwise from the top. Big and small
/// prizes are spread out so the wheel looks lively; every slice is the same
/// size (the chances come from the database, not the slice size).
const List<int> wheelSlices = [1000, 50, 200, 80, 500, 100, 150];

class _LotteryOverlayState extends State<LotteryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );
  late Animation<double> _angle = const AlwaysStoppedAnimation(0);

  bool _spinning = false;
  int? _won;
  String? _problem;
  int _lastTick = 0;
  final math.Random _random = math.Random();

  static const double _slice = 2 * math.pi / 7;

  @override
  void initState() {
    super.initState();
    _spin.addListener(_tick);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// A click each time a slice passes the pointer, like a real wheel.
  void _tick() {
    final passed = (_angle.value / _slice).floor();
    if (passed != _lastTick) {
      _lastTick = passed;
      SfxService.play(Sfx.click, gain: 0.35);
    }
  }

  Future<void> _start() async {
    if (_spinning || _won != null) return;
    setState(() {
      _spinning = true;
      _problem = null;
    });
    int won;
    try {
      won = await LotteryService.spin();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _problem = '$error'.contains('already spun')
            ? AppStrings.lotteryAlreadySpun
            : AppStrings.lotteryError;
      });
      return;
    }
    if (!mounted) return;
    // Land the pointer (at the top) somewhere inside the prize's slice,
    // after six full turns.
    final index = wheelSlices.indexOf(won);
    final jitter = (_random.nextDouble() - 0.5) * _slice * 0.7;
    final target = 6 * 2 * math.pi + (index + 0.5) * _slice + jitter;
    _angle = Tween<double>(
      begin: 0,
      end: target,
    ).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart));
    _lastTick = 0;
    await _spin.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _won = won;
    });
    SfxService.play(Sfx.win);
    SfxService.play(Sfx.coin, gain: 0.7);
    if (won >= 500) SfxService.play(Sfx.sparkle);
  }

  @override
  Widget build(BuildContext context) {
    final won = _won;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            !_spinning) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: const Color(0xD9120B07),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Side by side on a landscape screen, stacked otherwise, so
              // the wheel is as big as fits and the buttons stay on screen.
              final wide = box.maxWidth > box.maxHeight * 1.2;
              final wheel =
                  (wide
                          ? math.min(box.maxHeight - 32, box.maxWidth * 0.5)
                          : math.min(box.maxHeight - 200, box.maxWidth - 40))
                      .clamp(150.0, 420.0);
              final info = _info(won, center: !wide);
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _wheel(wheel, won),
                            const SizedBox(width: 28),
                            SizedBox(width: 240, child: info),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _wheel(wheel, won),
                            const SizedBox(height: 14),
                            info,
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wheel(double size, int? won) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => Transform.rotate(
              // Turning the wheel back brings slice i under the pointer at
              // the top.
              angle: -_angle.value,
              child: CustomPaint(
                size: Size.square(size),
                painter: _WheelPainter(highlight: won),
              ),
            ),
          ),
          // The hub doubles as the SPIN button.
          _Hub(
            size: size * 0.24,
            enabled: !_spinning && won == null,
            onTap: _start,
          ),
          // The pointer at the top.
          Positioned(
            top: -4,
            child: CustomPaint(
              size: Size(size * 0.09, size * 0.11),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// The title, what's happening, and the buttons.
  Widget _info(int? won, {required bool center}) {
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.lotteryTitle,
          textAlign: align,
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFE3A3),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          won != null
              ? AppStrings.lotteryWon(won)
              : _problem ?? AppStrings.lotteryIntro,
          textAlign: align,
          style: GoogleFonts.inter(
            fontSize: won != null ? 17 : 13,
            fontWeight: won != null ? FontWeight.w900 : FontWeight.w500,
            color: won != null
                ? const Color(0xFFFFD36B)
                : const Color(0xFFF1E3C4),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0A945),
              foregroundColor: const Color(0xFF2A1C12),
              disabledBackgroundColor: const Color(0x55E0A945),
              padding: const EdgeInsets.symmetric(horizontal: 26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _spinning
                ? null
                : (won != null || _problem != null)
                ? widget.onClose
                : _start,
            child: Text(
              won != null
                  ? AppStrings.lotteryCollect
                  : _problem != null
                  ? AppStrings.closeButton
                  : _spinning
                  ? AppStrings.lotterySpinning
                  : AppStrings.lotterySpin,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (!_spinning && won == null && _problem == null)
          TextButton(
            onPressed: widget.onClose,
            child: Text(
              AppStrings.lotteryLater,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xCCF1E3C4),
              ),
            ),
          ),
      ],
    );
  }
}

/// The wheel: seven slices in red, cream and gold with their prize, inside
/// a brass rim studded with little lights.
class _WheelPainter extends CustomPainter {
  _WheelPainter({this.highlight});

  final int? highlight;

  static const List<Color> _fills = [
    Color(0xFF9E2B25),
    Color(0xFFF3E2C0),
    Color(0xFF6B3A1E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final slice = 2 * math.pi / wheelSlices.length;

    // Brass rim.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A230F));
    canvas.drawCircle(
      c,
      r * 0.97,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFD27A),
            Color(0xFFB8741C),
            Color(0xFFFFE3A3),
            Color(0xFFB8741C),
            Color(0xFFFFD27A),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final face = r * 0.86;

    for (var i = 0; i < wheelSlices.length; i++) {
      final coins = wheelSlices[i];
      // Slice i spans clockwise from the top.
      final start = -math.pi / 2 + i * slice;
      final jackpot = coins == 1000;
      final fill = jackpot
          ? const Color(0xFFE8B83A)
          : _fills[i % _fills.length];
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: face),
        start,
        slice,
        true,
        Paint()..color = fill,
      );
      canvas.drawLine(
        c,
        c + Offset(math.cos(start), math.sin(start)) * face,
        Paint()
          ..color = const Color(0xFF3A230F)
          ..strokeWidth = r * 0.015,
      );
      // The prize, reading outward along the slice.
      final light = fill.computeLuminance() > 0.4;
      final label = TextPainter(
        text: TextSpan(
          text: '$coins',
          style: GoogleFonts.inter(
            fontSize: r * (coins >= 1000 ? 0.12 : 0.14),
            fontWeight: FontWeight.w900,
            color: light ? const Color(0xFF3A230F) : const Color(0xFFFFF1D0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(start + slice / 2)
        ..translate(face * 0.62, 0)
        ..rotate(math.pi / 2);
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }

    // Studs (little lights) around the rim.
    for (var i = 0; i < 21; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 21;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.915;
      canvas
        ..drawCircle(p, r * 0.028, Paint()..color = const Color(0xFF5A3510))
        ..drawCircle(p, r * 0.019, Paint()..color = const Color(0xFFFFF4C2));
    }
    canvas.drawCircle(
      c,
      face,
      Paint()
        ..color = const Color(0xFF3A230F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.highlight != highlight;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = const Color(0xFFFFD27A))
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3A230F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The middle of the wheel: a gold coin you press to spin.
class _Hub extends StatelessWidget {
  const _Hub({required this.size, required this.enabled, required this.onTap});

  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.lotterySpin,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CoinIcon(size: size),
            Text(
              AppStrings.lotterySpin,
              style: GoogleFonts.inter(
                fontSize: size * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF5A3510),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
