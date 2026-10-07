import 'package:final_project/screens/tavern_panels.dart';
import 'package:final_project/services/room_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Who's here" lists voice chat members first, under their own heading.
void main() {
  setUpAll(() {
    // Tests have no network, so google_fonts can't download fonts.
    final report = reportTestException;
    reportTestException = (details, description) {
      if (details.exception.toString().contains('Failed to load font')) return;
      report(details, description);
    };
  });

  Future<void> show(WidgetTester tester, PlayersPanel panel) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(body: SizedBox(width: 340, height: 600, child: panel)),
        ),
      );

  const others = [
    RoomPlayer(id: 'a', name: 'Ashly', x: 0, y: 0, voice: true, camera: true),
    RoomPlayer(id: 'b', name: 'Bea', x: 0, y: 0),
    RoomPlayer(id: 'c', name: 'Cy', x: 0, y: 0, voice: true),
  ];

  testWidgets('voice chat members are grouped first', (tester) async {
    await show(
      tester,
      PlayersPanel(
        myName: 'Me',
        myAvatarUrl: null,
        others: others,
        onSelect: (_) {},
        onClose: () {},
        meInVoice: true,
        talking: const {'c'},
        myId: 'me',
      ),
    );
    await tester.pump();

    expect(find.text('IN VOICE CHAT (3)'), findsOneWidget);
    expect(find.text('IN THE TAVERN'), findsOneWidget);
    // Me, Ashly and Cy are above the tavern heading; Bea is below it.
    final heading = tester.getTopLeft(find.text('IN THE TAVERN')).dy;
    for (final name in ['Me', 'Ashly', 'Cy']) {
      expect(tester.getTopLeft(find.text(name)).dy, lessThan(heading));
    }
    expect(tester.getTopLeft(find.text('Bea')).dy, greaterThan(heading));
    // Cy is talking, Ashly's camera is on.
    expect(find.byTooltip('Talking'), findsOneWidget);
    expect(find.byTooltip('In voice chat'), findsNWidgets(2));
    expect(find.byTooltip('Camera on'), findsOneWidget);
  });

  testWidgets('no headings while nobody is in voice chat', (tester) async {
    await show(
      tester,
      PlayersPanel(
        myName: 'Me',
        myAvatarUrl: null,
        others: const [RoomPlayer(id: 'b', name: 'Bea', x: 0, y: 0)],
        onSelect: (_) {},
        onClose: () {},
      ),
    );
    await tester.pump();

    expect(find.textContaining('IN VOICE CHAT'), findsNothing);
    expect(find.text('IN THE TAVERN'), findsNothing);
    expect(find.text('Bea'), findsOneWidget);
  });
}
