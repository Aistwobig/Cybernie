
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<_ProfileCharacter> _characters = [
    _ProfileCharacter(
      name: AppStrings.characterLuna,
      imagePath: AppImages.profileLuna,
    ),
    _ProfileCharacter(
      name: AppStrings.characterRogue,
      imagePath: AppImages.profileRogue,
    ),
    _ProfileCharacter(
      name: AppStrings.characterMage,
      imagePath: AppImages.profileMage,
    ),
    _ProfileCharacter(
      name: AppStrings.characterLily,
      imagePath: AppImages.profileLuna,
    ),
    _ProfileCharacter(
      name: AppStrings.characterDancer,
      imagePath: AppImages.profileRogue,
    ),
  ];

  int _selectedCharacter = 1;
  String _playerName = AppStrings.profilePlayerName;
  Uint8List? _profilePhotoBytes;
  bool _isPickingProfilePhoto = false;

  final ImagePicker _imagePicker = ImagePicker();

  _ProfileCharacter get _activeCharacter => _characters[_selectedCharacter];

  Future<void> _pickProfilePhoto() async {
    if (_isPickingProfilePhoto) return;
    setState(() => _isPickingProfilePhoto = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _profilePhotoBytes = bytes);
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

  void _returnToWelcome() {
    final navigator = Navigator.of(context);
    var foundWelcome = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/welcome') {
        foundWelcome = true;
        return true;
      }
      return route.isFirst;
    });
    if (!foundWelcome) navigator.pushReplacementNamed('/welcome');
  }

  void _openFriends() {
    final navigator = Navigator.of(context);
    var foundFriends = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/friends') {
        foundFriends = true;
        return true;
      }
      return route.isFirst;
    });
    if (!foundFriends) navigator.pushNamed('/friends');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildRule(),
            _buildPlayerSummary(),
            _buildRule(),
            Expanded(child: _buildCharacterPicker()),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                navigator.pushReplacementNamed('/welcome');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 21),
            color: AppColors.ink,
          ),
          Text(
            AppStrings.profileTitle,
            style: GoogleFonts.cinzel(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRule() =>
      Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18));

  Widget _buildPlayerSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Tooltip(
            message: AppStrings.editProfilePicture,
            child: InkWell(
              onTap: _pickProfilePhoto,
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.parchmentSoft,
                    child: ClipOval(
                      child: _profilePhotoBytes == null
                          ? Image.asset(
                              _activeCharacter.imagePath,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              _profilePhotoBytes!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.parchment,
                          width: 2,
                        ),
                      ),
                      child: _isPickingProfilePhoto
                          ? const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 11,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.editPlayerName,
                      onPressed: _editPlayerName,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.ink,
                    ),
                  ],
                ),
                Text(
                  AppStrings.profileLevel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.ink.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.5,
                    minHeight: 8,
                    backgroundColor: AppColors.parchmentDim,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.ink,
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

  Widget _buildCharacterPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.chooseCharacter,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.ink.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 8,
            mainAxisExtent: 72,
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
                  const SnackBar(
                    content: Text(AppStrings.moreCharactersComingSoon),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 36,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.profileSaved)),
              ),
              child: Text(
                AppStrings.saveButton,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final dividerColor = AppColors.ink.withValues(alpha: 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRule(),
        SizedBox(
          height: 2,
          child: Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: ColoredBox(
                  color: index == 2
                      ? AppColors.ink.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: Row(
            children: [
              Expanded(
                child: _ProfileNavTab(
                  icon: Icons.home_outlined,
                  label: AppStrings.navHome,
                  onTap: _returnToWelcome,
                ),
              ),
              Container(width: 1, height: 42, color: dividerColor),
              Expanded(
                child: _ProfileNavTab(
                  icon: Icons.people_outline,
                  label: AppStrings.navFriends,
                  onTap: _openFriends,
                ),
              ),
              Container(width: 1, height: 42, color: dividerColor),
              Expanded(
                child: _ProfileNavTab(
                  icon: Icons.person,
                  label: AppStrings.navProfile,
                  isActive: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

class _ProfileCharacter {
  const _ProfileCharacter({required this.name, required this.imagePath});

  final String name;
  final String imagePath;
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final _ProfileCharacter character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : AppColors.ink;

    return Material(
      color: isSelected ? AppColors.ink : AppColors.parchment,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.ink.withValues(alpha: 0.8)
                  : AppColors.ink.withValues(alpha: 0.72),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                character.imagePath,
                width: 30,
                height: 34,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 2),
              Text(
                character.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreCharactersTile extends StatelessWidget {
  const _MoreCharactersTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
              Text(
                AppStrings.moreCharacters,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink.withValues(alpha: 0.72),
                ),
              ),
            ],
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
      ..color = AppColors.ink.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      );

    for (final metric in border.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 4 < metric.length ? distance + 4 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileNavTab extends StatelessWidget {
  const _ProfileNavTab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.ink
        : AppColors.ink.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
