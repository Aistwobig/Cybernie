import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/sfx_service.dart';
import '../utils/app_nav.dart';
import 'dm_banner.dart';

/// The fantasy UI kit: pixel-art frames, castle header, ornate buttons and
/// the bottom bar shared by Home, Friends and Profile. Art lives in
/// assets/images (cut from assets/sheets/ui_sheet.png).

// --- Type -------------------------------------------------------------------

class FantasyText {
  FantasyText._();

  /// Screen titles: FRIENDS, PROFILE.
  static TextStyle title({double size = 28}) => GoogleFonts.cinzel(
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.ink,
  );

  /// Player and character names.
  static TextStyle name({double size = 20, Color? color}) => GoogleFonts.lora(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.ink,
  );

  /// The spaced typewriter text: labels, statuses, hints.
  static TextStyle mono({
    double size = 13,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double spacing = 0.8,
  }) => GoogleFonts.courierPrime(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color ?? AppColors.inkMuted,
  );
}

// --- Framed card --------------------------------------------------------------

/// A parchment card inside the curled-corner pixel frame (frame_card.png).
/// The frame stretches to any size; only its plain middle is stretched, so
/// the corner curls keep their shape.
class FantasyCard extends StatelessWidget {
  const FantasyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.fill,
    this.cornerSize = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Background inside the frame; [AppColors.card] when null.
  final Color? fill;

  /// How big the corner curls are drawn, in logical pixels.
  final double cornerSize;

  /// frame_card.png is 332 x 247 with 66 px corner ornaments.
  static const double _cornerPx = 66;
  static const Rect _centerPx = Rect.fromLTRB(66, 66, 266, 181);

