/// What a drink does for a while after you've had it.
enum DrinkEffect {
  /// Tavern Ale: a happy, tipsy sway with bubbles rising off you.
  tipsy,

  /// Berry Wine: little hearts float up around you.
  hearts,

  /// Moonberry Brew: a soft moonlight glow around you (it lights up the
  /// room around you at night).
  glow,

  /// Goblin Cider: you walk much faster, kicking up green sparks.
  swift,
}

/// Something Bernie serves at the bar.
///
/// [id] is what's sent to the other players, so keep it short and never
/// rename one that's in use. Prices must match public.buy_drink in
/// supabase/migrations/20261009000000_drink_prices.sql.
class Drink {
  const Drink({
    required this.id,
    required this.name,
    required this.description,
    required this.asset,
    required this.bernieSays,
    required this.price,
    required this.effect,
    required this.effectName,
    this.effectSeconds = 30,
  });

  final String id;
  final String name;

  /// One line under the name on Bernie's menu.
  final String description;

  /// The mug picture (cut from Bernie's own mug and recoloured).
  final String asset;

  /// What Bernie says when he serves it.
  final String bernieSays;

  /// Coins it costs.
  final int price;

  final DrinkEffect effect;

  /// Short name for the effect, e.g. "Swift" (shown while it lasts).
  final String effectName;
  final int effectSeconds;
}

/// Bernie's menu, in order.
const List<Drink> drinks = [
  Drink(
    id: 'ale',
    name: 'Tavern Ale',
    description: 'Golden and foamy. Makes you merry (and a bit wobbly).',
    asset: 'assets/images/drink_ale.png',
    bernieSays: 'One ale, coming right up!',
    price: 10,
    effect: DrinkEffect.tipsy,
    effectName: 'Merry',
  ),
  Drink(
    id: 'berry',
    name: 'Berry Wine',
    description: 'Sweet and red. Hearts float around you.',
    asset: 'assets/images/drink_berry_wine.png',
    bernieSays: 'Berry wine! A fine choice.',
    price: 15,
    effect: DrinkEffect.hearts,
    effectName: 'Lovestruck',
  ),
  Drink(
    id: 'moon',
    name: 'Moonberry Brew',
    description: 'You glow like the moon. Brightest at night.',
    asset: 'assets/images/drink_moonberry.png',
    bernieSays: "Moonberry brew... don't stare at it too long.",
    price: 25,
    effect: DrinkEffect.glow,
    effectName: 'Moonlit',
    effectSeconds: 60,
  ),
  Drink(
    id: 'cider',
    name: 'Goblin Cider',
    description: 'Fizzy and green. Run fast for 30 seconds!',
    asset: 'assets/images/drink_goblin_cider.png',
    bernieSays: 'Goblin cider. Brave adventurer, you are.',
    price: 25,
    effect: DrinkEffect.swift,
    effectName: 'Swift',
  ),
];

/// The drink sent as [id], or null if there isn't one.
Drink? drinkById(String id) {
  for (final drink in drinks) {
    if (drink.id == id) return drink;
  }
  return null;
}
