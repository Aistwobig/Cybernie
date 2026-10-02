import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../constants/characters.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/profile_service.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';
import '../widgets/corner_framed_box.dart';
import '../widgets/cybernie_bottom_nav.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sprite_walk_preview.dart';

/// Home: who you are, who's around, and the way into the tavern.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with RouteAware {
  static const String _tavernId = 'tavern';

  /// Seeded from the Google account so the very first frame is personal;
  /// the saved profile name replaces it once loaded.
  String? _playerName = _nameFromAccount();
  int _characterIndex = defaultCharacterIndex;

  /// Null until the first presence update arrives.
  int? _tavernPlayers;
  StreamSubscription<int>? _countSubscription;

  /// Null while loading; empty when the player has no friends yet.
  List<Profile>? _friends;
  Timer? _refreshTimer;
  bool _subscribedToRoutes = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _resumeLiveData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_subscribedToRoutes && route is ModalRoute<void>) {
      AppNav.routeObserver.subscribe(this, route);
      _subscribedToRoutes = true;
    }
  }

  @override
  void dispose() {
    AppNav.routeObserver.unsubscribe(this);
    _pauseLiveData();
    super.dispose();
  }

  // Another screen covered Home: stop watching. The tavern opens its own
  // connection to the same channel, and one app can hold only one.
  @override
  void didPushNext() => _pauseLiveData();

  // Back on Home: the name, character or friends may have changed.
  @override
  void didPopNext() {
    _loadProfile();
    _resumeLiveData();
  }

  static String? _nameFromAccount() {
    final meta = AuthService.currentUser?.userMetadata;
    final given = meta?['given_name'] as String?;
    if (given != null && given.isNotEmpty) return given;
    final full = meta?['full_name'] as String?;
    if (full == null || full.trim().isEmpty) return null;
    return full.trim().split(' ').first;
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isSignedIn) return;
    try {
      final profile = await ProfileService.fetchMine();
      if (!mounted) return;
      setState(() {
        if (profile.displayName.isNotEmpty) _playerName = profile.displayName;
        _characterIndex = profile.characterIndex;
      });
    } catch (_) {
      // Keep the account name and default character.
    }
  }

  void _resumeLiveData() {
    if (!AuthService.isSignedIn) {
      setState(() => _friends = const []);
      return;
    }
    _countSubscription ??= RoomService.watchPlayerCount(_tavernId).listen((
      count,
    ) {
      if (mounted) setState(() => _tavernPlayers = count);
    }, onError: (_) {});
    _loadFriends();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadFriends(),
    );
  }

  void _pauseLiveData() {
    _countSubscription?.cancel();
    _countSubscription = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadFriends() async {
    try {
      final entries = await FriendsService.fetchAll();
      if (!mounted) return;
      setState(() {
        _friends = [
          for (final e in entries)
            if (e.status == FriendStatus.friends) e.profile,
        ];
      });
    } catch (_) {
      if (mounted && _friends == null) setState(() => _friends = const []);
    }
  }

  bool get _tavernFull => (_tavernPlayers ?? 0) >= RoomService.maxPlayers;

  void _enterTavern() {
    _pauseLiveData();
    Navigator.of(context).pushNamed('/rooms/tavern');
  }

  Future<void> _signOut() async {
    if (AuthService.isSignedIn) await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = characterAt(_characterIndex);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false, // The bottom nav pads for the home indicator.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            const _OrnamentalDivider(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildBody(constraints, character),
              ),
            ),
            const CybernieBottomNav(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _playerName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                header: true,
                child: Text(
                  name == null
                      ? AppStrings.welcomeGreetingNoName
                      : AppStrings.welcomeGreeting(name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cinzel(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<void>(
            tooltip: AppStrings.moreMenu,
            icon: const Icon(Icons.more_vert, color: AppColors.ink),
            color: AppColors.parchment,
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _signOut,
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: AppColors.ink),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.signOut,
                      style: GoogleFonts.inter(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The character frame takes whatever height is left; on very short or
  /// large-text screens it bottoms out and the page scrolls instead.
  Widget _buildBody(BoxConstraints constraints, GameCharacter character) {
    const horizontal = 24.0;
    const reserved = 280.0; // caption, friends, enter button, gaps
    final width = constraints.maxWidth - horizontal * 2;
    final frame = (constraints.maxHeight - reserved).clamp(150.0, width);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                _CharacterFrame(size: frame, character: character),
                const SizedBox(height: 6),
                _CharacterCaption(character: character),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _FriendsHere(friends: _friends),
                const SizedBox(height: 12),
                _EnterTavernButton(
                  players: _tavernPlayers,
                  isFull: _tavernFull,
                  onPressed: _enterTavern,
                ),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: () => Navigator.of(context).pushNamed('/rooms'),
                    child: Text(
                      AppStrings.browseRooms,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Your walking character in the bracketed frame. Tapping it opens Profile
/// to change character.
class _CharacterFrame extends StatelessWidget {
  const _CharacterFrame({required this.size, required this.character});

  final double size;
  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.characterFrameLabel(character.name),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => AppNav.goToTab(context, '/profile'),
            borderRadius: BorderRadius.circular(10),
            child: const CornerFramedBox(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.expand(
                  child: SpriteWalkPreview(
                    assetPath: AppImages.characterMenAnim,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Playing as Rogue · Change", so the frame says whose character it is.
class _CharacterCaption extends StatelessWidget {
  const _CharacterCaption({required this.character});

  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.characterFrameLabel(character.name),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => AppNav.goToTab(context, '/profile'),
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    character.portrait,
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppStrings.playingAs(character.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.changeCharacter,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Who's around: friends online now, or a nudge toward finding some.
class _FriendsHere extends StatelessWidget {
  const _FriendsHere({required this.friends});

  /// Null while loading.
  final List<Profile>? friends;

  @override
  Widget build(BuildContext context) {
    final all = friends;
    final now = DateTime.now();
    final online = all == null
        ? const <Profile>[]
        : all.where((f) => f.isOnline(now)).toList();

    final String text;
    final Color textColor;
    final String target;
    Widget? leading;

    if (all == null) {
      text = AppStrings.checkingFriends;
      textColor = AppColors.inkMuted;
      target = '/friends';
    } else if (all.isEmpty) {
      text = AppStrings.findFriendsPrompt;
      textColor = AppColors.ink;
      target = '/friends/add';
      leading = const Icon(
        Icons.person_add_alt,
        size: 22,
        color: AppColors.ink,
      );
    } else if (online.isEmpty) {
      text = AppStrings.noFriendsOnline;
      textColor = AppColors.inkMuted;
      target = '/friends';
    } else {
      text = AppStrings.friendsOnline(online.length);
      textColor = AppColors.emberText;
      target = '/friends';
      leading = _AvatarStack(profiles: online.take(4).toList());
    }

    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => target == '/friends'
            ? AppNav.goToTab(context, '/friends')
            : Navigator.of(context).pushNamed(target),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(
                color: AppColors.ink.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to four overlapping friend photos, each ringed in parchment.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.profiles});

  final List<Profile> profiles;

  static const double _radius = 15;
  static const double _overlap = 10;

  @override
  Widget build(BuildContext context) {
    final step = _radius * 2 - _overlap;
    return SizedBox(
      width: _radius * 2 + step * (profiles.length - 1) + 4,
      height: _radius * 2 + 4,
      child: Stack(
        children: [
          for (var i = 0; i < profiles.length; i++)
            Positioned(
              left: step * i,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.parchment,
                  shape: BoxShape.circle,
                ),
                child: PlayerAvatar(
                  photoUrl: profiles[i].avatarUrl,
                  radius: _radius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The way in: ember (the tavern's candlelight) with the live head count.
class _EnterTavernButton extends StatelessWidget {
  const _EnterTavernButton({
    required this.players,
    required this.isFull,
    required this.onPressed,
  });

  /// Null until the live count arrives.
  final int? players;
  final bool isFull;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = players;
    final String? subline = isFull
        ? AppStrings.tavernFullDetail
        : count == null
        ? null
        : count == 0
        ? AppStrings.tavernEmpty
        : AppStrings.tavernInside(count, RoomService.maxPlayers);

    final fill = isFull ? AppColors.parchmentDim : AppColors.ember;
    final foreground = isFull ? AppColors.inkMuted : AppColors.ink;

    return Semantics(
      button: true,
      enabled: !isFull,
      label: [
        isFull ? AppStrings.tavernFull : AppStrings.enterTavern,
        ?subline,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          // Ember is 2.4:1 against parchment; the ink edge defines the button.
          side: const BorderSide(color: AppColors.ink, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isFull ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isFull ? AppStrings.tavernFull : AppStrings.enterTavern,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: foreground,
                    ),
                  ),
                  if (subline != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFull && (count ?? 0) > 0) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          subline,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The thin ink rule under the greeting, with small bracket notches near
/// each end (the same bracket motif as the character frame).
class _OrnamentalDivider extends StatelessWidget {
  const _OrnamentalDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      width: double.infinity,
      child: CustomPaint(
        painter: _DividerPainter(color: AppColors.ink.withValues(alpha: 0.15)),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  _DividerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double notchHeight = 6.0;
    const double notchWidth = 8.0;
    const double margin = 24.0;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(margin, 0)
      ..lineTo(margin, notchHeight)
      ..lineTo(margin + notchWidth, notchHeight)
      ..lineTo(margin + notchWidth, 0)
      ..lineTo(size.width - margin - notchWidth, 0)
      ..lineTo(size.width - margin - notchWidth, notchHeight)
      ..lineTo(size.width - margin, notchHeight)
      ..lineTo(size.width - margin, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DividerPainter oldDelegate) =>
      oldDelegate.color != color;
}
