import '../utils/numeric_utils.dart';

class SubItem {
  final String itemId;
  final String name;
  final double amount;
  final List<String> assignedTo;

  const SubItem({
    required this.itemId,
    required this.name,
    required this.amount,
    required this.assignedTo,
  });

  factory SubItem.fromJson(Map<String, dynamic> json) => SubItem(
    itemId: json['itemId'] as String,
    name: json['name'] as String,
    amount: parseDoubleAmount(json['amount']),
    assignedTo: List<String>.from(json['assignedTo'] as List? ?? []),
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'name': name,
    'amount': amount,
    'assignedTo': assignedTo,
  };

  SubItem copyWith({String? name, double? amount, List<String>? assignedTo}) =>
      SubItem(
        itemId: itemId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        assignedTo: assignedTo ?? this.assignedTo,
      );
}
