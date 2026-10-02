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
    this.feetFraction = 0.963,
  });

  final String name;

  /// The walk sheet: used on the Profile tile, the Home preview and in rooms.
  final String sheet;

  /// Where the feet sit inside a cell, as a fraction of the cell's height.
  /// Characters stand on this point in the tavern.
  final double feetFraction;
}

/// The choosable characters, in the order `profiles.character_index` uses.
///
/// Luna, Rogue, Lily and Dancer still share the original sprite until their
/// own sheets are added; swap `sheet` here when they are.
const List<GameCharacter> gameCharacters = [
  GameCharacter(
    name: AppStrings.characterLuna,
    sheet: AppImages.characterMenAnim,
  ),
  GameCharacter(
    name: AppStrings.characterRogue,
    sheet: AppImages.characterMenAnim,
  ),
  GameCharacter(
    name: AppStrings.characterMage,
    sheet: AppImages.mageSheet,
    feetFraction: 246 / 256,
  ),
  GameCharacter(
    name: AppStrings.characterLily,
    sheet: AppImages.characterMenAnim,
  ),
  GameCharacter(
    name: AppStrings.characterDancer,
    sheet: AppImages.characterMenAnim,
  ),
];

/// Matches the database default for `profiles.character_index`.
const int defaultCharacterIndex = 1;

GameCharacter characterAt(int index) =>
    gameCharacters[index >= 0 && index < gameCharacters.length
        ? index
        : defaultCharacterIndex];
