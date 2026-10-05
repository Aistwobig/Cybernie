import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import '../models/blackjack.dart';
import 'sheet_cell.dart';

/// Width / height of the cat cards.
const double cardAspect = 150 / 166;

/// One card from the cat deck ([AppImages.catCards]), or its back for
/// [hiddenCard], [height] pixels tall.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({super.key, required this.card, required this.height});

  final int card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * cardAspect;
    final radius = BorderRadius.circular(height * 0.06);
    final face = card == hiddenCard
        ? const _CardBack()
        // Column = rank (A..K), row = suit.
        : SheetCell(
            asset: AppImages.catCards,
            cols: 13,
            rows: 4,
            col: cardRank(card),
            row: cardSuit(card),
            width: width,
            height: height,
          );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 6,
            offset: Offset(1, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: face),
    );
  }
}

/// The deck's red back, like the cards in Bernie's paw: a cream border
/// around a diamond lattice, with a small gold spade in the middle.
class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CardBackPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF3E6CC));
    final inner = rect.deflate(size.width * 0.07);
    canvas.drawRect(inner, Paint()..color = const Color(0xFFB8322C));
    // Diamond lattice.
    canvas.save();
    canvas.clipRect(inner);
    final line = Paint()
      ..color = const Color(0xFFE8857A)
      ..strokeWidth = size.width * 0.025;
    final step = size.width * 0.16;
    for (var d = -size.height; d < size.width + size.height; d += step) {
      canvas
        ..drawLine(Offset(d, 0), Offset(d + size.height, size.height), line)
        ..drawLine(Offset(d, size.height), Offset(d + size.height, 0), line);
    }
    canvas.restore();
    canvas.drawRect(
      inner,
      Paint()
        ..color = const Color(0xFF7A1C17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02,
    );
    // A gold spade on a dark medallion.
    final centre = rect.center;
    canvas.drawCircle(
      centre,
      size.width * 0.17,
      Paint()..color = const Color(0xFF7A1C17),
    );
    final spade = TextPainter(
      text: TextSpan(
        text: '♠',
        style: TextStyle(
          fontSize: size.width * 0.26,
          color: const Color(0xFFFFC966),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    spade.paint(canvas, centre - Offset(spade.width / 2, spade.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
