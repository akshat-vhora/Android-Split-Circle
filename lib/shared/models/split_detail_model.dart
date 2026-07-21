import '../utils/numeric_utils.dart';

class SplitDetail {
  final double amount;
  final bool settled;
  final DateTime? settledAt;
  final String? settledBy;
  final DateTime? settlementRequestedAt;
  final String? settlementRequestedBy;

  const SplitDetail({
    required this.amount,
    required this.settled,
    this.settledAt,
    this.settledBy,
    this.settlementRequestedAt,
    this.settlementRequestedBy,
  });

  factory SplitDetail.fromJson(Map<String, dynamic> json) => SplitDetail(
        amount: parseDoubleAmount(json['amount']),
    settled: json['settled'] as bool? ?? false,
    settledAt: json['settledAt'] != null
        ? DateTime.parse(json['settledAt'] as String)
        : null,
    settledBy: json['settledBy'] as String?,
    settlementRequestedAt: json['settlementRequestedAt'] != null
        ? DateTime.parse(json['settlementRequestedAt'] as String)
        : null,
    settlementRequestedBy: json['settlementRequestedBy'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'settled': settled,
    'settledAt': settledAt?.toIso8601String(),
    'settledBy': settledBy,
    'settlementRequestedAt': settlementRequestedAt?.toIso8601String(),
    'settlementRequestedBy': settlementRequestedBy,
  };

  SplitDetail copyWith({
    double? amount,
    bool? settled,
    DateTime? settledAt,
    String? settledBy,
    DateTime? settlementRequestedAt,
    String? settlementRequestedBy,
  }) => SplitDetail(
    amount: amount ?? this.amount,
    settled: settled ?? this.settled,
    settledAt: settledAt ?? this.settledAt,
    settledBy: settledBy ?? this.settledBy,
    settlementRequestedAt: settlementRequestedAt ?? this.settlementRequestedAt,
    settlementRequestedBy: settlementRequestedBy ?? this.settlementRequestedBy,
  );

  bool get isSettlementRequested => settlementRequestedAt != null && !settled;
}
