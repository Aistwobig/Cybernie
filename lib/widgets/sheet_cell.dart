import 'package:flutter/material.dart';

/// One cell ([col], [row]) of a sheet laid out as [cols] x [rows] equal
/// cells, drawn [width] x [height].
class SheetCell extends StatelessWidget {
  const SheetCell({
    super.key,
    required this.asset,
    required this.cols,
    required this.rows,
    required this.col,
    required this.row,
    required this.width,
    required this.height,
  });

  final String asset;
  final int cols;
  final int rows;
  final int col;
  final int row;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The whole sheet, shifted so the wanted cell is in view.
            Positioned(
              left: -col * width,
              top: -row * height,
              width: width * cols,
              height: height * rows,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
