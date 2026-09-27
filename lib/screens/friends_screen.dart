import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Friends list screen — the "has friends" state.
/// Shows a search field and a scrollable list of friends with an
/// online/offline status dot. Pair with a separate empty-state widget
/// for when the friends list is empty.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _Friend {
  final String name;
  final bool isOnline;
  final Color avatarColor;

  const _Friend({
    required this.name,
    required this.isOnline,
    required this.avatarColor,
  });
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _navIndex = 1; // Friends tab active on this screen

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // TODO: replace with real friends data from your backend/state layer.
  final List<_Friend> _friends = const [
    _Friend(name: 'Alice', isOnline: true, avatarColor: Color(0xFFB98FD0)),
    _Friend(name: 'Bob', isOnline: false, avatarColor: Color(0xFF7D9BC1)),
    _Friend(name: 'Luna', isOnline: true, avatarColor: Color(0xFFE08FA6)),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onNavTap(int index) async {
    if (index == 0) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacementNamed('/welcome');
      }
      return;
    }

    if (index == _navIndex) return;
    setState(() => _navIndex = index);

    if (index == 2) {
      await Navigator.of(context).pushNamed('/profile');
      if (mounted) setState(() => _navIndex = 1);
    }
  }

  List<_Friend> get _filteredFriends {
    if (_query.trim().isEmpty) return _friends;
    final q = _query.trim().toLowerCase();
    return _friends.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  TextStyle get _titleStyle => GoogleFonts.cinzel(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  TextStyle get _nameStyle => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            // Top bar: "Friends" title + add-friend button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Friends', style: _titleStyle),
                  _AddFriendButton(
                    onTap: () {
                      // TODO: navigate to / open the Add Friends flow.
                      Navigator.of(context).pushNamed('/friends/add');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.18)),
            const SizedBox(height: 10),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 4),

            // Friends list
            Expanded(
              child: _filteredFriends.isEmpty
                  ? _NoResults(query: _query)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      itemCount: _filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        return _FriendRow(
                          friend: friend,
                          nameStyle: _nameStyle,
                          onTap: () {
                            // TODO: navigate to friend profile / chat.
                          },
                        );
                      },
                    ),
            ),

            _buildCustomBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    final dividerColor = AppColors.ink.withValues(alpha: 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: AppColors.ink.withValues(alpha: 0.2)),
        SizedBox(
          height: 2,
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: ColoredBox(
                  color: index == _navIndex
                      ? AppColors.ink.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
              );
            }),
          ),
        ),
        Container(
          color: AppColors.parchment,
          height: 58,
          child: Row(
            children: [
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 0 ? Icons.home : Icons.home_outlined,
                  label: AppStrings.navHome,
                  isActive: _navIndex == 0,
                  onTap: () => _onNavTap(0),
                ),
              ),
              Container(width: 1, height: 42, color: dividerColor),
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 1 ? Icons.people : Icons.people_outline,
                  label: AppStrings.navFriends,
                  isActive: _navIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
              ),
              Container(width: 1, height: 42, color: dividerColor),
              Expanded(
                child: _NavTab(
                  icon: _navIndex == 2 ? Icons.person : Icons.person_outline,
                  label: AppStrings.navProfile,
                  isActive: _navIndex == 2,
                  onTap: () => _onNavTap(2),
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

/// Search field with the fine, squared outline used in the mockup.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.65)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: 'Search friends...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.ink.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 19,
            color: AppColors.ink.withValues(alpha: 0.65),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

/// Small bordered square "+" button used to open the add-friend flow.
class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.55)),
        ),
        child: Icon(Icons.add, size: 18, color: AppColors.ink),
      ),
    );
  }
}

/// One row in the friends list: avatar, name, status dot, chevron.
class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.nameStyle,
    required this.onTap,
  });

  final _Friend friend;
  final TextStyle nameStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = friend.isOnline
        ? const Color(0xFF3DDC84) // online green
        : AppColors.ink.withValues(alpha: 0.55); // offline / dark dot

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.ink.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: friend.avatarColor,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(friend.name, style: nameStyle)),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.ink.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No friends match "$query"',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.ink.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Custom Bottom Nav Tab Item (same look as WelcomeScreen's).
class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.ink
        : AppColors.ink.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
