import 'split_detail_model.dart';
import '../utils/numeric_utils.dart';

class ExpenseModel {
  final String id;
  final String expenseId;
  final String title;
  final String? description;
  final String category;
  final double totalAmount;
  final String paidBy;
  final String createdBy;
  final DateTime createdAt;
  final String splitType;
  final Map<String, SplitDetail> splits;
  final String? notes;

  const ExpenseModel({
    required this.id,
    required this.expenseId,
    required this.title,
    this.description,
    required this.category,
    required this.totalAmount,
    required this.paidBy,
    required this.createdBy,
    required this.createdAt,
    required this.splitType,
    required this.splits,
    this.notes,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String,
    expenseId: json['expense_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    category: json['category'] as String,
    totalAmount: parseDoubleAmount(json['total_amount']),
    paidBy: json['paid_by'] as String,
    createdBy: json['created_by'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    splitType: json['split_type'] as String? ?? 'equal',
    splits: (json['splits'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, SplitDetail.fromJson(v as Map<String, dynamic>)),
    ),
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'expense_id': expenseId,
    'title': title,
    'description': description,
    'category': category,
    'total_amount': totalAmount,
    'paid_by': paidBy,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'split_type': splitType,
    'splits': splits.map((k, v) => MapEntry(k, v.toJson())),
    'notes': notes,
  };

  bool get isFullySettled => splits.entries
      .where((e) => e.key != paidBy)
      .every((e) => e.value.settled);

  bool get hasSettlementRequests =>
      splits.values.any((s) => s.isSettlementRequested);

  List<String> get participantUids => splits.keys.toList();

  ExpenseModel copyWith({
    Map<String, SplitDetail>? splits,
    String? notes,
  }) => ExpenseModel(
    id: id,
    expenseId: expenseId,
    title: title,
    description: description,
    category: category,
    totalAmount: totalAmount,
    paidBy: paidBy,
    createdBy: createdBy,
    createdAt: createdAt,
    splitType: splitType,
    splits: splits ?? this.splits,
    notes: notes ?? this.notes,
  );
}


