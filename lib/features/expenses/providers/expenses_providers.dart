import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/expenses_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../services/cache_manager.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/constants/cache_durations.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(),
);

class ExpensesRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

final expensesRefreshProvider = NotifierProvider<ExpensesRefreshNotifier, int>(
  ExpensesRefreshNotifier.new,
);

/// Shared optimistic state cache for expense mutations.
/// Screens write patches here after local mutations (settlement, etc.)
/// so other screens can read the updated state without a DB roundtrip.
class ExpensePatchNotifier extends Notifier<Map<String, ExpenseModel>> {
  @override
  Map<String, ExpenseModel> build() => {};

  void patch(ExpenseModel expense) {
    state = {...state, expense.id: expense};
  }

  void remove(String id) {
    state = {...state}..remove(id);
  }

  void clearAll() {
    state = {};
  }
}

final expensePatchProvider =
    NotifierProvider<ExpensePatchNotifier, Map<String, ExpenseModel>>(
      ExpensePatchNotifier.new,
    );

final expensesListProvider = FutureProvider.autoDispose
    .family<List<ExpenseModel>, (int, int)>((ref, params) async {
      ref.watch(expensesRefreshProvider);
      final uid = SupabaseService.instance.currentUid;
      if (uid.isEmpty) return [];
      final page = params.$1;
      final tab = params.$2;
      if (page == 0) {
        cacheManager.touch('expenses', CacheDurations.expenses);
      }
      return ref
          .read(expensesRepositoryProvider)
          .getExpenses(uid, page: page, tab: tab);
    });

final recentExpensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final uid = SupabaseService.instance.currentUid;
  if (uid.isEmpty) return [];
  cacheManager.touch('recentExpenses', CacheDurations.expenses);
  return SupabaseService.instance.getExpenses(uid, pageSize: 10);
});

final expenseDetailProvider = FutureProvider.autoDispose
    .family<ExpenseModel?, String>((ref, id) async {
      cacheManager.touch('expenseDetail_$id', CacheDurations.expenseDetail);
      return SupabaseService.instance.getExpenseById(id);
    });

final awaitingConfirmationProvider = FutureProvider<List<ExpenseModel>>((
  ref,
) async {
  final uid = SupabaseService.instance.currentUid;
  if (uid.isEmpty) return [];
  cacheManager.touch('settlements', CacheDurations.settlements);
  return ref.read(expensesRepositoryProvider).getAwaitingConfirmation(uid);
});
