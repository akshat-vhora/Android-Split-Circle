import 'package:flutter/material.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/constants/categories.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/widgets/badge_widget.dart';
import '../../../shared/widgets/glass_card.dart';

class RecentExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;

  const RecentExpenseCard({
    super.key,
    required this.expense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryFromName(expense.category);
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(expense.createdAt)} · ${expense.participantUids.length} people',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatAmount(expense.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              expense.isFullySettled
                  ? BadgeWidget.settled()
                  : BadgeWidget.pending(),
            ],
          ),
        ],
      ),
    );
  }
}
