import 'package:flutter/material.dart';
import '../../../shared/models/sub_item_model.dart';
import '../../../shared/utils/currency_formatter.dart';

class SubItemTile extends StatelessWidget {
  final SubItem item;
  final Map<String, String>? userNames;

  const SubItemTile({
    super.key,
    required this.item,
    this.userNames,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        item.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        formatAmount(item.amount),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: item.assignedTo.isNotEmpty
          ? Text(
              'Assigned to: ${item.assignedTo.map((uid) => userNames?[uid] ?? uid).join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
    );
  }
}
