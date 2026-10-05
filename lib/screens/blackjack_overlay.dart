import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../models/blackjack.dart';
import '../services/blackjack_service.dart';
import '../services/coin_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sfx_service.dart';
import '../widgets/coin_chip.dart';
import '../widgets/player_avatar.dart';
import '../widgets/playing_card.dart';
import '../widgets/sheet_cell.dart';

/// Bernie's blackjack table, laid over the tavern: the card-table scene,
/// Bernie's hand on the felt, yours in front of you, and Bernie talking
/// (with his face changing) in a box on the left.
class BlackjackOverlay extends StatefulWidget {
  const BlackjackOverlay({
    super.key,
    required this.table,
    required this.onClose,
    this.offline = false,
  });

  final BlackjackTable table;
  final VoidCallback onClose;

  /// Playing at the on-device table (signed out): says coins aren't saved.
  final bool offline;

  @override
  State<BlackjackOverlay> createState() => _BlackjackOverlayState();
}

/// Bernie's poses, by cell in AppImages.bernieDealer (row by row). Cells
/// 9-16 are his shuffle.
enum _Face {
  idle(0),
  smile(1),
  sly(2),
  laugh(3),
  smug(4),
  surprised(5),
  shocked(6),
  wink(7),
  pleased(8);

  const _Face(this.cell);

  final int cell;
}

const int _shuffleFirstCell = 9;
const int _shuffleFrames = 8;

/// One frame per 120 ms: the 8 frames last as long as the shuffle sound.
const Duration _shuffleFrame = Duration(milliseconds: 120);

class _BlackjackOverlayState extends State<BlackjackOverlay> {
  // AppImages.catBlackjack is 1448 x 1086. Bernie's ears are at y 150 and
  // the felt ends at y 870; the counter in front of his paws is at y 560.
  static const double _sceneW = 1448;
  static const double _sceneH = 1086;
  static const double _bandTop = 150;
  static const double _bandBottom = 870;
  static const double _counterY = 560;

  /// Where Bernie stands (AppImages.bernieDealer cells are drawn here),
  /// the table's back edge that hides him from the waist down, and where
  /// his speech bubble goes (to the right of his head).
  static const Rect _bernieBox = Rect.fromLTWH(415, 80, 640, 600);
  static const double _tableEdgeY = 652;
  static const Offset _bubbleAt = Offset(900, 200);

  BlackjackState? _state;
  bool _busy = false;
  bool _failed = false;
  int _bet = 25;

  /// How many of Bernie's cards are face up on the table: after you stand
  /// they're turned and drawn one at a time.
  int _dealerShown = 0;
  Timer? _reveal;
  static const Duration _revealStep = Duration(milliseconds: 550);

  /// Bumped on each deal, so the new cards slide in again.
  int _round = 0;

  /// Bernie shuffling before a deal: the frame of his shuffle, or null.
  int? _shuffleStep;
  Timer? _shuffleTimer;

  bool _leaderboardOpen = false;

  BlackjackHand? get _hand => _state?.hand;
  int get _coins => _state?.coins ?? CoinService.coins.value ?? 0;

  bool get _revealing =>
      _hand != null && !_hand!.playing && _dealerShown < _hand!.dealer.length;

  bool get _betting => _hand == null || (!_hand!.playing && !_revealing);

  @override
  void initState() {
    super.initState();
    _run(widget.table.load, revealSlowly: false);
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _shuffleTimer?.cancel();
    super.dispose();
  }

