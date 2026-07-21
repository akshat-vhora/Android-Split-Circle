import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/user_model.dart';
import '../shared/models/expense_model.dart';
import '../shared/models/friend_balance_model.dart';
import '../shared/constants/supabase_tables.dart';
import '../shared/utils/unique_id_generator.dart';
import '../shared/utils/numeric_utils.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<UserModel> getCurrentUser() async {
    final session = client.auth.currentSession;
    if (session == null) throw Exception('No authenticated user');
    final uid = session.user.id;
    final email = session.user.email ?? '';
    final metadata = session.user.userMetadata;
    final metaName =
        metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        metadata?['display_name'] as String?;
    final res = await client
        .from(SupabaseTables.users)
        .select()
        .eq('uid', uid)
        .maybeSingle();
    if (res != null) {
      return UserModel.fromJson(res);
    }

    final displayName = metaName ?? email.split('@').first;
    var uniqueId = generateUniqueId();
    var attempts = 0;
    while (!await isUniqueIdAvailable(uniqueId) && attempts < 5) {
      uniqueId = generateUniqueId();
      attempts++;
    }
    try {
      await client.from(SupabaseTables.users).insert({
        'uid': uid,
        'display_name': displayName,
        'email': email,
        'unique_id': uniqueId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final existing = await client
            .from(SupabaseTables.users)
            .select()
            .eq('uid', uid)
            .single();
        return UserModel.fromJson(existing);
      }
      rethrow;
    }
    final inserted = await client
        .from(SupabaseTables.users)
        .select()
        .eq('uid', uid)
        .single();
    return UserModel.fromJson(inserted);
  }

  Future<UserModel?> getUserByUid(String uid) async {
    final res = await client
        .from(SupabaseTables.users)
        .select()
        .eq('uid', uid)
        .maybeSingle();
    if (res == null) return null;
    return UserModel.fromJson(res);
  }

  Future<UserModel?> getUserByUniqueId(String uniqueId) async {
    final res = await client.rpc(
      'find_user_by_unique_id',
      params: {'p_unique_id': uniqueId},
    );
    if (res == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<UserModel>> getFriends(List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    final res = await client
        .from(SupabaseTables.users)
        .select()
        .inFilter('uid', friendUids);
    return res.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<String>> getFriendIds(String uid) async {
    final res = await client
        .from(SupabaseTables.friendships)
        .select('user_id,friend_user_id')
        .or('user_id.eq.$uid,friend_user_id.eq.$uid');
    return res
        .map<String>((row) {
          final userId = row['user_id'] as String;
          final friendUserId = row['friend_user_id'] as String;
          return userId == uid ? friendUserId : userId;
        })
        .toSet()
        .toList();
  }

  Future<void> addFriend(String targetUid) async {
    await client.rpc('add_friend_secure', params: {'target_uid': targetUid});
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await client.from(SupabaseTables.users).update(data).eq('uid', uid);
  }

  Future<void> updateUpiId(String uid, String upiId) async {
    await updateUser(uid, {'upi_id': upiId});
  }

  Future<List<ExpenseModel>> getExpenses(
    String uid, {
    int page = 0,
    int pageSize = 20,
    int tab = 0,
  }) async {
    final res = await client.rpc(
      'get_expenses_page',
      params: {
        'p_auth': uid,
        'p_page': page,
        'p_page_size': pageSize,
        'p_tab': tab,
      },
    );
    final list = (res as List)
        .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<List<ExpenseModel>> getAwaitingConfirmation(String uid) async {
    final res = await client.rpc(
      'get_awaiting_confirmation',
      params: {'p_auth': uid},
    );
    final list = (res as List)
        .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final res = await client
        .from(SupabaseTables.expenseLedgerHistoryView)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return ExpenseModel.fromJson(res);
  }

  Future<ExpenseModel> createExpenseWithBalances(
    Map<String, dynamic> data,
  ) async {
    final res = await client.rpc(
      'create_expense_with_balances',
      params: {'p_expense': data},
    );
    return ExpenseModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> deleteExpense(String id) async {
    await client.rpc(
      'delete_expense_with_balances',
      params: {'p_expense_id': id},
    );
  }

  Future<FriendBalanceModel?> getFriendBalance(
    String userId,
    String friendId,
  ) async {
    final res = await client
        .from(SupabaseTables.friendBalanceView)
        .select()
        .eq('user_id', userId)
        .eq('friend_id', friendId)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return FriendBalanceModel.fromJson(res);
  }

  Future<void> requestSettlement(String expenseId) async {
    await client.rpc('request_settlement', params: {'p_expense_id': expenseId});
  }

  Future<void> confirmSettlement(
    String expenseId,
    String participantUid,
  ) async {
    await client.rpc(
      'confirm_settlement',
      params: {'p_expense_id': expenseId, 'p_participant_uid': participantUid},
    );
  }

  Future<void> rejectSettlement(String expenseId, String participantUid) async {
    await client.rpc(
      'reject_settlement',
      params: {'p_expense_id': expenseId, 'p_participant_uid': participantUid},
    );
  }

  Future<Map<String, double>> getBalanceTotals(String uid) async {
    final res = await client
        .from(SupabaseTables.dashboardTotalsView)
        .select('total_owed,total_owe')
        .eq('user_id', uid)
        .maybeSingle();
    return {
      'totalOwed': parseDoubleAmount(res?['total_owed']),
      'totalOwe': parseDoubleAmount(res?['total_owe']),
    };
  }

  Future<void> sendReminder(String expenseId, String targetUserId) async {
    await client.rpc('send_reminder', params: {
      'p_expense_id': expenseId,
      'p_target_user_id': targetUserId,
    });
  }

  Future<int> getReminderCooldown(String expenseId, String targetUserId) async {
    final res = await client.rpc('get_reminder_cooldown', params: {
      'p_expense_id': expenseId,
      'p_target_user_id': targetUserId,
    });
    return (res as num?)?.toInt() ?? 0;
  }

  Future<bool> isUniqueIdAvailable(String uniqueId) async {
    final res = await client
        .from(SupabaseTables.users)
        .select('uid')
        .eq('unique_id', uniqueId)
        .maybeSingle();
    return res == null;
  }

  String get currentUid => client.auth.currentSession?.user.id ?? '';
}


