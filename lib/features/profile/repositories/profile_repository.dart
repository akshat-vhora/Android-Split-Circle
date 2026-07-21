import '../../../services/supabase_service.dart';

class ProfileRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<void> updateDisplayName(String uid, String name) async {
    await _supabase.updateUser(uid, {'display_name': name});
  }

  Future<void> updateUpiId(String uid, String upiId) async {
    await _supabase.updateUpiId(uid, upiId);
  }

  Future<void> clearUpiId(String uid) async {
    await _supabase.updateUser(uid, {'upi_id': null});
  }

}
