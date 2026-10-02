import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';
import '../widgets/fantasy_ui.dart';

/// "Select Room" screen, opened from the JOIN ROOM button on the welcome
/// screen. Lists the available rooms (just Bernie's Tavern for now) with a
/// live player count, plus a dashed "coming soon" placeholder.
class SelectRoomScreen extends StatefulWidget {
  const SelectRoomScreen({super.key});

  @override
  State<SelectRoomScreen> createState() => _SelectRoomScreenState();
}

class _SelectRoomScreenState extends State<SelectRoomScreen> {
  static const String _tavernId = 'tavern';

  StreamSubscription<int>? _countSubscription;
  int _tavernPlayers = 0;

  bool get _tavernFull => _tavernPlayers >= RoomService.maxPlayers;

  @override
  void initState() {
    super.initState();
    _watchCount();
  }

  @override
  void dispose() {
    _countSubscription?.cancel();
    super.dispose();
  }

  void _watchCount() {
    if (!AuthService.isSignedIn) return;
    _countSubscription = RoomService.watchPlayerCount(_tavernId).listen((
      count,
    ) {
      if (mounted) setState(() => _tavernPlayers = count);
    }, onError: (_) {});
  }

  Future<void> _joinTavern() async {
    // The room screen opens its own connection to this room's channel, so
    // stop watching the count until we come back.
    await _countSubscription?.cancel();
    _countSubscription = null;
    if (!mounted) return;
    await Navigator.of(context).pushNamed('/rooms/tavern');
    if (mounted) _watchCount();
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
            child: CastleBackdrop(height: 210),
          ),
          // The lamp-post terrace along the bottom, as on Friends.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.6,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0, 0.35],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: NightTint(
                    child: Image.asset(
                      AppImages.friendsFooterScene,
                      fit: BoxFit.fitWidth,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FantasyTitleBar(
                  title: AppStrings.selectRoomTitle,
                  leading: FramedIconButton(
                    icon: Icons.arrow_back,
                    tooltip: AppStrings.backButton,
                    onPressed: () => AppNav.back(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    children: [
                      _RoomCard(
                        imagePath: AppImages.tavernRoom,
                        name: AppStrings.tavernRoomName,
                        details: AppStrings.tavernRoomDetails(
                          _tavernPlayers,
                          RoomService.maxPlayers,
                        ),
                        isFull: _tavernFull,
                        onJoin: _joinTavern,
                      ),
                      const SizedBox(height: 18),
                      const _ComingSoonTile(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A room in its ornate frame: the map preview, a star banner with the
/// name and live count, and the JOIN button.
class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.imagePath,
    required this.name,
    required this.details,
    required this.isFull,
    required this.onJoin,
  });

  final String imagePath;
  final String name;
  final String details;
  final bool isFull;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return FantasyCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      cornerSize: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map preview inside its own thin frame.
          FantasyCard(
            padding: const EdgeInsets.all(5),
            cornerSize: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                // Slight zoom crops the black edge baked into the map.
                child: Transform.scale(
                  scale: 1.08,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FantasyCard(
            padding: EdgeInsets.zero,
            cornerSize: 16,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Image.asset(
                        AppImages.compassStar,
                        width: 40,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toUpperCase(),
                              style: FantasyText.title(size: 19),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              details,
                              style: FantasyText.name(
                                size: 14,
                                color: AppColors.inkMuted,
                              ).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FantasyButton(
            label: isFull ? AppStrings.roomFullButton : AppStrings.joinButton,
            leading: isFull
                ? null
                : Image.asset(
                    AppImages.sword,
                    width: 28,
                    filterQuality: FilterQuality.medium,
                  ),
            showChevron: !isFull,
            height: 62,
            onPressed: isFull ? null : onJoin,
          ),
        ],
      ),
    );
  }
}

/// Dashed placeholder with a locked signpost for rooms that aren't open.
class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.moreRoomsComingSoon,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: SizedBox(
          height: 170,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LockedSign(),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.moreRoomsComingSoon,
                      textAlign: TextAlign.center,
                      style: FantasyText.name(
                        size: 13.5,
                        color: AppColors.inkMuted,
                      ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),
                    NightTint(
                      lineArt: true,
                      child: Image.asset(
                        AppImages.ornamentDivider,
                        width: 150,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A little wooden signboard hanging from a bar, with a padlock on it.
class _LockedSign extends StatelessWidget {
  const _LockedSign();

  static const _wood = Color(0xFFD9B98A);
  static const _woodDark = Color(0xFF8A6A4A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 64,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // The bar it hangs from.
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: _wood,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.frameBrown, width: 1.5),
            ),
          ),
          // Two short chains.
          Positioned(
            top: 9,
            left: 18,
            child: Container(width: 2, height: 8, color: AppColors.frameBrown),
          ),
          Positioned(
            top: 9,
            right: 18,
            child: Container(width: 2, height: 8, color: AppColors.frameBrown),
          ),
          // The board with its lock.
          Positioned(
            top: 16,
            child: Container(
              width: 56,
              height: 46,
              decoration: BoxDecoration(
                color: _wood,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.frameBrown, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.lock, size: 24, color: _woodDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.frameBrown.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(10),
        ),
      );

    for (final metric in border.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 6 < metric.length ? distance + 6 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
