import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// One warm light painted in the tavern picture (a lantern, a candle, the
/// fire), in map pixels.
class _Light {
  const _Light(this.x, this.y, this.radius, {this.strength = 1, this.seed = 0});

  final double x;
  final double y;
  final double radius;

  /// How bright the glow is (the fire is brighter than a candle).
  final double strength;

  /// Offsets the flicker so the lights don't pulse together.
  final double seed;
}

/// Warm pools of light around the tavern's lanterns at night, added over
/// the dimmed map and the characters (so someone standing by a lantern is
/// lit by it). Each one flickers gently, like a flame.
class NightLighting extends Component {
  NightLighting() : super(priority: 1 << 20);

  static const List<_Light> _lights = [
    _Light(118, 300, 150, strength: 1.25, seed: 0.0), // fireplace
    _Light(300, 145, 115, seed: 1.3), // wall lantern by the banner
    _Light(740, 148, 115, seed: 2.1), // wall lantern by the painting
    _Light(1295, 178, 70, strength: 0.8, seed: 3.7), // candle on the board
    _Light(300, 580, 105, seed: 4.2), // round table
    _Light(272, 758, 105, seed: 5.6), // long table (left)
    _Light(1070, 460, 100, seed: 6.4), // table (top-right)
    _Light(1160, 615, 100, seed: 7.9), // table (middle-right)
    _Light(1028, 820, 105, seed: 8.5), // big table (bottom-right)
    // Upstairs (1400 map pixels further down; see TavernMap.upstairsTop):
    // the four wall lanterns between the windows.
    _Light(383, 1400 + 120, 120, seed: 9.2),
    _Light(626, 1400 + 120, 120, seed: 10.6),
    _Light(1087, 1400 + 120, 120, seed: 11.3),
    _Light(1322, 1400 + 120, 120, seed: 12.7),
  ];

  static const Color _warm = Color(0xFFFFA64D);

  double _time = 0;
  final Paint _paint = Paint()..blendMode = BlendMode.plus;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    for (final light in _lights) {
      // Two slow waves make an uneven, flame-like flicker.
      final flicker =
          1 +
          0.06 * math.sin(_time * 3.1 + light.seed) +
          0.04 * math.sin(_time * 7.3 + light.seed * 2);
      final radius = light.radius * (0.97 + 0.03 * flicker);
      final alpha = (0.34 * light.strength * flicker).clamp(0.0, 1.0);
      final centre = Offset(light.x, light.y);
      _paint.shader = Gradient.radial(
        centre,
        radius,
        [
          _warm.withValues(alpha: alpha),
          _warm.withValues(alpha: alpha * 0.45),
          _warm.withValues(alpha: 0),
        ],
        const [0, 0.4, 1],
      );
      canvas.drawCircle(centre, radius, _paint);
    }
  }
}
