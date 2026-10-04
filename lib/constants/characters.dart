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
  ),
  GameCharacter(
    name: AppStrings.characterRogue,
    sheet: AppImages.characterMenAnim,
    idleSheet: AppImages.boyIdleSheet,
  ),
  GameCharacter(
    name: AppStrings.characterMage,
    sheet: AppImages.mageSheet,
    idleSheet: AppImages.mageIdleSheet,
    horizontalRunSheet: AppImages.mageRunSheet,
    feetFraction: 246 / 256,
  ),
  GameCharacter(
    name: AppStrings.characterLily,
    sheet: AppImages.lilySheet,
    // Breathing idle built from her standing walk frames.
    idleSheet: AppImages.lilyIdleSheet,
    feetFraction: 374 / 384,
  ),
  GameCharacter(
    name: AppStrings.characterDancer,
    sheet: AppImages.characterMenAnim,
    idleSheet: AppImages.boyIdleSheet,
  ),
  // His sheets bake in the bounce: stretched frames are drawn in the air
  // above a shadow on the ground. 16 frames: every drawn pose is followed
  // by an in-between for a smoother hop.
  GameCharacter(
    name: AppStrings.characterSlime,
    sheet: AppImages.slimeSheet,
    idleSheet: AppImages.slimeIdleSheet,
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
