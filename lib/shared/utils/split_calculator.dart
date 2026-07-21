import '../models/split_detail_model.dart';
import '../models/sub_item_model.dart';

/// Equal split — divides total equally among all participant UIDs
Map<String, SplitDetail> calculateEqualSplit(
  List<String> participantUids,
  double totalAmount,
) {
  return calculateCustomSplit(_allocateEvenly(participantUids, totalAmount));
}

/// Custom split — uses provided amounts map
Map<String, SplitDetail> calculateCustomSplit(
  Map<String, double> amountsPerUid,
) => amountsPerUid.map(
  (uid, amount) =>
      MapEntry(uid, SplitDetail(amount: _round(amount), settled: false)),
);

/// Sub-item based split:
/// 1. Each participant gets their share of assigned sub-items
/// 2. Remaining (total - subItemsTotal) split equally among all
Map<String, SplitDetail> calculateSubItemSplit(
  List<String> participantUids,
  double totalAmount,
  List<SubItem> subItems,
) {
  final Map<String, double> amounts = {
    for (final uid in participantUids) uid: 0.0,
  };

  // Assign sub-item costs
  for (final item in subItems) {
    if (item.assignedTo.isEmpty) continue;
    final perPerson = item.amount / item.assignedTo.length;
    for (final uid in item.assignedTo) {
      amounts[uid] = (amounts[uid] ?? 0) + perPerson;
    }
  }

  // Split remaining equally, assigning the rounding remainder to the last user.
  final subItemTotal = subItems.fold(0.0, (sum, item) => sum + item.amount);
  final remaining = totalAmount - subItemTotal;
  if (remaining > 0) {
    final remainingSplit = _allocateEvenly(participantUids, remaining);
    for (final entry in remainingSplit.entries) {
      amounts[entry.key] = (amounts[entry.key] ?? 0) + entry.value;
    }
  }

  final rounded = _normalizeRemainder(amounts, totalAmount);
  return calculateCustomSplit(rounded);
}

/// Validates that split amounts sum to total
bool validateCustomSplit(Map<String, double> amounts, double total) {
  final sum = amounts.values.fold(0.0, (a, b) => a + b);
  return (sum - total).abs() < 0.01;
}

/// Remaining amount after custom inputs
double remainingAmount(Map<String, double> amounts, double total) {
  final sum = amounts.values.fold(0.0, (a, b) => a + b);
  return total - sum;
}

double _round(double value) => double.parse(value.toStringAsFixed(2));

Map<String, double> _allocateEvenly(
  List<String> participantUids,
  double totalAmount,
) {
  if (participantUids.isEmpty) return {};
  final totalCents = _toCents(totalAmount);
  final base = totalCents ~/ participantUids.length;
  var remainder = totalCents % participantUids.length;
  return {
    for (final uid in participantUids)
      uid: ((base + (remainder-- > 0 ? 1 : 0)) / 100.0),
  };
}

Map<String, double> _normalizeRemainder(
  Map<String, double> amounts,
  double totalAmount,
) {
  if (amounts.isEmpty) return amounts;
  final entries = amounts.entries.toList();
  final normalized = <String, double>{};
  var assignedCents = 0;
  final totalCents = _toCents(totalAmount);

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final cents = i == entries.length - 1
        ? totalCents - assignedCents
        : _toCents(entry.value);
    normalized[entry.key] = cents / 100.0;
    assignedCents += cents;
  }

  return normalized;
}

int _toCents(double value) => (value * 100).round();
