import '../models/profile.dart';

/// "Online", "Active 5 mins ago", "Active 3 hours ago", "Active 2 days ago".
String lastSeenLabel(Profile profile, [DateTime? now]) {
  now ??= DateTime.now();
  if (profile.isOnline(now)) return 'Online';

  final seen = profile.lastSeenAt;
  if (seen == null) return 'Offline';

  final ago = now.difference(seen);
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

  if (ago.inMinutes < 60) {
    return 'Active ${plural(ago.inMinutes.clamp(1, 59), 'min')} ago';
  }
  if (ago.inHours < 24) return 'Active ${plural(ago.inHours, 'hour')} ago';
  if (ago.inDays < 30) return 'Active ${plural(ago.inDays, 'day')} ago';
  return 'Active a long time ago';
}

/// "just now", "5 mins ago", "3 hours ago", "2 days ago", e.g. for notes.
String timeAgo(DateTime then, [DateTime? now]) {
  final ago = (now ?? DateTime.now()).difference(then);
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

  if (ago.inMinutes < 1) return 'just now';
  if (ago.inMinutes < 60) return '${plural(ago.inMinutes, 'min')} ago';
  if (ago.inHours < 24) return '${plural(ago.inHours, 'hour')} ago';
  if (ago.inDays < 30) return '${plural(ago.inDays, 'day')} ago';
  return 'a long time ago';
}
