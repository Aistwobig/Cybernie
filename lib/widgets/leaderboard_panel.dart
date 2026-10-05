import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_strings.dart';
import '../services/leaderboard_service.dart';
import 'coin_chip.dart';
import 'player_avatar.dart';

/// The richest players, by coins.
class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<LeaderboardPanel> {
  late final Future<List<LeaderboardEntry>> _entries = LeaderboardService.top();

  @override
  Widget build(BuildContext context) {
    final myId = LeaderboardService.myId;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF21B1712),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4A86A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 18,
                  color: Color(0xFFFFC966),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.leaderboardTitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFE3A3),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.closeButton,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFFF5EFE0),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4A86A),
                      ),
                    ),
                  );
                }
                final entries = snapshot.data;
                if (entries == null || entries.isEmpty) {
                  return Center(
                    child: Text(
                      snapshot.hasError
                          ? AppStrings.leaderboardError
                          : AppStrings.leaderboardEmpty,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xCCF5EFE0),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _LeaderboardRow(
                    rank: i + 1,
                    entry: entries[i],
                    isMe: entries[i].id == myId || entries[i].id == 'me',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  static const List<Color> _medals = [
    Color(0xFFFFC94D), // gold
    Color(0xFFD9DEE6), // silver
    Color(0xFFD9915A), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? const Color(0x33FFC966) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: rank <= 3
                ? Icon(Icons.emoji_events, size: 16, color: _medals[rank - 1])
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xCCF5EFE0),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(photoUrl: entry.avatarUrl, radius: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '${entry.name} ${AppStrings.leaderboardYou}' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFFF5EFE0),
              ),
            ),
          ),
          const CoinIcon(size: 14),
          const SizedBox(width: 5),
          Text(
            '${entry.coins}',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              height: 1,
              color: Color(0xFFFFE3A3),
            ),
          ),
        ],
      ),
    );
  }
}
