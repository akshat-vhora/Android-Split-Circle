import 'package:uuid/uuid.dart';

import '../../../services/supabase_service.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/models/split_detail_model.dart';

class ExpensesRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<ExpenseModel> createExpense({
    required String title,
    String? description,
    required String category,
    required double totalAmount,
    required String paidBy,
    required String createdBy,
    required String splitType,
    required Map<String, SplitDetail> splits,
    String? notes,
    DateTime? expenseDate,
  }) async {
    final expenseId = const Uuid().v4();
    final data = {
      'expense_id': expenseId,
      'title': title,
      'description': description,
      'category': category,
      'total_amount': totalAmount,
      'paid_by': paidBy,
      'created_by': createdBy,
      'split_type': splitType,
      'splits': splits.map((k, v) => MapEntry(k, v.toJson())),
      'notes': notes,
      'created_at': expenseDate != null
          ? DateTime.utc(expenseDate.year, expenseDate.month, expenseDate.day).toIso8601String()
          : DateTime.now().toUtc().toIso8601String(),
    };
    return _supabase.createExpenseWithBalances(data);
  }

  Future<List<ExpenseModel>> getExpenses(
    String uid, {
    int page = 0,
    int pageSize = 20,
    int tab = 0,
  }) async {
    return _supabase.getExpenses(uid, page: page, pageSize: pageSize, tab: tab);
  }

  Future<List<ExpenseModel>> getAwaitingConfirmation(String uid) async {
    return _supabase.getAwaitingConfirmation(uid);
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    return _supabase.getExpenseById(id);
  }

  Future<void> deleteExpense(String id, String uid) async {
    final expense = await _supabase.getExpenseById(id);
    if (expense == null) throw Exception('Expense not found');
    if (expense.createdBy != uid) throw Exception('Only creator can delete');
    await _supabase.deleteExpense(id);
  }
}
