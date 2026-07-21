import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/split_detail_model.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/utils/currency_formatter.dart';

class SplitCard extends StatelessWidget {
  final SplitDetail split;
  final UserModel user;
  final bool isPayer;
  final bool isPayerSplit;
  final bool isCurrentUser;
  final bool isProcessing;
  final VoidCallback? onRequestSettlement;
  final VoidCallback? onConfirmSettlement;
  final VoidCallback? onRejectSettlement;
  final VoidCallback? onRemind;

  const SplitCard({
    super.key,
    required this.split,
    required this.user,
    this.isPayer = false,
    this.isPayerSplit = false,
    this.isCurrentUser = false,
    this.isProcessing = false,
    this.onRequestSettlement,
    this.onConfirmSettlement,
    this.onRejectSettlement,
    this.onRemind,
  });

  Widget _actionButton({
    required Widget icon,
    String? tooltip,
    VoidCallback? onPressed,
  }) {
    if (isProcessing) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(icon: icon, tooltip: tooltip, onPressed: onPressed);
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AvatarWidget(
            imageUrl: null,
            name: user.displayName,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'You' : user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  formatAmount(split.amount),
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isPayerSplit || split.settled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, color: Color(0xFF34D399), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Paid',
                    style: TextStyle(
                      color: const Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (split.isSettlementRequested && isPayer)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                  tooltip: 'Reject settlement',
                  onPressed: onRejectSettlement,
                ),
                _actionButton(
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF34D399),
                    size: 28,
                  ),
                  tooltip: 'Confirm settlement',
                  onPressed: onConfirmSettlement,
                ),
              ],
            )
          else if (split.isSettlementRequested)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.schedule, color: Color(0xFFFFD166), size: 22),
            )
          else if (!isPayer)
            _actionButton(
              icon: Icon(
                Icons.double_arrow_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              tooltip: 'Request settlement',
              onPressed: onRequestSettlement,
            )
          else
            _actionButton(
              icon: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF9E9EB8),
                size: 22,
              ),
              tooltip: 'Send reminder',
              onPressed: onRemind,
            ),
        ],
      ),
    );
  }
}
