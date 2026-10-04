/// Something Bernie serves at the bar.
///
/// [id] is what's sent to the other players, so keep it short and never
/// rename one that's in use.
class Drink {
  const Drink({
    required this.id,
    required this.name,
    required this.description,
    required this.asset,
    required this.bernieSays,
  });

  final String id;
  final String name;

  /// One line under the name on Bernie's menu.
  final String description;

  /// The mug picture (cut from Bernie's own mug and recoloured).
  final String asset;

  /// What Bernie says when he serves it.
  final String bernieSays;
}

/// Bernie's menu, in order.
const List<Drink> drinks = [
  Drink(
    id: 'ale',
    name: 'Tavern Ale',
    description: 'Golden, foamy, the house favourite.',
    asset: 'assets/images/drink_ale.png',
    bernieSays: 'One ale, coming right up!',
  ),
  Drink(
    id: 'berry',
    name: 'Berry Wine',
    description: 'Sweet and red, from the hillside farms.',
    asset: 'assets/images/drink_berry_wine.png',
    bernieSays: 'Berry wine! A fine choice.',
  ),
  Drink(
    id: 'moon',
    name: 'Moonberry Brew',
    description: 'Glows a little. Nobody knows why.',
    asset: 'assets/images/drink_moonberry.png',
    bernieSays: "Moonberry brew... don't stare at it too long.",
  ),
  Drink(
    id: 'cider',
    name: 'Goblin Cider',
    description: 'Fizzy, green and suspiciously strong.',
    asset: 'assets/images/drink_goblin_cider.png',
    bernieSays: 'Goblin cider. Brave adventurer, you are.',
  ),
];

/// The drink sent as [id], or null if there isn't one.
Drink? drinkById(String id) {
  for (final drink in drinks) {
    if (drink.id == id) return drink;
  }
  return null;
}
