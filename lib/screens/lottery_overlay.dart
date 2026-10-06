import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../services/lottery_service.dart';
import '../services/sfx_service.dart';

/// Bernie's lucky wheel, over the tavern. Press SPIN: the database draws
/// the prize, then the wheel spins and slows down onto it.
class LotteryOverlay extends StatefulWidget {
  const LotteryOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<LotteryOverlay> createState() => _LotteryOverlayState();
}

/// The slices around the wheel art (assets/images/lw_disc.png), clockwise,
/// slice 0 centred at the top. Every slice is the same size; the chances
/// come from the database, not the slice size.
const List<int> wheelSlices = [50, 200, 80, 500, 100, 150, 1000];

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
    // Land the pointer (at the top) somewhere inside the prize's slice
    // (slice i is centred i slices clockwise from the top), after six full
    // turns.
    final index = wheelSlices.indexOf(won);
    final jitter = (_random.nextDouble() - 0.5) * _slice * 0.7;
    final target = 6 * 2 * math.pi + index * _slice + jitter;
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
        color: const Color(0xC70B0705),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Wheel on the left, Bernie's card on the right (stacked on
              // a tall screen), as big as fits.
              final wide = box.maxWidth > box.maxHeight * 1.2;
              final wheelH = wide
                  ? math.min(box.maxHeight - 24, box.maxWidth * 0.5)
                  : math.min(box.maxHeight * 0.55, box.maxWidth * 0.9);
              // The card (banner, parchment, button, "Maybe later") is
              // about 1.05 times as tall as it is wide, plus ~60 px.
              final fitTall = (box.maxHeight - 84) / 1.05;
              final cardW = wide
                  ? math.min(
                      math.min(box.maxWidth - wheelH * 742 / 792 - 60, 420.0),
                      fitTall,
                    )
                  : math.min(box.maxWidth - 32, 420.0);
              final wheel = _wheel(wheelH);
              final card = SizedBox(width: cardW, child: _card(cardW));
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: wide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [wheel, const SizedBox(width: 28), card],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [wheel, const SizedBox(height: 12), card],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The wheel: its slices turn inside the still frame (pointer at the
  /// top), with the SPIN coin in the middle.
  Widget _wheel(double height) {
    // assets/images/lw_frame.png is 742 x 792; the slice disc (566 px across)
    // turns about (380, 392) in it.
    final k = height / 792;
    final disc = 566 * k;
    return SizedBox(
      width: 742 * k,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: (380 - 283) * k,
            top: (392 - 283) * k,
            width: disc,
            height: disc,
            child: AnimatedBuilder(
              animation: _spin,
              // Turning the wheel back brings slice i under the pointer.
              builder: (context, child) =>
                  Transform.rotate(angle: -_angle.value, child: child),
              child: Image.asset(
                'assets/images/lw_disc.png',
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/lw_frame.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          // The SPIN coin, over the hub; pressing it spins.
          Positioned(
            left: (380 - 104) * k,
            top: (392 - 104) * k,
            width: 208 * k,
            height: 208 * k,
            child: Semantics(
              button: true,
              label: AppStrings.lotterySpin,
              child: GestureDetector(
                onTap: !_spinning && _won == null && _problem == null
                    ? _start
                    : null,
                child: AnimatedScale(
                  scale: _spinning ? 0.94 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Image.asset(
                    'assets/images/lw_spin.png',
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bernie's card: the banner, "Daily Spin", the coins, what's happening
  /// and the button.
  Widget _card(double width) {
    final won = _won;
    final k = width / 666;
    final message = won != null
        ? null
        : _problem ??
              (_spinning
                  ? AppStrings.lotterySpinning
                  : AppStrings.lotteryIntro);
    final buttonLabel = won != null
        ? AppStrings.lotteryCollect
        : _problem != null
        ? AppStrings.closeButton
        : _spinning
        ? AppStrings.lotterySpinning
        : AppStrings.lotterySpin;
    final VoidCallback? onButton = _spinning
        ? null
        : (won != null || _problem != null)
        ? widget.onClose
        : _start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The parchment card, with the title banner across its top.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 150 * k),
              child: SizedBox(
                width: width,
                height: 427 * k,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/lw_panel.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned(
                      left: 60 * k,
                      right: 60 * k,
                      top: 120 * k,
                      bottom: 70 * k,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Image.asset(
                            'assets/images/lw_coins.png',
                            height: 110 * k,
                            filterQuality: FilterQuality.medium,
                          ),
                          // "You won 50 coins!" on its dark plate.
                          _Plate(
                            width: width - 120 * k,
                            child: won != null
                                ? Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(text: 'You won '),
                                        TextSpan(
                                          text: '$won',
                                          style: const TextStyle(
                                            color: Color(0xFFFFD027),
                                            fontSize: 22,
                                          ),
                                        ),
                                        const TextSpan(text: ' coins!'),
                                      ],
                                    ),
                                    style: _plateText,
                                  )
                                : Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: _plateText.copyWith(fontSize: 13),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/lw_title.png',
                    width: width,
                    filterQuality: FilterQuality.medium,
                  ),
                  Transform.translate(
                    offset: Offset(0, -18 * k),
                    child: Image.asset(
                      'assets/images/lw_daily.png',
                      width: 314 * k,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The gold button: SPIN, then COLLECT.
        Semantics(
          button: true,
          label: buttonLabel,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onButton,
            child: Opacity(
              opacity: onButton == null ? 0.6 : 1,
              child: SizedBox(
                width: width * 0.72,
                height: width * 0.72 * 134 / 530,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/lw_button.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Text(
                      buttonLabel,
                      style: GoogleFonts.lilitaOne(
                        fontSize: 22,
                        letterSpacing: 1,
                        color: const Color(0xFF2A1408),
                      ),
                    ),
                  ],
                ),
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

  static final TextStyle _plateText = GoogleFonts.lilitaOne(
    fontSize: 18,
    height: 1.1,
    color: const Color(0xFFF5E6C8),
  );
}

/// The dark plate the result is written on (its text erased from the art).
class _Plate extends StatelessWidget {
  const _Plate({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 126 / 666,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/lw_plate.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.12),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ],
      ),
    );
  }
}
