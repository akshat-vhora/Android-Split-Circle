import '../../../services/supabase_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/friend_balance_model.dart';

class FriendsRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<UserModel?> findUserByUniqueId(String uniqueId) async {
    return _supabase.getUserByUniqueId(uniqueId);
  }

  Future<bool> canSendRequest(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return false;
    final friendIds = await _supabase.getFriendIds(currentUid);
    return !friendIds.contains(targetUid);
  }

  Future<void> sendFriendRequest(
    String currentUid,
    String targetUid,
  ) async {
    await _supabase.addFriend(targetUid);
  }

  Future<void> acceptRequest(String currentUid, String fromUid) async {
    await _supabase.addFriend(fromUid);
  }

  Future<void> declineRequest(String currentUid, String fromUid) async {
  }

  Future<List<UserModel>> getFriends(List<String> friendUids) async {
    return _supabase.getFriends(friendUids);
  }

  Future<FriendBalanceModel?> getBalance(String userId, String friendId) async {
    return _supabase.getFriendBalance(userId, friendId);
  }

  Future<void> removeFriend(String currentUid, String friendUid) async {
    if (currentUid.isEmpty || friendUid.isEmpty) {
      throw Exception('User not found');
    }
    await _supabase.client.rpc(
      'remove_friend_secure',
      params: {'target_uid': friendUid},
    );
  }

  Future<void> requestSettlement(String expenseId, String currentUid) async {
    final expense = await _supabase.getExpenseById(expenseId);
    if (expense == null) throw Exception('Expense not found');
    await _supabase.requestSettlement(expenseId);
  }

  Future<void> confirmSettlement(
    String expenseId,
    String payerUid,
    String participantUid,
  ) async {
    final expense = await _supabase.getExpenseById(expenseId);
    if (expense == null) throw Exception('Expense not found');
    // Prevent double-confirm; server RPC is also idempotent.
    if (expense.splits[participantUid]?.settled == true) return;
    if (payerUid != _supabase.currentUid) {
      throw Exception('Only payer can confirm');
    }
    await _supabase.confirmSettlement(expenseId, participantUid);
  }

  Future<void> rejectSettlement(String expenseId, String participantUid) async {
    await _supabase.rejectSettlement(expenseId, participantUid);
  }

  Future<void> sendReminder(String expenseId, String targetUserId) async {
    await _supabase.sendReminder(expenseId, targetUserId);
  }

  Future<int> getReminderCooldown(String expenseId, String targetUserId) async {
    return _supabase.getReminderCooldown(expenseId, targetUserId);
  }
}
