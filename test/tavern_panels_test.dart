import 'package:final_project/screens/tavern_panels.dart';
import 'package:final_project/services/room_service.dart';
import 'package:final_project/utils/last_seen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Who\'s here lists you first and opens other players', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 400,
            child: PlayersPanel(
              myName: 'Mclaren',
              myAvatarUrl: null,
              others: const [
                RoomPlayer(id: 'b', name: 'Mikko', x: 0, y: 0),
                RoomPlayer(id: 'a', name: 'Alice', x: 0, y: 0),
              ],
              onSelect: (id) => opened = id,
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text("Who's here (3 / 20)"), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    // Sorted by name, after you.
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'Mclaren' || d == 'Alice' || d == 'Mikko')
        .toList();
    expect(names, ['Mclaren', 'Alice', 'Mikko']);

    await tester.tap(find.text('Mikko'));
    expect(opened, 'b');
  });

  testWidgets('an empty room says so', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 400,
            child: PlayersPanel(
              myName: 'Mclaren',
              myAvatarUrl: null,
              others: const [],
              onSelect: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining("It's just you"), findsOneWidget);
  });

  test('note times read naturally', () {
    final now = DateTime(2026, 10, 3, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 1)), now), '1 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3 hours ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2 days ago');
  });

  test('only the six emotes are accepted from other players', () {
    expect(RoomService.isEmote('👋'), isTrue);
    expect(RoomService.isEmote('🍕'), isFalse);
    expect(RoomService.isEmote('<script>'), isFalse);
  });
}
