import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/friends_providers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/loading_dialog.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../services/supabase_service.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendUid;
  const FriendDetailScreen({super.key, required this.friendUid});

  Future<void> _payViaUpi(
    BuildContext context,
    String upiId,
    String name,
    double amount,
  ) async {
    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=${amount.toStringAsFixed(2)}&cu=INR',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No UPI app found')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open UPI: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendAsync = ref
        .watch(friendsListProvider)
        .whenOrNull(
          data: (friends) =>
              friends.where((f) => f.uid == friendUid).firstOrNull,
        );
    final balanceAsync = ref
        .watch(friendBalancesProvider)
        .whenOrNull(data: (b) => b[friendUid]);
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(friendAsync?.displayName ?? 'Friend')),
      body: friendAsync == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ── Avatar Hero ────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                        ),
                        child: AvatarWidget(
                          imageUrl: null,
                          name: friendAsync.displayName,
                          radius: 48,
                          fontSize: 50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        friendAsync.displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── Balance Card ───────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'Net Balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _balanceAmount(context, balanceAsync),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Quick Actions ──────────────────────────────
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Pay via UPI (when user owes friend) ────────
                if (balanceAsync != null && balanceAsync.amount < 0)
                  _actionCard(
                    context,
                    icon: Icons.payment_rounded,
                    iconColor: const Color(0xFF126CDE),
                    title: 'Pay via UPI',
                    subtitle: 'Pay ${formatAmount(balanceAsync.absAmount)} to ${friendAsync.displayName}',
                    onTap: () {
                      final upiId = friendAsync.upiId;
                      if (upiId == null || upiId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This friend has not set up their UPI ID yet',
                            ),
                          ),
                        );
                        return;
                      }
                      _payViaUpi(
                        context,
                        upiId,
                        friendAsync.displayName,
                        balanceAsync.absAmount,
                      );
                    },
                  ),

                // ── Remove Friend ──────────────────────────────
                if (balanceAsync != null && balanceAsync.amount != 0)
                  _actionCard(
                    context,
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFFFD166),
                    title: 'Remove Friend',
                    subtitle: 'Settle all balances first',
                    enabled: false,
                  )
                else
                  _actionCard(
                    context,
                    icon: Icons.person_remove_outlined,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Remove Friend',
                    subtitle:
                        'Remove ${friendAsync.displayName} from your friends',
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Remove Friend?'),
                          content: Text(
                            'Remove ${friendAsync.displayName} from your friends?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Remove',
                                style: TextStyle(color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        if (!context.mounted) return;
                        showLoadingDialog(
                          context,
                          message: 'Removing friend...',
                        );
                        try {
                          await ref
                              .read(friendsRepositoryProvider)
                              .removeFriend(
                                SupabaseService.instance.currentUid,
                                friendUid,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Friend removed')),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to remove: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
    );
  }

  Widget _balanceAmount(
    BuildContext context,
    dynamic balanceAsync,
  ) {
    if (balanceAsync == null) {
      return Text(
        'Settled up',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (balanceAsync.amount > 0) {
      return Column(
        children: [
          Icon(Icons.arrow_circle_up, size: 28, color: const Color(0xFF34D399)),
          const SizedBox(height: 8),
          Text(
            'They owe',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF34D399),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatAmount(balanceAsync.amount),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: const Color(0xFF34D399),
            ),
          ),
        ],
      );
    }
    if (balanceAsync.amount < 0) {
      return Column(
        children: [
          Icon(
            Icons.arrow_circle_down,
            size: 28,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 8),
          Text(
            'You owe',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFFEF4444),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatAmount(balanceAsync.absAmount),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      );
    }
    return Text(
      'Settled up',
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? iconColor : muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
        trailing: enabled
            ? Icon(Icons.chevron_right, color: muted, size: 20)
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