  @override
  Widget build(BuildContext context) {
    final inset = cornerSize * 0.22;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill ?? AppColors.card,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: _AssetImageBuilder(
              asset: AppImages.frameCard,
              builder: (image) => CustomPaint(
                painter: _NineSlicePainter(
                  image: image,
                  centerPx: _centerPx,
                  scale: _cornerPx / cornerSize,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws an image stretched like a nine-patch: the corners stay their size
/// (image pixels / [scale]), the edges and middle stretch.
///
/// Drawn directly with drawImageNine because Flutter's Image(centerSlice:)
/// trips a rounding assertion at some sizes.
class _NineSlicePainter extends CustomPainter {
  _NineSlicePainter({
    required this.image,
    required this.centerPx,
    required this.scale,
  });

  final ui.Image? image;
  final Rect centerPx;
  final double scale;

  /// Night mode's gentler tint for the frame art (null by day).
  final ColorFilter? filter = AppColors.artFilter;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null || size.isEmpty) return;
    canvas.save();
    canvas.scale(1 / scale);
    canvas.drawImageNine(
      img,
      centerPx,
      Offset.zero & (size * scale),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = filter,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NineSlicePainter old) =>
      old.image != image || old.scale != scale || old.filter != filter;
}

/// Loads an asset image once and rebuilds with it (null until decoded).
class _AssetImageBuilder extends StatefulWidget {
  const _AssetImageBuilder({required this.asset, required this.builder});

  final String asset;
  final Widget Function(ui.Image? image) builder;

  @override
  State<_AssetImageBuilder> createState() => _AssetImageBuilderState();
}

class _AssetImageBuilderState extends State<_AssetImageBuilder> {
  ImageStream? _stream;
  ui.Image? _image;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _image = info.image);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_image);
}

// --- Ornate button -----------------------------------------------------------

/// The dark ornate button (frame_button.png) used for JOIN ROOM and SAVE.
/// Its corners and the diamond cluster in the middle keep their shape; only
/// the plain stretches between them grow with the width.
class FantasyButton extends StatelessWidget {
  const FantasyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.showChevron = false,
    this.height = 64,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool showChevron;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    // The button art is dark in both modes, so its text stays day parchment.
    final textColor = const Color(
      0xFFF5EFE0,
    ).withValues(alpha: enabled ? 1 : 0.55);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: _PressScale(
        enabled: enabled,
        child: SizedBox(
          height: height,
          child: _AssetImageBuilder(
            asset: AppImages.frameButton,
            builder: (frame) => CustomPaint(
              painter: _ButtonFramePainter(frame),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          SfxService.play(Sfx.click);
                          onPressed!();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(height * 0.2),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: height * 0.5),
                    child: Row(
                      children: [
                        SizedBox(width: height * 0.55, child: leading),
                        Expanded(
                          child: busy
                              ? Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: textColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cinzel(
                                    fontSize: height * 0.3,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: height * 0.08,
                                    color: textColor,
                                  ),
                                ),
                        ),
                        SizedBox(
                          width: height * 0.55,
                          child: showChevron
                              ? Icon(
                                  Icons.chevron_right,
                                  size: height * 0.42,
                                  color: textColor,
                                )
                              : null,
                        ),
                      ],
                    ),
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

/// Shrinks its child slightly while pressed, so buttons feel physical.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Paints frame_button.png in five vertical strips:
/// corner | stretch | diamonds | stretch | corner.
class _ButtonFramePainter extends CustomPainter {
  _ButtonFramePainter(this.image);

  final ui.Image? image;

  /// Night mode's gentler tint for the button art (null by day).
  final ColorFilter? filter = AppColors.artFilter;

  // Source x-ranges in frame_button.png (658 x 182).
  static const List<(double, double, bool)> _strips = [
    (0, 70, false),
    (70, 280, true),
    (280, 370, false),
    (370, 588, true),
    (588, 658, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final s = size.height / img.height;
    const fixedPx = 70 + 90 + 70;
    final stretchPx = (img.width - fixedPx).toDouble();
    final stretchOut = (size.width - fixedPx * s).clamp(0.0, double.infinity);

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = filter;
    var x = 0.0;
    for (final (from, to, stretches) in _strips) {
      final srcW = to - from;
      final dstW = stretches ? stretchOut * (srcW / stretchPx) : srcW * s;
      // Sample half a pixel inside each strip (so neighbouring pixels don't
      // bleed in) and overlap strips by a pixel, so no seams show.
      canvas.drawImageRect(
        img,
        Rect.fromLTRB(from + 0.5, 0, to - 0.5, img.height.toDouble()),
        Rect.fromLTWH(
          x.floorToDouble(),
          0,
          dstW.ceilToDouble() + 1,
          size.height,
        ),
        paint,
      );
      x += dstW;
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonFramePainter old) =>
      old.image != image || old.filter != filter;
}

// --- Small framed buttons ------------------------------------------------------

/// A square button with a double ink border, as used for +, back, the edit
/// pencil and the dark chevrons on friend rows.
class FramedIconButton extends StatelessWidget {
  const FramedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.dark = false,
    this.size = 44,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool dark;
  final double size;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fill = dark ? AppColors.ink : AppColors.card;
    final foreground = dark ? AppColors.parchment : AppColors.ink;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badgeCount > 0 ? '$tooltip, $badgeCount' : tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size + 6,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Material(
                color: fill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                  side: BorderSide(color: AppColors.ink, width: 1.6),
                ),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox.square(
                    dimension: size,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: foreground.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Icon(icon, size: size * 0.5, color: foreground),
                      ),
                    ),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.card, width: 1.5),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Header -------------------------------------------------------------------

/// The castle skyline across the top of a screen, fading into the parchment.
///
/// The castle sits on the right; the art fades out toward the left (behind
/// the screen title) and toward the bottom, so text never sits on top of
/// busy art.
class CastleBackdrop extends StatelessWidget {
  const CastleBackdrop({super.key, this.height = 190, this.opacity = 0.5});

  final double height;
  final double opacity;

  /// header_castle.png is 1165 x 374; the main castle's centre is at 71%.
  static const double _imageAspect = 1165 / 374;
  static const double _castleCentre = 0.712;

  /// Where the castle's centre lands, as a fraction of the screen width.
  static const double _castleTarget = 0.8;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = height * _imageAspect;
            final left =
                constraints.maxWidth * _castleTarget -
                imageWidth * _castleCentre;
            return ShaderMask(
              // Fade the bottom edge into the page...
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.55, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ShaderMask(
                // ...and the left side, where the title is.
                shaderCallback: (rect) => LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white,
                  ],
                  stops: const [0, 0.42, 0.68],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: left,
                        top: 0,
                        width: imageWidth,
                        height: height,
                        child: NightTint(
                          child: Image.asset(
                            AppImages.headerCastle,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Title row for Friends and Profile: optional leading button, the title
/// with its ornament line and compass star, and an optional trailing button.
class FantasyTitleBar extends StatelessWidget {
  const FantasyTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title.toUpperCase(), style: FantasyText.title()),
              ),
              const SizedBox(height: 4),
              NightTint(
                lineArt: true,
                child: Image.asset(
                  AppImages.ornamentDivider,
                  width: 130,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          NightTint(
            art: true,
            child: Image.asset(
              AppImages.compassStar,
              width: 34,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// A short banner card: compass star, spaced heading and a subtitle line.
class StarBanner extends StatelessWidget {
  const StarBanner({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FantasyCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          NightTint(
            art: true,
            child: Image.asset(
              AppImages.compassStar,
              width: 36,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: FantasyText.mono(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                    spacing: 3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: FantasyText.mono(size: 10, spacing: 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bottom bar ----------------------------------------------------------------

/// Home / Friends / Profile tab bar shared by the three tab screens.
class FantasyBottomNav extends StatelessWidget {
  const FantasyBottomNav({super.key, required this.currentIndex});

  /// 0 = Home, 1 = Friends, 2 = Profile.
  final int currentIndex;

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    SfxService.play(Sfx.click);
    switch (index) {
      case 0:
        AppNav.goHome(context);
      case 1:
        AppNav.goToTab(context, '/friends');
      case 2:
        AppNav.goToTab(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.home_outlined, Icons.home, AppStrings.navHome),
      (Icons.people_outline, Icons.people, AppStrings.navFriends),
      (Icons.person_outline, Icons.person, AppStrings.navProfile),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: 6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 44,
                  color: AppColors.ink.withValues(alpha: 0.12),
                ),
              Expanded(
                child: _NavTab(
                  icon: i == currentIndex ? tabs[i].$2 : tabs[i].$1,
                  label: tabs[i].$3,
                  isActive: i == currentIndex,
                  onTap: () => _go(context, i),
                  badgeUnreadMessages: i == 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeUnreadMessages = false,
  });

  /// Shows how many private messages are unread (the Friends tab).
  final bool badgeUnreadMessages;

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.ink : AppColors.navMuted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 34,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.parchmentDim.withValues(alpha: 0.7)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: badgeUnreadMessages
                    ? DmUnreadBadge(child: Icon(icon, color: color, size: 24))
                    : Icon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(height: 4),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: GoogleFonts.lora(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 1.6,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 8,
              child: isActive
                  ? NightTint(
                      lineArt: true,
                      child: Image.asset(
                        AppImages.ornamentDivider,
                        width: 70,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small light button with the double ink border, for short actions on
/// rows (ADD).
class FramedTextButton extends StatelessWidget {
  const FramedTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: AppColors.ink, width: 1.6),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              constraints: const BoxConstraints(minWidth: 58, minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.ink.withValues(alpha: 0.5)),
              ),
              child: Text(
                label,
                style: FantasyText.mono(
                  size: 13,
                  color: AppColors.ink.withValues(alpha: enabled ? 1 : 0.5),
                  weight: FontWeight.w700,
                  spacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
