import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'coin_service.dart';

/// The player's items (drinks bought from Bernie), by item id. Stored in
/// the database (see supabase/migrations/20261010000000_inventory_tasks.sql);
/// signed out, or before that migration is run, they're kept on the device
/// for this session.
class InventoryService {
  InventoryService._();

  static final ValueNotifier<Map<String, int>> items = ValueNotifier(const {});

  /// True while the server keeps the inventory (false: on the device).
  static bool _online = AuthService.isSignedIn;

  static SupabaseClient get _client => Supabase.instance.client;

  static int count(String itemId) => items.value[itemId] ?? 0;

  static Future<void> load() async {
    if (!AuthService.isSignedIn) {
      _online = false;
      return;
    }
    try {
      final result = await _client.rpc<dynamic>('my_items');
      items.value = _parse(result);
      _online = true;
    } catch (error) {
      debugPrint('Inventory: $error');
      _online = false;
    }
  }

  /// A drink was bought: the server already stored it (when online), so
  /// reload; otherwise keep it on the device.
  static Future<void> added(String itemId) async {
    if (_online) {
      await load();
      if (_online) return;
    }
    items.value = {...items.value, itemId: count(itemId) + 1};
  }

  /// Takes one [itemId] out to use it. False if there isn't one.
  static Future<bool> use(String itemId) async {
    if (count(itemId) <= 0) return false;
    if (_online) {
      try {
        final result = await _client.rpc<dynamic>(
          'use_item',
          params: {'p_item': itemId},
        );
        items.value = _parse(result);
        return true;
      } catch (error) {
        debugPrint('Using $itemId: $error');
        return false;
      }
    }
    final next = {...items.value, itemId: count(itemId) - 1}
      ..removeWhere((_, n) => n <= 0);
    items.value = next;
    return true;
  }

  static Map<String, int> _parse(Object? result) => {
    if (result is Map)
      for (final entry in result.entries)
        entry.key as String: (entry.value as num).toInt(),
  };
}

/// One task the player can do for coins.
class TavernTask {
  const TavernTask(this.id, this.title, this.reward);

  final String id;
  final String title;
  final int reward;
}

class TaskState {
  const TaskState(this.task, {this.done = false, this.claimed = false});

  final TavernTask task;
  final bool done;
  final bool claimed;
}

/// Tasks that pay coins once each, when claimed. Rewards must match
/// public.claim_task in the migration.
class TaskService {
  TaskService._();

  static const List<TavernTask> all = [
    TavernTask('bio', 'Write a bio on your Profile', 20),
    TavernTask('photo', 'Add a profile photo', 50),
    TavernTask('friend', 'Add a friend', 10),
    TavernTask('message', 'Send a message', 10),
  ];

  static final ValueNotifier<List<TaskState>> tasks = ValueNotifier([
    for (final task in all) TaskState(task),
  ]);

  /// Every task's reward has been claimed (the "!" goes away).
  static bool get allClaimed => tasks.value.every((t) => t.claimed);

  /// Why the tasks couldn't be loaded (e.g. the migration isn't run), or
  /// null when they loaded fine.
  static final ValueNotifier<String?> problem = ValueNotifier(null);

  static Future<void> load() async {
    if (!AuthService.isSignedIn) {
      problem.value = 'Sign in to do tasks.';
      return;
    }
    try {
      final result = await Supabase.instance.client.rpc<dynamic>('my_tasks');
      final rows = {
        for (final row in (result as List? ?? const []))
          (row as Map)['id'] as String: row,
      };
      tasks.value = [
        for (final task in all)
          TaskState(
            task,
            done: rows[task.id]?['done'] == true,
            claimed: rows[task.id]?['claimed'] == true,
          ),
      ];
      problem.value = null;
    } catch (error) {
      debugPrint('Tasks: $error');
      problem.value = _explain(error);
    }
  }

  /// Claims [taskId]'s coins. Returns null on success, or why it failed.
  static Future<String?> claim(String taskId) async {
    try {
      final coins = await Supabase.instance.client.rpc<dynamic>(
        'claim_task',
        params: {'p_task': taskId},
      );
      CoinService.coins.value = (coins as num).toInt();
      await load();
      return null;
    } catch (error) {
      debugPrint('Claiming $taskId: $error');
      await load();
      return _explain(error);
    }
  }

  static String _explain(Object error) {
    final text = error is PostgrestException ? error.message : '$error';
    if (text.contains('task not done')) return "That task isn't done yet.";
    if (text.contains('already claimed')) return 'Already claimed.';
    if (text.contains('Could not find the function') ||
        text.contains('does not exist')) {
      return 'Tasks need the inventory/tasks database update '
          '(migration 20261010000000).';
    }
    return "Couldn't reach the tavern's ledger. Try again.";
  }
}
