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
        // The deck's red back, from the blackjack UI kit.
        ? Image.asset(
            'assets/images/bj_card_back.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          )
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
