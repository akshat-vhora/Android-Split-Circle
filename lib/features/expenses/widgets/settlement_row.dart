import 'package:flutter/material.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/utils/currency_formatter.dart';

class SettlementRow extends StatelessWidget {
  final String name;
  final double amount;
  final VoidCallback onConfirm;

  const SettlementRow({
    super.key,
    required this.name,
    required this.amount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: AvatarWidget(imageUrl: null, name: name, radius: 20),
        title: Text('$name requested settlement'),
        subtitle: Text(formatAmount(amount)),
        trailing: FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirm'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          onPressed: onConfirm,
        ),
      ),
    );
  }
}
