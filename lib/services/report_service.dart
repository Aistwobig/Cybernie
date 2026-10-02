import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a player is being reported. The label is shown to the reporter and
/// stored as the start of the report's reason.
enum ReportReason {
  harassment('Harassment or bullying'),
  inappropriate('Inappropriate name, photo or messages'),
  spam('Spam or scams'),
  impersonation('Pretending to be someone else'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

/// Files reports into public.reports. Players can create reports but never
/// read them back; they're reviewed in the Supabase dashboard
/// (Table Editor > reports).
class ReportService {
  ReportService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> reportPlayer({
    required String reportedId,
    required String roomId,
    required ReportReason reason,
    String details = '',
  }) {
    final extra = details.trim();
    final text = extra.isEmpty ? reason.label : '${reason.label}: $extra';
    return _client.from('reports').insert({
      'reporter_id': _client.auth.currentUser!.id,
      'reported_id': reportedId,
      'room_id': roomId,
      // The reports table allows up to 500 characters.
      'reason': text.length > 500 ? text.substring(0, 500) : text,
    });
  }
}
