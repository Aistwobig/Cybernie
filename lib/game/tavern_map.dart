import 'dart:ui';

import 'character.dart' show Facing;

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

  /// Where Bernie the bartender stands (his feet), behind the bar counter.
  /// [barCounterFront] is the counter top, drawn again over him so the bar
  /// hides him from the waist down (the bottles and menu on it stay in front).
  static const Offset bartenderSpot = Offset(625, 335);
  static const Rect barCounterFront = Rect.fromLTRB(372, 306, 800, 345);

  /// The seats. Each has where a seated character's feet line goes, and the
  /// stool's front (cushion edge and legs) as a rectangle of this picture.
  /// The game draws that front again as its own sprite, layered by depth:
  /// over whoever sits on it (their legs tuck behind the stool) and under
  /// anyone walking past in front. Standing within [seatReach] of a free
  /// seat offers "Click to sit".
  ///
  /// Only seats you sit on with your back to the camera for now (the bar
  /// stools, and the stools in front of tables), matching the seated
  /// animations the characters have. Side and front chairs can be added
  /// here with their own [Seat.facing] once those animations exist.
  static const List<Seat> seats = [
    // Bar stools, facing the bar: red cushion from y 368, legs to y 427.
    Seat.barStool(379),
    Seat.barStool(445),
    Seat.barStool(508),
    Seat.barStool(572),
    Seat.barStool(632),
    Seat.barStool(696),
    Seat.barStool(762),
    Seat.barStool(826),
    // Wooden stools in front of tables, facing the table. The number is the
    // top of the seat.
    Seat.tableStool(229, 841), // long table (left)
    Seat.tableStool(320, 841),
    Seat.tableStool(1068, 529), // table (top-right)
    Seat.tableStool(1162, 696), // table (middle-right)
    Seat.tableStool(983, 903), // big table (bottom-right)
    Seat.tableStool(1073, 903),
  ];
  static const double seatReach = 62;

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

/// A place to sit: where the seated character's feet go, and which way
/// they face (north = back to the camera).
class Seat {
  const Seat(
    this.x,
    this.y, {
    required this.frontLeft,
    required this.frontTop,
    required this.frontRight,
    required this.frontBottom,
    this.facing = Facing.north,
  });

  /// A red-cushioned bar stool centred on [centerX].
  const Seat.barStool(double centerX)
    : this(
        centerX,
        404,
        frontLeft: centerX - 18,
        frontTop: 396,
        frontRight: centerX + 19,
        frontBottom: 429,
      );

  /// A wooden stool centred on [centerX] whose seat top is at [seatTop].
  const Seat.tableStool(double centerX, double seatTop)
    : this(
        centerX,
        seatTop + 35,
        frontLeft: centerX - 18,
        frontTop: seatTop + 22,
        frontRight: centerX + 19,
        frontBottom: seatTop + 48,
      );

  /// Where the seated character's feet line goes.
  final double x;
  final double y;
  final Facing facing;

  final double frontLeft;
  final double frontTop;
  final double frontRight;
  final double frontBottom;

  /// The part of the stool drawn in front of whoever sits on it, in map
  /// pixels (cut from the same spot of the tavern picture): the seat's front
  /// edge and the legs, exactly as wide as the stool, so hair and clothes
  /// drape over the seat but nothing shows below it.
  Rect get front => Rect.fromLTRB(frontLeft, frontTop, frontRight, frontBottom);
}