  /// Plays Bernie's shuffle (with its sound) and completes when it's done.
  Future<void> _shuffle() {
    final done = Completer<void>();
    SfxService.play(Sfx.shuffle);
    _shuffleTimer?.cancel();
    setState(() => _shuffleStep = 0);
    _shuffleTimer = Timer.periodic(_shuffleFrame, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_shuffleStep ?? 0) + 1;
      if (next >= _shuffleFrames) {
        timer.cancel();
        setState(() => _shuffleStep = null);
        done.complete();
      } else {
        setState(() => _shuffleStep = next);
      }
    });
    return done.future;
  }

  /// Calls the table, then shows the result: Bernie's new cards are turned
  /// one by one (unless [revealSlowly] is false), then the payout.
  Future<void> _run(
    Future<BlackjackState> Function() action, {
    bool revealSlowly = true,
    bool newRound = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final state = await action();
      if (!mounted) return;
      _reveal?.cancel();
      setState(() {
        _state = state;
        if (newRound) _round++;
        final hand = state.hand;
        if (hand == null) {
          _dealerShown = 0;
        } else if (hand.playing || !revealSlowly) {
          _dealerShown = hand.dealer.length;
        } else {
          // The face-down card flips right away; the rest follow.
          _dealerShown = 2;
        }
      });
      CoinService.coins.value = state.coins;
      // Bernie turns over his face-down card.
      if (revealSlowly && state.hand?.playing == false) {
        SfxService.play(Sfx.card, gain: 0.7);
      }
      if (_revealing) {
        _reveal = Timer.periodic(_revealStep, (timer) {
          if (!mounted) return;
          setState(() => _dealerShown++);
          SfxService.play(Sfx.card, gain: 0.8);
          if (!_revealing) {
            timer.cancel();
            _celebrate();
          }
        });
      } else if (revealSlowly && state.hand?.playing == false) {
        _celebrate();
      }
    } catch (error) {
      debugPrint('Blackjack: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _celebrate() {
    final outcome = _hand?.outcome;
    if (outcome == null) return;
    if (outcome == BlackjackOutcome.blackjack) {
      SfxService.play(Sfx.sparkle);
      SfxService.play(Sfx.win);
    } else if (outcome.playerWon) {
      SfxService.play(Sfx.win);
      SfxService.play(Sfx.coin, gain: 0.6);
    } else if (outcome != BlackjackOutcome.push) {
      SfxService.play(Sfx.lose, gain: 0.8);
    }
  }

  void _deal() {
    final bet = _bet;
    // Bernie shuffles first; the cards go out once he's done (and the
    // table has dealt).
    _run(() async {
      final done = await Future.wait<Object?>([
        widget.table.deal(bet),
        _shuffle(),
      ]);
      return done.first! as BlackjackState;
    }, newRound: true);
  }

  void _hit() {
    SfxService.play(Sfx.card);
    _run(widget.table.hit);
  }

  void _stand() {
    SfxService.play(Sfx.click);
    _run(widget.table.stand);
  }

  void _double() {
    SfxService.play(Sfx.coin, gain: 0.6);
    SfxService.play(Sfx.card);
    _run(widget.table.doubleDown);
  }

  void _addToBet(int amount) {
    SfxService.play(Sfx.click, gain: 0.6);
    setState(() {
      _bet = (_bet + amount).clamp(BlackjackTable.minBet, _maxBet);
    });
  }

  int get _maxBet => _coins < BlackjackTable.minBet
      ? BlackjackTable.minBet
      : (_coins < BlackjackTable.maxBet ? _coins : BlackjackTable.maxBet);

  /// One of [lines], the same one for the whole round.
  String _pick(List<String> lines) => lines[_round % lines.length];

  /// Bernie's pose (a cell of his sheet) and what he says right now.
  (int, String) get _bernieSays {
    final hand = _hand;
    final step = _shuffleStep;
    if (step != null) {
      return (_shuffleFirstCell + step, _pick(AppStrings.bernieShuffle));
    }
    final (face, line) = _faceAndLine(hand);
    return (face.cell, line);
  }

  (_Face, String) _faceAndLine(BlackjackHand? hand) {
    if (_failed) return (_Face.smug, AppStrings.bernieTableError);
    if (hand == null) {
      return _coins < BlackjackTable.minBet
          ? (_Face.smug, AppStrings.bernieBroke)
          : (_Face.idle, _pick(AppStrings.bernieWelcome));
    }
    if (hand.playing) {
      return handValue(hand.player) >= 17
          ? (_Face.smug, _pick(AppStrings.bernieHighHand))
          : (_Face.sly, _pick(AppStrings.bernieYourTurn));
    }
    if (_revealing) return (_Face.sly, _pick(AppStrings.bernieRevealing));
    return switch (hand.outcome) {
      BlackjackOutcome.blackjack => (
        _Face.shocked,
        _pick(AppStrings.bernieBlackjack),
      ),
      BlackjackOutcome.win => (_Face.surprised, _pick(AppStrings.bernieWin)),
      BlackjackOutcome.dealerBust => (
        _Face.surprised,
        _pick(AppStrings.bernieDealerBust),
      ),
      BlackjackOutcome.lose => (_Face.pleased, _pick(AppStrings.bernieLose)),
      BlackjackOutcome.dealerBlackjack => (
        _Face.laugh,
        _pick(AppStrings.bernieDealerBlackjack),
      ),
      BlackjackOutcome.bust => (_Face.smug, _pick(AppStrings.bernieBust)),
      BlackjackOutcome.push => (_Face.wink, _pick(AppStrings.berniePush)),
      null => (_Face.smile, _pick(AppStrings.bernieWelcome)),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Keeps the keyboard away from the tavern (no walking off mid-hand);
      // Escape leaves the table.
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(builder: (context, box) => _buildTable(box)),
    );
  }

  Widget _buildTable(BoxConstraints box) {
    final h = box.maxHeight;
    final w = box.maxWidth;
    final hand = _hand;
    // The felt is cleared while Bernie shuffles.
    final shuffling = _shuffleStep != null;
    final dealerCards = hand == null || shuffling
        ? const <int>[]
        : hand.dealer.take(_dealerShown).toList();
    final playerCards = hand == null || shuffling ? const <int>[] : hand.player;
    final (pose, line) = _bernieSays;
    final sideWidth = (w * 0.24).clamp(170.0, 260.0);

    // The scene fills the screen, keeping the band from Bernie's ears to
    // the bottom of the felt in view as far as the screen's shape allows.
    final scale = math.max(w / _sceneW, h / (_bandBottom - _bandTop));
    final sceneW = _sceneW * scale;
    final sceneH = _sceneH * scale;
    final sceneTop = (h / 2 - (_bandTop + _bandBottom) / 2 * scale).clamp(
      h - sceneH,
      0.0,
    );

    // Your cards along the bottom, on the felt; Bernie's on the counter in
    // front of him, just above yours.
    final playerHeight = h * 0.23;
    final dealerHeight = h * 0.19;
    final playerTop = h - playerHeight - 10;
    final dealerTop = math.min(
      sceneTop + _counterY * scale,
      playerTop - dealerHeight - 8,
    );

    final sceneLeft = (w - sceneW) / 2;
    // Bernie's box and the table edge in front of him, in scene pixels.
    final bernieRect = Rect.fromLTWH(
      sceneLeft + _bernieBox.left * scale,
      sceneTop + _bernieBox.top * scale,
      _bernieBox.width * scale,
      _bernieBox.height * scale,
    );
    final tableTop = sceneTop + _tableEdgeY * scale;

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // The bar behind him...
          Positioned(
            left: sceneLeft,
            top: sceneTop,
            width: sceneW,
            height: sceneH,
            child: Image.asset(
              AppImages.catBlackjack,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // ...Bernie himself...
          Positioned.fromRect(
            rect: bernieRect,
            child: SheetCell(
              asset: AppImages.bernieDealer,
              cols: 6,
              rows: 3,
              col: pose % 6,
              row: pose ~/ 6,
              width: bernieRect.width,
              height: bernieRect.height,
            ),
          ),
          // ...and the table in front of him, hiding him from the waist down.
          Positioned(
            left: sceneLeft,
            top: tableTop,
            width: sceneW,
            height: sceneTop + sceneH - tableTop,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: -_tableEdgeY * scale,
                    width: sceneW,
                    height: sceneH,
                    child: Image.asset(
                      AppImages.catBlackjack,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // What he's saying, beside his head.
          Positioned(
            left: sceneLeft + _bubbleAt.dx * scale,
            top: math.max(sceneTop + _bubbleAt.dy * scale, 54),
            width: math.min(250, w - (sceneLeft + _bubbleAt.dx * scale) - 12),
            child: _SpeechBubble(line: line),
          ),
          // Darker along the bottom so the hands and buttons stand out.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x99000000),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sideWidth,
            right: sideWidth,
            top: dealerTop,
            height: dealerHeight,
            child: _HandRow(
              key: ValueKey('dealer-$_round'),
              label: AppStrings.handBernie,
              cards: dealerCards,
              cardHeight: dealerHeight,
            ),
          ),
          Positioned(
            left: sideWidth,
            right: sideWidth,
            top: playerTop,
            height: playerHeight,
            child: _HandRow(
              key: ValueKey('player-$_round'),
              label: AppStrings.handYou,
              cards: playerCards,
              cardHeight: playerHeight,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: [
                _TableButton(
                  label: AppStrings.leaveTableButton,
                  icon: Icons.arrow_back,
                  onPressed: widget.onClose,
                ),
                const SizedBox(width: 8),
                _TableButton(
                  label: AppStrings.leaderboardButton,
                  icon: Icons.emoji_events_outlined,
                  onPressed: () {
                    SfxService.play(Sfx.click, gain: 0.6);
                    setState(() => _leaderboardOpen = !_leaderboardOpen);
                  },
                ),
              ],
            ),
          ),
          const Positioned(top: 12, right: 12, child: CoinChip()),
          if (_leaderboardOpen)
            Positioned(
              left: 12,
              top: 54,
              bottom: 12,
              width: math.max(sideWidth, 230),
              child: _LeaderboardPanel(
                // Reloaded after each hand, as coins change.
                key: ValueKey('board-${_state?.coins}'),
                onClose: () => setState(() => _leaderboardOpen = false),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            width: sideWidth - 20,
            child: _betting ? _buildBetting() : _buildActions(hand!),
          ),
          if (widget.offline)
            Positioned(
              top: 54,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  AppStrings.blackjackSignInHint,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xCCF5EFE0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBetting() {
    final canDeal = !_busy && _coins >= BlackjackTable.minBet && _bet <= _coins;
    final last = _hand;
    return _Panel(
      children: [
        // How the last hand went.
        if (last != null && last.outcome != null) ...[
          Center(child: _ResultBanner(hand: last)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Text(AppStrings.betLabel, style: _labelStyle),
            const Spacer(),
            const CoinIcon(size: 16),
            const SizedBox(width: 6),
            Text('$_bet', style: _numberStyle),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final amount in const [10, 25, 100]) ...[
              Expanded(
                child: _ChipButton(
                  label: '+$amount',
                  onPressed: _busy ? null : () => _addToBet(amount),
                ),
              ),
              if (amount != 100) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ChipButton(
                label: AppStrings.clearBetButton,
                onPressed: _busy
                    ? null
                    : () => setState(() => _bet = BlackjackTable.minBet),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _ActionButton(
                label: AppStrings.dealButton,
                onPressed: canDeal ? _deal : null,
                busy: _busy,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BlackjackHand hand) {
    final enabled = !_busy && hand.playing;
    final canDouble = enabled && hand.player.length == 2 && _coins >= hand.bet;
    return _Panel(
      children: [
        Row(
          children: [
            Text(AppStrings.betLabel, style: _labelStyle),
            const Spacer(),
            const CoinIcon(size: 16),
            const SizedBox(width: 6),
            Text('${hand.bet}', style: _numberStyle),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: AppStrings.hitButton,
                onPressed: enabled ? _hit : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                label: AppStrings.standButton,
                onPressed: enabled ? _stand : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ChipButton(
          label: AppStrings.doubleButton,
          onPressed: canDouble ? _double : null,
        ),
      ],
    );
  }

  static final TextStyle _labelStyle = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: const Color(0xFFD4A86A),
  );

  static const TextStyle _numberStyle = TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: 12,
    height: 1,
    color: Color(0xFFFFE3A3),
  );
}

/// A row of cards, overlapping like a hand on the table, with its total in
/// a small tag beside it.
class _HandRow extends StatelessWidget {
  const _HandRow({
    super.key,
    required this.label,
    required this.cards,
    required this.cardHeight,
  });

  final String label;
  final List<int> cards;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final cardWidth = cardHeight * cardAspect;
    final step = cardWidth * 0.62;
    final width = cardWidth + step * (cards.length - 1);
    final value = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE61B1712),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD4A86A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD4A86A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${handValue(cards)}',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              height: 1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    final row = SizedBox(
      width: width,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: step * i,
              child: _DealtCard(
                key: ValueKey(i),
                card: cards[i],
                height: cardHeight,
                // The first deal lands card by card.
                delay: Duration(milliseconds: i < 2 ? 160 * i : 0),
              ),
            ),
        ],
      ),
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [row, const SizedBox(width: 8), value],
      ),
    );
  }
}

/// A card that slides in from the deck the first time it appears, and
/// flips over when it's turned face up.
class _DealtCard extends StatefulWidget {
  const _DealtCard({
    super.key,
    required this.card,
    required this.height,
    this.delay = Duration.zero,
  });

  final int card;
  final double height;
  final Duration delay;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _slide.forward();
    } else {
      _start = Timer(widget.delay, () {
        if (mounted) _slide.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            // From the deck at the top right of the felt.
            offset: Offset(
              (1 - t) * widget.height * 1.6,
              (1 - t) * -widget.height * 0.9,
            ),
            child: Transform.rotate(angle: (1 - t) * 0.35, child: child),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(animation.value, 1, 1, 1),
            child: child,
          ),
        ),
        child: PlayingCardView(
          key: ValueKey(widget.card),
          card: widget.card,
          height: widget.height,
        ),
      ),
    );
  }
}

/// "+50 coins" (or what was lost) once a hand is over.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.hand});

  final BlackjackHand hand;

  @override
  Widget build(BuildContext context) {
    final net = hand.net;
    final colour = net > 0
        ? const Color(0xFFFFD36B)
        : net < 0
        ? const Color(0xFFFF8A7A)
        : const Color(0xFFF5EFE0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xD91B1712),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colour, width: 1.5),
        ),
        child: Text(
          AppStrings.blackjackNet(net),
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            height: 1.2,
            color: colour,
          ),
        ),
      ),
    );
  }
}

