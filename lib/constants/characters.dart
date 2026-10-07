import 'app_images.dart';
import 'app_strings.dart';

/// A character a player can choose on the Profile screen.
///
/// Every sheet is an 8-column x 4-row walk cycle: rows face South (front),
/// North (back), West (left) and East (right).
class GameCharacter {
  const GameCharacter({
    required this.name,
    required this.sheet,
    this.idleSheet,
    this.horizontalRunSheet,
    this.feetFraction = 0.963,
    this.frames = 8,
    this.sitBackSheet,
    this.sitSideSheet,
    this.sitFrontSheet,
    this.profileIdleSheet,
    this.profileIdleFrames = 8,
    this.profileIdleFrameMs = 200,
    this.sitsOverSeat = false,
  });

  final String name;

  /// The walk sheet: used on the Profile tile, the Home preview and in rooms.
  final String sheet;

  /// Optional 8-column x 4-row idle cycle, with one row per facing.
  final String? idleSheet;

  /// Optional 8-column x 2-row run cycle: left on row 0, right on row 1.
  final String? horizontalRunSheet;

  /// Where the feet sit inside a cell, as a fraction of the cell's height.
  /// Characters stand on this point in the tavern.
  final double feetFraction;

  /// Frames per row in the walk and idle sheets (the columns). More frames
  /// play faster, so a cycle takes the same time whatever the count.
  final int frames;

  /// Optional seated idle seen from behind ([frames] columns x 1 row), same
  /// cell size and feet line as [sheet]. Characters with one can sit on the
  /// tavern's seats that face away from the camera.
  final String? sitBackSheet;

  /// Optional seated idle seen from the side ([frames] columns x 2 rows:
  /// facing left on row 0, right on row 1), same cell size and feet line as
  /// [sheet]. Characters with one can sit on the tavern's side chairs.
  final String? sitSideSheet;

  /// Optional seated idle facing the camera ([frames] columns x 1 row),
  /// same cell size and feet line as [sheet]. Characters with one can sit
  /// on the chairs behind tables (the table hides their legs).
  final String? sitFrontSheet;

  /// Optional front-facing idle just for the Profile tile (one row of
  /// [profileIdleFrames] frames, [profileIdleFrameMs] each), for a
  /// character whose in-game sheets aren't ready yet.
  final String? profileIdleSheet;
  final int profileIdleFrames;
  final int profileIdleFrameMs;

  /// Drawn in front of the stool while seated (a full skirt draped over the
  /// cushion) instead of having the stool's front cover the lower body.
  final bool sitsOverSeat;
}

/// The choosable characters, in the order `profiles.character_index` uses.
///
const List<GameCharacter> gameCharacters = [
  GameCharacter(
    name: AppStrings.characterLuna,
    // Her own walk and idle. She sits with her skirt spread over the stool;
    // her front idle from the GIF plays on the Profile tile.
    sheet: AppImages.lunaSheet,
    idleSheet: AppImages.lunaIdleSheet,
    sitBackSheet: AppImages.lunaSitBackSheet,
    // Sitting on the side chairs, hands on her knees, either way round.
    sitSideSheet: AppImages.lunaSitSideSheet,
    // And facing you from behind a table.
    sitFrontSheet: AppImages.lunaSitFrontSheet,
    sitsOverSeat: true,
    feetFraction: 374 / 384,
    profileIdleSheet: AppImages.lunaIdleFront,
    profileIdleFrames: 24,
    profileIdleFrameMs: 125,
  ),
  GameCharacter(
    name: AppStrings.characterRogue,
    sheet: AppImages.characterMenAnim,
    idleSheet: AppImages.boyIdleSheet,
    sitBackSheet: AppImages.boySitBackSheet,
  ),
  GameCharacter(
    name: AppStrings.characterMage,
    sheet: AppImages.mageSheet,
    idleSheet: AppImages.mageIdleSheet,
    horizontalRunSheet: AppImages.mageRunSheet,
    sitBackSheet: AppImages.mageSitBackSheet,
    feetFraction: 246 / 256,
  ),
  GameCharacter(
    name: AppStrings.characterLily,
    sheet: AppImages.lilySheet,
    idleSheet: AppImages.lilyIdleSheet,
    // Her back-facing idle, cut at the skirt hem and lowered onto the seat.
    sitBackSheet: AppImages.lilySitBackSheet,
    feetFraction: 374 / 384,
  ),
  // Took the Dancer's place (same index, so saved picks carry over). He
  // sits with his seated idle cut under the jacket and lowered onto the seat.
  GameCharacter(
    name: AppStrings.characterThief,
    sheet: AppImages.thiefSheet,
    idleSheet: AppImages.thiefIdleSheet,
    sitBackSheet: AppImages.thiefSitBackSheet,
    feetFraction: 374 / 384,
  ),
  // His sheets bake in the bounce: stretched frames are drawn in the air
  // above a shadow on the ground. 16 frames: every drawn pose is followed
  // by an in-between for a smoother hop.
  GameCharacter(
    name: AppStrings.characterSlime,
    sheet: AppImages.slimeSheet,
    idleSheet: AppImages.slimeIdleSheet,
    // His back-facing idle without the floor shadow, resting on the seat.
    sitBackSheet: AppImages.slimeSitBackSheet,
    feetFraction: 246 / 256,
    frames: 16,
  ),
];

/// Matches the database default for `profiles.character_index`.
const int defaultCharacterIndex = 1;

GameCharacter characterAt(int index) =>
    gameCharacters[index >= 0 && index < gameCharacters.length
        ? index
        : defaultCharacterIndex];
