import 'dart:ui';

/// Layout of Bernie's Tavern, measured in pixels on AppImages.tavernRoom
/// (1402 x 1122). The game world uses the same units, so a box here lines up
/// exactly with the picture.
///
/// To adjust a box: turn on the hitbox view in the room (debug builds show a
/// "HITBOXES" button), tap the map to read coordinates, then edit the numbers
/// below. Rect.fromLTRB is (left, top, right, bottom).
class TavernMap {
  TavernMap._();

  static const double width = 1402;
  static const double height = 1122;

  /// Where players appear: just inside the front door, on the doormat.
  static const Offset spawnPoint = Offset(637, 945);

  /// The open floor in front of the notice board (the board itself is at
  /// x 1212-1340, y 170-290). Standing within [noticeBoardReach] of this
  /// point offers "Read notice board".
  static const Offset noticeBoardSpot = Offset(1245, 310);
  static const double noticeBoardReach = 95;

  /// Everything a player's feet cannot walk through.
  static const List<Rect> collisionBoxes = [
    // --- Outer walls -------------------------------------------------------
    Rect.fromLTRB(0, 0, 1402, 282), // back wall, shelves, door
    Rect.fromLTRB(0, 0, 62, 1122), // left wall
    Rect.fromLTRB(1340, 0, 1402, 1122), // right wall (upper)
    Rect.fromLTRB(1297, 540, 1402, 1122), // right wall (lower step-in)
    Rect.fromLTRB(0, 982, 555, 1122), // bottom wall, left of entrance
    Rect.fromLTRB(722, 982, 1402, 1122), // bottom wall, right of entrance
    Rect.fromLTRB(555, 1040, 722, 1122), // entrance, below the doormat
    // Bottom-left diagonal corner, as steps.
    Rect.fromLTRB(62, 780, 85, 982),
    Rect.fromLTRB(85, 840, 110, 982),
    Rect.fromLTRB(110, 895, 135, 982),
    Rect.fromLTRB(135, 940, 160, 982),
    // Bottom-right diagonal corner, as steps.
    Rect.fromLTRB(1265, 930, 1297, 982),
    Rect.fromLTRB(1240, 960, 1265, 982),

    // --- Back of the room --------------------------------------------------
    Rect.fromLTRB(62, 85, 178, 365), // fireplace
    Rect.fromLTRB(178, 230, 318, 328), // barrels + plant left of the bar
    Rect.fromLTRB(328, 85, 868, 358), // bar counter and shelves
    Rect.fromLTRB(355, 358, 850, 425), // bar stools
    Rect.fromLTRB(1012, 215, 1072, 312), // plant by the door
    Rect.fromLTRB(1072, 85, 1190, 352), // stairs
    Rect.fromLTRB(1212, 170, 1340, 290), // notice board
    Rect.fromLTRB(1278, 265, 1340, 522), // stacked barrels (right)
    Rect.fromLTRB(1232, 400, 1280, 488), // plant on stool (right)

    // --- Left side -----------------------------------------------------------
    Rect.fromLTRB(65, 425, 122, 630), // booth with two stools
    Rect.fromLTRB(203, 545, 398, 658), // round table + chairs
    Rect.fromLTRB(175, 712, 420, 888), // long table + chairs + stools
    Rect.fromLTRB(88, 828, 158, 928), // plant (bottom-left)
    Rect.fromLTRB(198, 912, 318, 982), // two barrels (bottom-left)

    // --- Entrance ------------------------------------------------------------
    Rect.fromLTRB(422, 928, 492, 1030), // plant left of the door
    Rect.fromLTRB(785, 928, 858, 1030), // plant right of the door

    // --- Right side ----------------------------------------------------------
    Rect.fromLTRB(968, 425, 1162, 568), // table (top-right) + chairs
    Rect.fromLTRB(1052, 582, 1268, 742), // table (middle-right) + chairs
    Rect.fromLTRB(878, 740, 1185, 948), // big table (bottom-right) + chairs
    Rect.fromLTRB(1222, 788, 1297, 888), // plant (bottom-right)
    Rect.fromLTRB(1172, 902, 1236, 982), // barrel (bottom-right)
  ];

  static bool isBlocked(Rect feet) =>
      collisionBoxes.any((box) => box.overlaps(feet));
}
