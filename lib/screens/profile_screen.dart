import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_images.dart';
import '../constants/characters.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_nav.dart';
import '../widgets/fantasy_ui.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sprite_walk_preview.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<GameCharacter> _characters = gameCharacters;

  int _selectedCharacter = 1;
  String _playerName = AppStrings.profilePlayerName;
  int _level = 1;
  double _levelProgress = 0;
  bool _saving = false;

  /// A photo picked on this screen (shown immediately, before any upload).
  Uint8List? _profilePhotoBytes;

  /// The saved photo from the player's Supabase profile.
  String? _profilePhotoUrl;
  bool _isPickingProfilePhoto = false;

  final ImagePicker _imagePicker = ImagePicker();

  static const String _photoKey = 'profile_photo';
  static const String _nameKey = 'profile_name';
  static const String _characterKey = 'profile_character';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Signed in: everything comes from the player's Supabase profile, so it
  /// follows their Google account to any device. Signed out (offline dev
  /// runs): falls back to what was saved on this device.
  Future<void> _loadProfile() async {
    if (AuthService.isSignedIn) {
      try {
        final profile = await ProfileService.fetchMine();
        if (!mounted) return;
        setState(() {
          if (profile.displayName.isNotEmpty) {
            _playerName = profile.displayName;
          }
          _profilePhotoUrl = profile.avatarUrl;
          _level = profile.level;
          _levelProgress = profile.levelProgress;
          if (profile.characterIndex < _characters.length) {
            _selectedCharacter = profile.characterIndex;
          }
        });
      } catch (_) {
        // Keep the defaults if the profile can't be loaded.
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final photo = prefs.getString(_photoKey);
    final name = prefs.getString(_nameKey);
    final character = prefs.getInt(_characterKey);
    if (!mounted) return;

    setState(() {
      if (photo != null) _profilePhotoBytes = base64Decode(photo);
      if (name != null && name.isNotEmpty) _playerName = name;
      if (character != null &&
          character >= 0 &&
          character < _characters.length) {
        _selectedCharacter = character;
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    if (AuthService.isSignedIn) {
      setState(() => _saving = true);
      try {
        await ProfileService.updateMine(
          displayName: _playerName,
          characterIndex: _selectedCharacter,
        );
      } catch (_) {
        _showSnack(AppStrings.profileSaveError);
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (_profilePhotoBytes == null) {
        await prefs.remove(_photoKey);
      } else {
        await prefs.setString(_photoKey, base64Encode(_profilePhotoBytes!));
      }
      await prefs.setString(_nameKey, _playerName);
      await prefs.setInt(_characterKey, _selectedCharacter);
    }

    _showSnack(AppStrings.profileSaved);
  }

  /// Just-picked photo first, then the saved one, then a blank person icon
  /// (the same one friends see until a photo is imported).
  Widget _buildAvatarImage() {
    final bytes = _profilePhotoBytes;
    if (bytes != null) {
      return Image.memory(bytes, width: 76, height: 76, fit: BoxFit.cover);
    }
    return PlayerAvatar(photoUrl: _profilePhotoUrl, radius: 38);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Picks a photo and, when signed in, saves it to the player's account
  /// straight away (no need to press Save).
  Future<void> _pickProfilePhoto() async {
    if (_isPickingProfilePhoto) return;
    setState(() => _isPickingProfilePhoto = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _profilePhotoBytes = bytes);

      if (AuthService.isSignedIn) {
        try {
          final url = await ProfileService.uploadAvatar(bytes);
          await ProfileService.updateMine(avatarUrl: url);
          _profilePhotoUrl = url;
          _showSnack(AppStrings.profilePhotoSaved);
        } catch (_) {
          _showSnack(AppStrings.profilePhotoSaveError);
        }
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.profilePhotoPickerError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingProfilePhoto = false);
    }
  }

  Future<void> _editPlayerName() async {
    final controller = TextEditingController(text: _playerName);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.editPlayerName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: AppStrings.playerNameLabel,
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.cancelButton),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text(AppStrings.saveButton),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updatedName != null && updatedName.isNotEmpty && mounted) {
      setState(() => _playerName = updatedName);
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
            child: CastleBackdrop(height: 200),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FantasyTitleBar(
                  title: AppStrings.profileTitle,
                  leading: FramedIconButton(
                    icon: Icons.arrow_back,
                    tooltip: AppStrings.backButton,
                    onPressed: () => AppNav.back(context),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                      children: [
                        _buildPlayerCard(),
                        const SizedBox(height: 12),
                        const StarBanner(
                          title: AppStrings.chooseCharacter,
                          subtitle: AppStrings.chooseCharacterSubtitle,
                        ),
                        const SizedBox(height: 12),
                        _buildCharacterGrid(),
                        const SizedBox(height: 18),
                        FantasyButton(
                          label: AppStrings.saveButton,
                          busy: _saving,
                          onPressed: _saveProfile,
                        ),
                      ],
                    ),
                  ),
                ),
                const FantasyBottomNav(currentIndex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Photo (tap to import), name with an edit button, level and its bar.
  Widget _buildPlayerCard() {
    return FantasyCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: AppStrings.editProfilePicture,
            excludeSemantics: true,
            child: Tooltip(
              message: AppStrings.editProfilePicture,
              child: InkWell(
                onTap: _pickProfilePhoto,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 92,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.card,
                          border: Border.all(
                            color: AppColors.frameBrown,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: SizedBox.square(
                            dimension: 76,
                            child: _buildAvatarImage(),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.card, width: 2),
                          ),
                          child: _isPickingProfilePhoto
                              ? Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.onInk,
                                  ),
                                )
                              : Icon(
                                  Icons.edit,
                                  color: AppColors.onInk,
                                  size: 15,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FantasyText.name(size: 22),
                      ),
                    ),
                    FramedIconButton(
                      icon: Icons.edit,
                      tooltip: AppStrings.editPlayerName,
                      size: 40,
                      onPressed: _editPlayerName,
                    ),
                  ],
                ),
                Text(
                  AppStrings.levelLabel(_level),
                  style: FantasyText.mono(size: 14, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: AppStrings.levelProgress(_level, _levelProgress),
                  child: Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.parchmentDim,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: AppColors.ink.withValues(alpha: 0.2),
                      ),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _levelProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterGrid() {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var index = 0; index < _characters.length; index++)
          _CharacterTile(
            character: _characters[index],
            isSelected: index == _selectedCharacter,
            onTap: () => setState(() => _selectedCharacter = index),
          ),
        _MoreCharactersTile(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.moreCharactersComingSoon)),
          ),
        ),
      ],
    );
  }
}

