import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';
import '../widgets/fantasy_ui.dart';
import '../widgets/sprite_walk_preview.dart';

/// Home: greeting, your character in its framed scene (turn it with the
/// arrows), the live tavern count and JOIN ROOM.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with RouteAware {
  static const String _tavernId = 'tavern';

  /// The order the arrows turn the character through.
  static const List<SpriteDirection> _facings = [
    SpriteDirection.south,
    SpriteDirection.west,
    SpriteDirection.north,
    SpriteDirection.east,
  ];

  String _playerName = AppStrings.profilePlayerName;
  int _facingIndex = 0;

  int? _tavernPlayers;
  StreamSubscription<int>? _countSubscription;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _watchTavern();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is ModalRoute<void>) {
      AppNav.routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    AppNav.routeObserver.unsubscribe(this);
    _countSubscription?.cancel();
    super.dispose();
  }

  // Another screen covered Home. Stop watching the tavern: Select Room and
  // the tavern itself open their own connection to the same channel, and an
  // app can hold only one.
  @override
  void didPushNext() {
    _countSubscription?.cancel();
    _countSubscription = null;
  }

  // Back on Home: the name may have changed on Profile.
  @override
  void didPopNext() {
    _loadPlayerName();
    _watchTavern();
  }

  /// Shows the name from the player's profile, which starts as the first name
  /// on their Google account and can be changed on the Profile screen.
  Future<void> _loadPlayerName() async {
    if (!AuthService.isSignedIn) return;
    try {
      final profile = await ProfileService.fetchMine();
      if (mounted && profile.displayName.isNotEmpty) {
        setState(() => _playerName = profile.displayName);
      }
    } catch (_) {
      // Keep the default name if the profile can't be loaded.
    }
  }

  void _watchTavern() {
    if (!AuthService.isSignedIn || _countSubscription != null) return;
    _countSubscription = RoomService.watchPlayerCount(_tavernId).listen(
      (count) {
        if (mounted) setState(() => _tavernPlayers = count);
      },
      onError: (_) {},
    );
  }

  void _turn(int step) => setState(() {
    _facingIndex = (_facingIndex + step) % _facings.length;
  });

  Future<void> _signOut() async {
    if (AuthService.isSignedIn) await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CastleBackdrop(height: 230),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGreeting(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => _buildCard(constraints),
                  ),
                ),
                const FantasyBottomNav(currentIndex: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: AppStrings.welcomeGreeting(_playerName),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.welcomeLabel,
                    style: FantasyText.mono(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      spacing: 5,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_playerName.toUpperCase()}!',
                      maxLines: 1,
                      style: FantasyText.title(
                        size: 40,
                      ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Image.asset(
                        AppImages.ornamentDivider,
                        width: 150,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 6),
                      Image.asset(
                        AppImages.compassStar,
                        width: 30,
                        filterQuality: FilterQuality.medium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<void>(
            tooltip: AppStrings.menuButton,
            color: AppColors.card,
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _signOut,
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: AppColors.ink),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.signOut,
                      style: FantasyText.mono(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: const IgnorePointer(
              child: FramedIconButton(
                icon: Icons.menu,
                tooltip: AppStrings.menuButton,
                onPressed: null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The parchment card holding the banner, character frame, tavern count
  /// and JOIN ROOM. The character frame takes the height that's left; on
  /// small or large-text screens the card scrolls instead.
  Widget _buildCard(BoxConstraints constraints) {
    const reserved = 262.0; // banner, dots, count, button, paddings
    final frameHeight = (constraints.maxHeight - reserved).clamp(200.0, 460.0);
    final facing = _facings[_facingIndex];
    final count = _tavernPlayers;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StarBanner(
              title: AppStrings.characterPreviewTitle,
              subtitle: AppStrings.characterPreviewSubtitle,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: frameHeight,
              child: _CharacterStage(
                facing: facing,
                onPrevious: () => _turn(_facings.length - 1),
                onNext: () => _turn(1),
              ),
            ),
            const SizedBox(height: 10),
            _FacingDots(count: _facings.length, active: _facingIndex),
            const SizedBox(height: 10),
            SizedBox(
              height: 18,
              child: count == null
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: count > 0
                                ? AppColors.online
                                : AppColors.navMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.tavernAdventurers(
                            count,
                            RoomService.maxPlayers,
                          ),
                          style: FantasyText.mono(size: 12.5),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            FantasyButton(
              label: AppStrings.joinRoomButton,
              leading: Image.asset(
                AppImages.sword,
                width: 30,
                filterQuality: FilterQuality.medium,
              ),
              showChevron: true,
              onPressed: () => Navigator.of(context).pushNamed('/rooms'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The framed scene with your walking character, a soft halo, sparkles and
/// the octagonal arrows that turn the character.
class _CharacterStage extends StatelessWidget {
  const _CharacterStage({
    required this.facing,
    required this.onPrevious,
    required this.onNext,
  });

  final SpriteDirection facing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: FantasyCard(
            padding: const EdgeInsets.all(9),
            cornerSize: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.75,
                    child: Image.asset(
                      AppImages.homePreviewScene,
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const CustomPaint(painter: _HaloPainter()),
                  const _Sparkles(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                    child: SpriteWalkPreview(
                      assetPath: AppImages.characterMenAnim,
                      facing: facing,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _OctagonArrow(
              icon: Icons.chevron_left,
              tooltip: AppStrings.turnLeft,
              onPressed: onPrevious,
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _OctagonArrow(
              icon: Icons.chevron_right,
              tooltip: AppStrings.turnRight,
              onPressed: onNext,
            ),
          ),
        ),
      ],
    );
  }
}

/// The faint ring behind the character.
class _HaloPainter extends CustomPainter {
  const _HaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.shortestSide * 0.36;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.card.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.frameBrown.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sparkles extends StatelessWidget {
  const _Sparkles();

  @override
  Widget build(BuildContext context) {
    Widget sparkle(double size, double opacity) => Opacity(
      opacity: opacity,
      child: Image.asset(
        AppImages.sparkle,
        width: size,
        filterQuality: FilterQuality.medium,
      ),
    );

    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.6, -0.65),
            child: sparkle(20, 0.8),
          ),
          Align(
            alignment: const Alignment(0.62, -0.45),
            child: sparkle(16, 0.6),
          ),
          Align(
            alignment: const Alignment(0.5, 0.05),
            child: sparkle(14, 0.7),
          ),
          Align(
            alignment: const Alignment(-0.72, 0.15),
            child: sparkle(12, 0.45),
          ),
        ],
      ),
    );
  }
}

/// Dark octagonal button with a light inner ring, as in the mockup.
class _OctagonArrow extends StatelessWidget {
  const _OctagonArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: Material(
            color: AppColors.card,
            shape: const _OctagonBorder(),
            child: InkWell(
              customBorder: const _OctagonBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: const Color(0xFF4A3424),
                  shape: const _OctagonBorder(
                    side: BorderSide(color: AppColors.parchmentDim),
                  ),
                  child: Icon(icon, color: AppColors.parchment, size: 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonBorder extends ShapeBorder {
  const _OctagonBorder({this.side = const BorderSide(color: AppColors.ink)});

  final BorderSide side;

  Path _path(Rect r) {
    final c = r.shortestSide * 0.28;
    return Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..lineTo(r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => _OctagonBorder(side: side.scale(t));
}

/// One dot per facing; the current one is filled.
class _FacingDots extends StatelessWidget {
  const _FacingDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == active ? AppColors.ink : AppColors.parchmentDim,
              ),
            ),
        ],
      ),
    );
  }
}
