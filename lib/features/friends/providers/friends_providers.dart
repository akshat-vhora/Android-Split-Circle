import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/friends_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../services/cache_manager.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/friend_balance_model.dart';
import '../../../shared/constants/cache_durations.dart';
import '../../../shared/constants/supabase_tables.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(),
);

class FriendsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

final friendsRefreshProvider = NotifierProvider<FriendsRefreshNotifier, int>(
  FriendsRefreshNotifier.new,
);

final friendsListProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  ref.watch(friendsRefreshProvider);
  final uid = SupabaseService.instance.currentUid;
  if (uid.isEmpty) return [];
  cacheManager.touch('friends', CacheDurations.friends);
  final friendIds = await SupabaseService.instance.getFriendIds(uid);
  return ref.read(friendsRepositoryProvider).getFriends(friendIds);
});

final friendBalancesProvider =
    FutureProvider.autoDispose<Map<String, FriendBalanceModel>>((ref) async {
      final uid = SupabaseService.instance.currentUid;
      if (uid.isEmpty) return {};
      final results = await SupabaseService.instance.client
          .from(SupabaseTables.friendBalanceView)
          .select()
          .eq('user_id', uid);
      final balances = <String, FriendBalanceModel>{};
      for (final row in results) {
        final model = FriendBalanceModel.fromJson(row);
        balances[model.friendId] = model;
      }
      return balances;
    });