/// A character in its ornate frame with sparkles; the chosen one is dark.
/// The chosen character, and any character you hover, plays its idle
/// animation facing front; the rest stand still.
class _CharacterTile extends StatefulWidget {
  const _CharacterTile({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final GameCharacter character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CharacterTile> createState() => _CharacterTileState();
}

class _CharacterTileState extends State<_CharacterTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final isSelected = widget.isSelected;
    final onTap = widget.onTap;
    // Idle cycles run at the same pace as in the tavern (0.2 s per frame
    // for 8 frames, whatever the frame count).
    final idleFrame = Duration(microseconds: 200000 * 8 ~/ character.frames);

    return Semantics(
      button: true,
      selected: isSelected,
      label: character.name,
      excludeSemantics: true,
      child: FantasyCard(
        fill: isSelected ? AppColors.selectedTile : AppColors.card,
        padding: EdgeInsets.zero,
        cornerSize: 18,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onHover: (hovering) => setState(() => _hovered = hovering),
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 12,
                  child: _sparkle(14, isSelected ? 0.5 : 0.75),
                ),
                Positioned(
                  right: 12,
                  top: 18,
                  child: _sparkle(11, isSelected ? 0.4 : 0.6),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                  child: Column(
                    children: [
                      Expanded(
                        // The front-facing idle (the walk's first frame
                        // for a character without one).
                        child: SpriteWalkPreview(
                          assetPath: character.idleSheet ?? character.sheet,
                          columns: character.frames,
                          facing: SpriteDirection.south,
                          animate:
                              character.idleSheet != null &&
                              (_hovered || isSelected),
                          frameDuration: idleFrame,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FantasyText.name(
                          size: 14,
                          color: isSelected
                              ? const Color(0xFFF5EFE0)
                              : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sparkle(double size, double opacity) => IgnorePointer(
    child: Opacity(
      opacity: opacity,
      child: NightTint(
        art: true,
        child: Image.asset(
          AppImages.sparkle,
          width: size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}

/// Dashed "+ MORE" placeholder for characters that aren't out yet.
class _MoreCharactersTile extends StatelessWidget {
  const _MoreCharactersTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.moreCharacters,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 30, color: AppColors.ink),
                const SizedBox(height: 4),
                Text(
                  AppStrings.moreCharacters,
                  style: FantasyText.mono(
                    size: 12.5,
                    color: AppColors.inkMuted,
                    weight: FontWeight.w700,
                    spacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.frameBrown.withValues(alpha: 0.6)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(3),
          const Radius.circular(8),
        ),
      );

    for (final metric in border.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 5 < metric.length ? distance + 5 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