/// Bernie's speech bubble, beside his head with its tail pointing at him.
/// Each new line types itself out, as if he's saying it.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.lora(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF1B1712),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CustomPaint(size: const Size(10, 14), painter: _TailPainter()),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 7, 11, 9),
            decoration: BoxDecoration(
              color: const Color(0xF7F5EFE0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1B1712), width: 1.4),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 6),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.bernieName,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF8A5A12),
                  ),
                ),
                const SizedBox(height: 2),
                TweenAnimationBuilder<int>(
                  key: ValueKey(line),
                  tween: IntTween(begin: 0, end: line.length),
                  duration: Duration(milliseconds: 22 * line.length),
                  builder: (context, shown, _) => Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: line.substring(0, shown)),
                        // The rest takes its space already, so the bubble
                        // doesn't grow while he talks.
                        TextSpan(
                          text: line.substring(shown),
                          style: const TextStyle(color: Color(0x00000000)),
                        ),
                      ],
                    ),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width + 1, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width + 1, size.height)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = const Color(0xF7F5EFE0))
      ..drawLine(
        Offset(size.width, 0),
        Offset(0, size.height / 2),
        Paint()
          ..color = const Color(0xFF1B1712)
          ..strokeWidth = 1.4,
      )
      ..drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height),
        Paint()
          ..color = const Color(0xFF1B1712)
          ..strokeWidth = 1.4,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The richest players, by coins.
