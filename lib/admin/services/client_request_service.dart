import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_client_request.dart';

class ClientRequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'client_requests';

  // Get all client requests.
  Future<List<AdminClientRequest>> getRequests() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) => AdminClientRequest.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  // Update request status.
  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await _supabase
        .from(_table)
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  // Update internal admin notes.
  Future<void> updateAdminNotes({
    required String id,
    required String notes,
  }) async {
    await _supabase
        .from(_table)
        .update({
          'admin_notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  // Delete a request.
  Future<void> deleteRequest(String id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }
}
