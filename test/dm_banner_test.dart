import 'package:final_project/models/profile.dart';
import 'package:final_project/services/direct_message_service.dart';
import 'package:final_project/services/dm_notifier.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/dm_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A private message slides in as a banner (anywhere in the app) that
/// opens the conversation, and unread counts show as badges.
void main() {
  setUpAll(() {
    // Tests have no network, so google_fonts can't download fonts.
    final report = reportTestException;
    reportTestException = (details, description) {
      if (details.exception.toString().contains('Failed to load font')) return;
      report(details, description);
    };
  });

  const ashly = Profile(
    id: 'ashly',
    username: 'ashly',
    displayName: 'Ashly',
    avatarUrl: null,
    characterIndex: 0,
    level: 1,
  );

  testWidgets('a new message shows a banner that opens the chat', (
    tester,
  ) async {
    final opened = <String>[];
    void open(Profile friend) => opened.add(friend.id);
    DmNotifier.addOpener(open);
    addTearDown(() => DmNotifier.removeOpener(open));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const DmBannerHost(child: Scaffold(body: SizedBox.expand())),
      ),
    );
    expect(find.text('Ashly'), findsNothing);

    DmNotifier.alert.value = DmAlert(
      from: ashly,
      message: DirectMessage(
        id: 1,
        senderId: 'ashly',
        recipientId: 'me',
        body: 'see you in the tavern?',
        createdAt: DateTime(2026),
      ),
    );
    // Let the banner slide in (or out).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ashly'), findsOneWidget);
    expect(find.text('see you in the tavern?'), findsOneWidget);

    await tester.tap(find.text('see you in the tavern?'));
    // Let the banner slide in (or out).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, ['ashly']);
    expect(DmNotifier.alert.value, isNull, reason: 'the banner closes');

    // It also hides by itself after a few seconds.
    DmNotifier.alert.value = DmAlert(
      from: ashly,
      message: DirectMessage(
        id: 2,
        senderId: 'ashly',
        recipientId: 'me',
        emote: '👋',
        createdAt: DateTime(2026),
      ),
    );
    // Let the banner slide in (or out).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('sent an emote'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(DmNotifier.alert.value, isNull);
  });

  testWidgets('unread messages show as a badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DmUnreadBadge(friendId: 'ashly', child: Icon(Icons.chat)),
          ),
        ),
      ),
    );
    expect(find.text('2'), findsNothing);
    DmNotifier.unread.value = {'ashly': 2, 'bea': 1};
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    // Reading the conversation clears it.
    DmNotifier.markRead('ashly');
    await tester.pump();
    expect(find.text('2'), findsNothing);
    DmNotifier.unread.value = const {};
  });
}