class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  late final Future<List<LeaderboardEntry>> _entries = LeaderboardService.top();

  @override
  Widget build(BuildContext context) {
    final myId = LeaderboardService.myId;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF21B1712),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4A86A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 18,
                  color: Color(0xFFFFC966),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.leaderboardTitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFE3A3),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.closeButton,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFFF5EFE0),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4A86A),
                      ),
                    ),
                  );
                }
                final entries = snapshot.data;
                if (entries == null || entries.isEmpty) {
                  return Center(
                    child: Text(
                      snapshot.hasError
                          ? AppStrings.leaderboardError
                          : AppStrings.leaderboardEmpty,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xCCF5EFE0),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _LeaderboardRow(
                    rank: i + 1,
                    entry: entries[i],
                    isMe: entries[i].id == myId || entries[i].id == 'me',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  static const List<Color> _medals = [
    Color(0xFFFFC94D), // gold
    Color(0xFFD9DEE6), // silver
    Color(0xFFD9915A), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? const Color(0x33FFC966) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: rank <= 3
                ? Icon(Icons.emoji_events, size: 16, color: _medals[rank - 1])
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xCCF5EFE0),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(photoUrl: entry.avatarUrl, radius: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '${entry.name} ${AppStrings.leaderboardYou}' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFFF5EFE0),
              ),
            ),
          ),
          const CoinIcon(size: 14),
          const SizedBox(width: 5),
          Text(
            '${entry.coins}',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              height: 1,
              color: Color(0xFFFFE3A3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE61B1712),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4A86A), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A big gold button (Deal, Hit, Stand).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE0A945),
          foregroundColor: const Color(0xFF1B1712),
          disabledBackgroundColor: const Color(0x55E0A945),
          disabledForegroundColor: const Color(0x991B1712),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1B1712),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}

/// A small outlined button (bet chips, Clear, Double).
class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFE3A3),
          disabledForegroundColor: const Color(0x66FFE3A3),
          side: const BorderSide(color: Color(0xFFD4A86A)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  const _TableButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xE61B1712),
          foregroundColor: const Color(0xFFF5EFE0),
          side: const BorderSide(color: Color(0xFFD4A86A)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
