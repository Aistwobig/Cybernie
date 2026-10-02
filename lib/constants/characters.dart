import 'app_images.dart';
import 'app_strings.dart';

/// A character a player can choose on the Profile screen.
class GameCharacter {
  const GameCharacter({required this.name, required this.portrait});

  final String name;

  /// Small portrait used on the character tiles and the Welcome caption.
  final String portrait;
}

/// The choosable characters, in the order `profiles.character_index` uses.
const List<GameCharacter> gameCharacters = [
  GameCharacter(
    name: AppStrings.characterLuna,
    portrait: AppImages.profileLuna,
  ),
  GameCharacter(
    name: AppStrings.characterRogue,
    portrait: AppImages.profileRogue,
  ),
  GameCharacter(
    name: AppStrings.characterMage,
    portrait: AppImages.profileMage,
  ),
  GameCharacter(
    name: AppStrings.characterLily,
    portrait: AppImages.profileLuna,
  ),
  GameCharacter(
    name: AppStrings.characterDancer,
    portrait: AppImages.profileRogue,
  ),
];

/// Matches the database default for `profiles.character_index`.
const int defaultCharacterIndex = 1;

GameCharacter characterAt(int index) =>
    gameCharacters[index >= 0 && index < gameCharacters.length
        ? index
        : defaultCharacterIndex];
