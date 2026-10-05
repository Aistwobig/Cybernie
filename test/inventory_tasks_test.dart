import 'package:final_project/screens/tavern_panels.dart';
import 'package:final_project/services/inventory_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
    );
  });

  test(
    'bought drinks go to the inventory and are used one at a time',
    () async {
      // Signed out: the inventory lives on the device.
      InventoryService.items.value = const {};
      await InventoryService.added('ale');
      await InventoryService.added('ale');
      await InventoryService.added('cider');
      expect(InventoryService.count('ale'), 2);
      expect(await InventoryService.use('ale'), isTrue);
      expect(InventoryService.count('ale'), 1);
      expect(await InventoryService.use('moon'), isFalse, reason: 'none owned');
      expect(await InventoryService.use('cider'), isTrue);
      expect(InventoryService.items.value.containsKey('cider'), isFalse);
    },
  );

  test('the task "!" stays until every reward is claimed', () {
    TaskService.tasks.value = [
      for (final task in TaskService.all) TaskState(task, done: true),
    ];
    expect(TaskService.allClaimed, isFalse);
    TaskService.tasks.value = [
      for (final task in TaskService.all)
        TaskState(task, done: true, claimed: true),
    ];
    expect(TaskService.allClaimed, isTrue);
  });

  testWidgets('inventory and task panels list their items', (tester) async {
    InventoryService.items.value = const {'ale': 2};
    final used = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: InventoryPanel(onUse: used.add, onClose: () {}),
        ),
      ),
    );
    expect(find.text('Tavern Ale'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    await tester.tap(find.text('USE'));
    expect(used, ['ale']);

    TaskService.tasks.value = [
      TaskState(TaskService.all[0], done: true),
      TaskState(TaskService.all[1]),
      TaskState(TaskService.all[2], done: true, claimed: true),
      TaskState(TaskService.all[3]),
    ];
    final claimed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: TasksPanel(
            onClaim: (id) async => claimed.add(id),
            onClose: () {},
          ),
        ),
      ),
    );
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('Claimed'), findsOneWidget);
    // Only the finished, unclaimed task can be claimed.
    await tester.tap(find.text('CLAIM').first);
    await tester.pump();
    expect(claimed, ['bio']);
  });
}
