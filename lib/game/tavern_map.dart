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
    // --- Upstairs: the long meeting table ----------------------------------
    // Seven chairs behind it (facing the camera)...
    Seat.behindMeetingTable(485),
    Seat.behindMeetingTable(571),
    Seat.behindMeetingTable(656),
    Seat.behindMeetingTable(742),
    Seat.behindMeetingTable(827),
    Seat.behindMeetingTable(912),
    Seat.behindMeetingTable(998),
    // ...and seven in front of it (facing the table).
    Seat.facingMeetingTable(485),
    Seat.facingMeetingTable(571),
    Seat.facingMeetingTable(656),
    Seat.facingMeetingTable(742),
    Seat.facingMeetingTable(827),
    Seat.facingMeetingTable(912),
    Seat.facingMeetingTable(998),
    // Its ends: two chairs each, facing the table.
    Seat.sideChair(414, upstairsTop + 443, 383, 420, Facing.east),
    Seat.sideChair(414, upstairsTop + 505, 383, 420, Facing.east),
    Seat.sideChair(1074, upstairsTop + 443, 1066, 1104, Facing.west),
    Seat.sideChair(1074, upstairsTop + 505, 1066, 1104, Facing.west),
  ];
  static const double seatReach = 62;

  /// How close you need to be to sit by double-tapping a seat (a bit more
  /// forgiving than [seatReach], for fingers on phones).
  static const double seatTapReach = 110;

  /// Everything a player's feet cannot walk through: the walls, and each
  /// piece of furniture on its own (traced from the picture), so the floor
  /// between and around them stays walkable.
  static const List<Rect> collisionBoxes = [
    // --- Outer walls -------------------------------------------------------
    Rect.fromLTRB(0, 0, 1402, 282), // back wall, shelves, door
    Rect.fromLTRB(0, 0, 62, 1122), // left wall
    Rect.fromLTRB(1340, 0, 1402, 1122), // right wall (upper)
    Rect.fromLTRB(1293, 525, 1402, 1122), // right wall (lower step-in)
    Rect.fromLTRB(0, 977, 562, 1122), // bottom wall, left of entrance
    Rect.fromLTRB(710, 977, 1402, 1122), // bottom wall, right of entrance
    Rect.fromLTRB(562, 1042, 710, 1122), // entrance, below the doormat
    // Bottom-left corner, cut diagonally (as steps).
    Rect.fromLTRB(62, 775, 75, 892),
    Rect.fromLTRB(62, 790, 88, 892),
    Rect.fromLTRB(62, 892, 100, 977),
    Rect.fromLTRB(62, 910, 115, 977),
    Rect.fromLTRB(62, 930, 135, 977),
    Rect.fromLTRB(62, 950, 155, 977),
    // Bottom-right corner, cut diagonally (as steps).
    Rect.fromLTRB(1285, 870, 1402, 977),
    Rect.fromLTRB(1265, 890, 1402, 977),
    Rect.fromLTRB(1250, 915, 1402, 977),
    Rect.fromLTRB(1235, 940, 1402, 977),
    Rect.fromLTRB(1220, 960, 1402, 977),

    // --- Back of the room --------------------------------------------------
    Rect.fromLTRB(62, 85, 175, 362), // fireplace
    Rect.fromLTRB(182, 282, 318, 328), // two barrels left of the bar
    Rect.fromLTRB(328, 85, 868, 358), // bar counter and shelves
    Rect.fromLTRB(355, 358, 850, 425), // bar stools
    Rect.fromLTRB(1020, 278, 1068, 312), // plant by the door
    Rect.fromLTRB(950, 322, 982, 340), // the bard (an NPC)
    // Stairs: the two railings and the top; the bottom steps can be walked
    // onto, and climbing them (see [stairsUp]) goes upstairs.
    Rect.fromLTRB(1072, 85, 1092, 352),
    Rect.fromLTRB(1170, 85, 1190, 352),
    Rect.fromLTRB(1072, 85, 1190, 250),
    // Notice board (players stand just below it to read it, see
    // [noticeBoardSpot]).
    Rect.fromLTRB(1212, 170, 1280, 290),
    Rect.fromLTRB(1278, 265, 1340, 522), // stacked barrels (right)
    Rect.fromLTRB(1235, 430, 1278, 488), // plant on a stool (right)

    // --- Left side -----------------------------------------------------------
    Rect.fromLTRB(65, 427, 118, 630), // booth with two stools
    Rect.fromLTRB(205, 558, 245, 642), // chair (round table)
    Rect.fromLTRB(253, 565, 353, 655), // round table
    Rect.fromLTRB(358, 598, 397, 642), // stool (round table)
    Rect.fromLTRB(178, 728, 372, 838), // long table
    Rect.fromLTRB(185, 838, 197, 857), // its legs
    Rect.fromLTRB(352, 838, 366, 857),
    Rect.fromLTRB(212, 850, 247, 887), // its two stools
    Rect.fromLTRB(302, 850, 338, 887),
    Rect.fromLTRB(378, 778, 418, 828), // its chair (right end)
    Rect.fromLTRB(98, 860, 150, 925), // plant (bottom-left)
    Rect.fromLTRB(202, 925, 315, 977), // two barrels (bottom-left)

    // --- Entrance ------------------------------------------------------------
    Rect.fromLTRB(428, 950, 480, 977), // plant left of the door
    Rect.fromLTRB(790, 950, 850, 977), // plant right of the door

    // --- Right side ----------------------------------------------------------
    // Table (top-right), where the two drinkers sit.
    Rect.fromLTRB(1015, 440, 1122, 535),
    Rect.fromLTRB(970, 480, 1007, 522), // its chair (left, the boy)
    Rect.fromLTRB(1125, 480, 1158, 523), // its chair (right, the girl)
    Rect.fromLTRB(1050, 535, 1087, 566), // its stool
    // Table (middle-right).
    Rect.fromLTRB(1103, 595, 1217, 710),
    Rect.fromLTRB(1057, 655, 1097, 698), // its chair (left)
    Rect.fromLTRB(1223, 655, 1263, 698), // its chair (right)
    Rect.fromLTRB(1145, 708, 1182, 743), // its stool
    // Big table (bottom-right).
    Rect.fromLTRB(928, 785, 1128, 888),
    Rect.fromLTRB(972, 745, 1013, 785), // its chairs behind it
    Rect.fromLTRB(1060, 745, 1098, 785),
    Rect.fromLTRB(880, 838, 920, 887), // its chair (left)
    Rect.fromLTRB(1140, 838, 1180, 887), // its chair (right)
    Rect.fromLTRB(965, 908, 1002, 943), // its two stools
    Rect.fromLTRB(1057, 908, 1093, 943),
    Rect.fromLTRB(1232, 830, 1290, 888), // plant (bottom-right)
    Rect.fromLTRB(1180, 915, 1232, 977), // barrel (bottom-right)
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
  // The upstairs meeting room (AppImages.tavernUpstairs, 1448 x 1086: a long
  // table, a projector screen) sits in the same game world, [upstairsTop]
  // map pixels down: far enough that nobody on one floor ever sees, hears
  // (voice chat) or meets anyone on the other. Spots and boxes below are in
  // its own picture's pixels ([_up] adds the shift).

  static const double upstairsTop = 1400;
  static const double upstairsWidth = 1448;
  static const double upstairsHeight = 1086;

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
  static const Offset upstairsArrival = Offset(723, upstairsTop + 795);

  /// Walking down through the doorway onto the doormat at the bottom of the
  /// upstairs room goes back downstairs, arriving at [downstairsArrival]
  /// (at the foot of the stairs).
  static const Rect stairsDown = Rect.fromLTRB(
    632,
    upstairsTop + 868,
    815,
    upstairsTop + 925,
  );
  static const Offset stairsDownArrow = Offset(723, upstairsTop + 862);
  static const Offset downstairsArrival = Offset(1131, 398);

  /// The projector screen's picture area (where a shared screen shows).
  static const Rect projectorScreen = Rect.fromLTRB(
    622,
    upstairsTop + 100,
    866,
    upstairsTop + 229,
  );

  /// Upstairs walls and furniture, in the upstairs picture's own pixels.
  static const List<Rect> _upstairsLocal = [
    Rect.fromLTRB(0, 0, 1448, 197), // back wall
    Rect.fromLTRB(608, 0, 880, 245), // projector screen (on its stand)
    Rect.fromLTRB(0, 0, 148, 270), // left alcove (top)
    Rect.fromLTRB(1305, 0, 1448, 270), // right alcove (top)
    Rect.fromLTRB(0, 0, 78, 388), // far left wall
    Rect.fromLTRB(1372, 0, 1448, 388), // far right wall
    Rect.fromLTRB(0, 0, 18, 1086), // left edge
    Rect.fromLTRB(1430, 0, 1448, 1086), // right edge
    Rect.fromLTRB(0, 490, 95, 1086), // left posts
    Rect.fromLTRB(1355, 490, 1448, 1086), // right posts
    Rect.fromLTRB(0, 550, 148, 735), // left alcove (bottom)
    Rect.fromLTRB(1305, 550, 1448, 735), // right alcove (bottom)
    // Bottom corners, cut diagonally (as steps).
    Rect.fromLTRB(0, 735, 100, 1086),
    Rect.fromLTRB(0, 765, 125, 1086),
    Rect.fromLTRB(0, 795, 150, 1086),
    Rect.fromLTRB(1350, 735, 1448, 1086),
    Rect.fromLTRB(1325, 765, 1448, 1086),
    Rect.fromLTRB(1300, 795, 1448, 1086),
    // Bottom wall either side of the doorway, the doorway's sides, and
    // below the doormat.
    Rect.fromLTRB(0, 822, 592, 1086),
    Rect.fromLTRB(855, 822, 1448, 1086),
    Rect.fromLTRB(0, 862, 632, 1086),
    Rect.fromLTRB(815, 862, 1448, 1086),
    Rect.fromLTRB(0, 915, 1448, 1086),
    // Plants in the corners.
    Rect.fromLTRB(158, 195, 203, 228),
    Rect.fromLTRB(1250, 195, 1300, 228),
    Rect.fromLTRB(140, 725, 192, 765),
    Rect.fromLTRB(1258, 725, 1310, 765),
    // The long table and its chairs (the seats are below; sitting puts
    // you there).
    Rect.fromLTRB(428, 392, 1058, 530), // table
    Rect.fromLTRB(458, 356, 1025, 392), // chairs behind it
    Rect.fromLTRB(458, 535, 1025, 588), // chairs in front of it
    Rect.fromLTRB(378, 400, 425, 528), // chairs at its left end
    Rect.fromLTRB(1062, 400, 1108, 528), // chairs at its right end
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

  /// Upstairs: a chair behind the long table, centred on [centerX], sat on
  /// facing the camera. The strip of table in front is drawn over the
  /// sitter, so it hides their legs (reaching far enough down to be drawn
  /// above a seated character, who is lifted over the seat).
  const Seat.behindMeetingTable(double centerX)
    : this(
        centerX,
        TavernMap.upstairsTop + 409,
        frontLeft: centerX - 34,
        frontTop: TavernMap.upstairsTop + 395,
        frontRight: centerX + 35,
        frontBottom: TavernMap.upstairsTop + 440,
        facing: Facing.south,
      );

  /// Upstairs: a chair in front of the long table, centred on [centerX],
  /// sat on facing the table (back to the camera). Its seat edge and legs
  /// are drawn over the sitter, like the stools downstairs.
  const Seat.facingMeetingTable(double centerX)
    : this(
        centerX,
        // High enough that sitters end at the seat's front edge (as on the
        // stools downstairs), so the edge drawn over them hides nothing.
        TavernMap.upstairsTop + 571,
        frontLeft: centerX - 23,
        frontTop: TavernMap.upstairsTop + 562,
        frontRight: centerX + 24,
        frontBottom: TavernMap.upstairsTop + 591,
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
