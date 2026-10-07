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

  /// Where the townsfolk NPCs idle: the bard's feet (below the door), and
  /// the hips of the two drinkers on the side chairs of the table by the
  /// stairs.
  static const Offset bardSpot = Offset(966, 338);
  // The boy's spot is his boots (his sheet shows him whole).
  static const Offset boySpot = Offset(998, 520);
  static const Offset girlSpot = Offset(1140, 508);

  /// The front of those two chairs (seat edge and legs), drawn again over
  /// the drinkers so they sit in the chairs rather than on top of them.
  static const List<Rect> drinkerChairFronts = [];

  /// The inside of the fireplace, where the burning fire is drawn.
  static const Rect fireplaceFire = Rect.fromLTWH(82, 268, 72, 64);

  /// The notice board's frame in the picture, drawn again so it can glow.
  static const Rect noticeBoardRect = Rect.fromLTRB(1214, 174, 1334, 278);

  /// Where Bernie the bartender stands (his feet), behind the bar counter.
  /// [barCounterFront] is the counter top, drawn again over him so the bar
  /// hides him from the waist down (the bottles and menu on it stay in front).
  static const Offset bartenderSpot = Offset(625, 335);
  static const Rect barCounterFront = Rect.fromLTRB(372, 306, 800, 345);

  /// Standing (or sitting) here, at the bar, lets you order from Bernie.
  static const Rect barOrderArea = Rect.fromLTRB(330, 380, 900, 530);

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
    // Side chairs, sat on facing the table beside them (their backrest is
    // on the far side): the point is where the seated character's feet
    // line goes, near the seat's front edge. Numbers: x, y, then the seat's
    // left and right edge.
    // Facing left (chairs on the right of their table).
    Seat.sideChair(1231, 684, 1225, 1252, Facing.west), // middle-right
    Seat.sideChair(1147, 871, 1141, 1171, Facing.west), // big table
    Seat.sideChair(386, 815, 380, 408, Facing.west), // long table (left)
    // Facing right (chairs on the left of their table).
    Seat.sideChair(1085, 684, 1062, 1091, Facing.east), // middle-right
    Seat.sideChair(914, 871, 891, 920, Facing.east), // big table
    Seat.sideChair(239, 596, 216, 245, Facing.east), // round table, back
    Seat.sideChair(239, 630, 216, 245, Facing.east), // round table, front
    // Chairs behind the big table (bottom-right), sat on facing the camera.
    // Their "front" is the strip of table just below them, drawn over the
    // sitter so the table hides their legs. It reaches down far enough to
    // be drawn above a seated character (who is lifted over the seat).
    Seat(
      992,
      790,
      frontLeft: 958,
      frontTop: 776,
      frontRight: 1027,
      frontBottom: 820,
      facing: Facing.south,
    ),
    Seat(
      1078,
      790,
      frontLeft: 1044,
      frontTop: 776,
      frontRight: 1113,
      frontBottom: 820,
      facing: Facing.south,
    ),
  ];
  static const double seatReach = 62;

  /// How close you need to be to sit by double-tapping a seat (a bit more
  /// forgiving than [seatReach], for fingers on phones).
  static const double seatTapReach = 110;

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
    Rect.fromLTRB(950, 322, 982, 340), // the bard (an NPC)
    // Stairs: the two railings and the top; the bottom steps can be walked
    // onto, and climbing them (see [stairsUp]) goes upstairs.
    Rect.fromLTRB(1072, 85, 1092, 352),
    Rect.fromLTRB(1170, 85, 1190, 352),
    Rect.fromLTRB(1072, 85, 1190, 250),
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
      collisionBoxes.any((box) => box.overlaps(feet)) ||
      _upstairsBoxes.any((box) => box.overlaps(feet));

  /// Every collision box on both floors (for the debug hitbox view).
  static List<Rect> get allCollisionBoxes => [
    ...collisionBoxes,
    ..._upstairsBoxes,
  ];

  // --- Upstairs ---------------------------------------------------------------
  //
  // The upstairs room (AppImages.tavernUpstairs, 1536 x 1024) sits in the
  // same game world, [upstairsTop] map pixels down: far enough that nobody
  // on one floor ever sees, hears (voice chat) or meets anyone on the other.
  // Boxes and spots below are in its own picture's pixels, shifted down.

  static const double upstairsTop = 1400;
  static const double upstairsWidth = 1536;
  static const double upstairsHeight = 1024;

  static const Rect downstairsArea = Rect.fromLTWH(0, 0, width, height);
  static const Rect upstairsArea = Rect.fromLTWH(
    0,
    upstairsTop,
    upstairsWidth,
    upstairsHeight,
  );

  static bool isUpstairs(Offset at) => at.dy >= upstairsTop - 100;

  /// The floor [at] is on.
  static Rect floorAt(Offset at) =>
      isUpstairs(at) ? upstairsArea : downstairsArea;

  /// Climbing the stairs into here (between the railings, past the bottom
  /// steps) takes you upstairs, arriving at [upstairsArrival]. The arrow
  /// above the steps ([stairsUpArrow]) shows the way.
  static const Rect stairsUp = Rect.fromLTRB(1092, 250, 1170, 320);
  static const Offset stairsUpArrow = Offset(1131, 300);
  static const Offset upstairsArrival = Offset(768, upstairsTop + 850);

  /// Walking down through the doorway onto the doormat at the bottom of the
  /// upstairs room goes back downstairs, arriving at [downstairsArrival]
  /// (at the foot of the stairs).
  static const Rect stairsDown = Rect.fromLTRB(
    692,
    upstairsTop + 905,
    843,
    upstairsTop + 970,
  );
  static const Offset stairsDownArrow = Offset(768, upstairsTop + 900);
  static const Offset downstairsArrival = Offset(1131, 398);

  /// Upstairs walls, in the upstairs picture's own pixels.
  static const List<Rect> _upstairsLocal = [
    Rect.fromLTRB(0, 0, 1536, 215), // back wall
    Rect.fromLTRB(0, 0, 155, 285), // left alcove (top)
    Rect.fromLTRB(1385, 0, 1536, 285), // right alcove (top)
    Rect.fromLTRB(0, 0, 80, 410), // far left wall
    Rect.fromLTRB(1458, 0, 1536, 410), // far right wall
    Rect.fromLTRB(0, 0, 22, 1024), // left edge
    Rect.fromLTRB(1514, 0, 1536, 1024), // right edge
    Rect.fromLTRB(0, 510, 100, 1024), // left posts
    Rect.fromLTRB(1438, 510, 1536, 1024), // right posts
    Rect.fromLTRB(0, 585, 155, 780), // left alcove (bottom)
    Rect.fromLTRB(1385, 585, 1536, 780), // right alcove (bottom)
    // Bottom corners, cut diagonally (as steps).
    Rect.fromLTRB(0, 780, 110, 1024),
    Rect.fromLTRB(0, 810, 135, 1024),
    Rect.fromLTRB(0, 840, 160, 1024),
    Rect.fromLTRB(1430, 780, 1536, 1024),
    Rect.fromLTRB(1405, 810, 1536, 1024),
    Rect.fromLTRB(1380, 840, 1536, 1024),
    // Bottom wall, either side of the doorway, and the doorway's sides.
    Rect.fromLTRB(0, 858, 628, 1024),
    Rect.fromLTRB(908, 858, 1536, 1024),
    Rect.fromLTRB(0, 890, 692, 1024),
    Rect.fromLTRB(843, 890, 1536, 1024),
    Rect.fromLTRB(0, 962, 1536, 1024), // below the doormat
  ];

  static final List<Rect> _upstairsBoxes = [
    for (final box in _upstairsLocal) box.shift(const Offset(0, upstairsTop)),
  ];
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

  /// A side chair between [seatLeft] and [seatRight], sat on facing
  /// [facing]. Nothing of it is drawn over the sitter (they sit on top).
  const Seat.sideChair(
    double x,
    double y,
    double seatLeft,
    double seatRight,
    Facing facing,
  ) : this(
        x,
        y,
        frontLeft: seatLeft,
        frontTop: y,
        frontRight: seatRight,
        frontBottom: y,
        facing: facing,
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
