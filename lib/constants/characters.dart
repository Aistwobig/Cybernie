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
}

/// The choosable characters, in the order `profiles.character_index` uses.
///
/// Luna, Rogue and Dancer still share the original sprite until their
/// own sheets are added; swap `sheet` here when they are.
const List<GameCharacter> gameCharacters = [
  GameCharacter(
    name: AppStrings.characterLuna,
    sheet: AppImages.characterMenAnim,
    idleSheet: AppImages.boyIdleSheet,
    sitBackSheet: AppImages.boySitBackSheet,
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
    sitBackSheet: AppImages.lilySitBackSheet,
    feetFraction: 374 / 384,
  ),
  GameCharacter(
    name: AppStrings.characterDancer,
    sheet: AppImages.characterMenAnim,
    idleSheet: AppImages.boyIdleSheet,
    sitBackSheet: AppImages.boySitBackSheet,
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
