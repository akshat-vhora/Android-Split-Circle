import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/expenses_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/models/split_detail_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/constants/categories.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../shared/widgets/loading_dialog.dart';
import '../../../services/supabase_service.dart';
import '../../friends/providers/friends_providers.dart';
import '../../auth/providers/auth_providers.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});
  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen>
    with SingleTickerProviderStateMixin {
  ExpenseModel? _expense;
  Map<String, UserModel> _participants = {};
  bool _loading = true;
  final Set<String> _processingSettlements = {};
  late final AnimationController _entranceCtrl;
  late final List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _staggeredAnimations = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(i * 0.12, 0.5 + i * 0.08, curve: Curves.easeOutCubic),
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _processingSettlements.clear();
    try {
      await _fetchExpense();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _entranceCtrl.forward();
      }
    }
  }

  Future<void> _fetchExpense() async {
    try {
      final expense =
          await SupabaseService.instance.getExpenseById(widget.expenseId);
      if (expense != null && mounted) {
        final uids = expense.participantUids;
        final users = await SupabaseService.instance.getFriends(uids);
        setState(() {
          _expense = expense;
          _participants = {for (final u in users) u.uid: u};
          _processingSettlements.clear();
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _processingSettlements.clear();
      });
    }
  }

  UserModel _resolveUser(String uid) {
    return _participants[uid] ??
        UserModel(
          uid: uid,
          displayName: uid,
          email: '',
          uniqueId: '',
          createdAt: DateTime.now(),
        );
  }

  List<_TimelineEvent> _buildTimeline(ExpenseModel expense) {
    final events = <_TimelineEvent>[];
    for (final entry in expense.splits.entries) {
      if (entry.key == expense.paidBy) continue;
      final split = entry.value;
      final name = _resolveUser(entry.key).displayName;
      if (split.settlementRequestedAt != null && !split.settled) {
        events.add(_TimelineEvent(
          type: _TimelineEventType.requested,
          title: '$name requested settlement',
          amount: split.amount,
          timestamp: split.settlementRequestedAt!,
        ));
      }
      if (split.settled && split.settledAt != null) {
        events.add(_TimelineEvent(
          type: _TimelineEventType.confirmed,
          title: 'Settlement confirmed',
          description: '$name settled ${formatAmount(split.amount)}',
          amount: split.amount,
          timestamp: split.settledAt!,
        ));
      }
    }
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: ShimmerList());
    }
    if (_expense == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Expense not found',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final expense = _expense!;
    final cat = categoryFromName(expense.category);
    final currentUid = SupabaseService.instance.currentUid;
    final isPayer = expense.paidBy == currentUid;
    final isCreator = expense.createdBy == currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payerName = _resolveUser(expense.paidBy).displayName;
    final mySplit = expense.splits[currentUid];
    final settled = expense.isFullySettled;
    final hasRequests = expense.hasSettlementRequests;
    final text = Theme.of(context).colorScheme.onSurface;
    final timeline = _buildTimeline(expense);
    final sortedEntries = expense.splits.entries.toList()
      ..sort((a, b) {
        if (a.key == currentUid) return -1;
        if (b.key == currentUid) return 1;
        return 0;
      });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0B14)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: text),
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          AnimatedBuilder(
            animation: _staggeredAnimations[0],
            builder: (context, child) => Opacity(
              opacity: _staggeredAnimations[0].value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - _staggeredAnimations[0].value)),
                child: child,
              ),
            ),
            child: _HeroSection(
              expense: expense,
              cat: cat,
              payerName: payerName,
              isDark: isDark,
              settled: settled,
              hasRequests: hasRequests,
              currentUid: currentUid,
              mySplit: mySplit,
            ),
          ),
          const SizedBox(height: 8),

          if (!isPayer && mySplit != null)
            AnimatedBuilder(
              animation: _staggeredAnimations[1],
              builder: (context, child) => Opacity(
                opacity: _staggeredAnimations[1].value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - _staggeredAnimations[1].value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _PrimaryActionCard(
                  split: mySplit,
                  payerName: payerName,
                  isDark: isDark,
                  onPayViaUpi:
                      mySplit.settled ? null : () => _payViaUpi(expense),
                ),
              ),
            ),

          AnimatedBuilder(
            animation: _staggeredAnimations[2],
            builder: (context, child) => Opacity(
              opacity: _staggeredAnimations[2].value,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - _staggeredAnimations[2].value)),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: _SectionHeader(
                title: 'Participants',
                trailing: expense.splitType == 'equal' ? 'Split equally' : 'Custom split',
              ),
            ),
          ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries.elementAt(index);
              final uid = entry.key;
              final idx = 3 + sortedEntries.indexWhere((e) => e.key == uid);
              final animIdx = idx.clamp(0, _staggeredAnimations.length - 1);
              return AnimatedBuilder(
                animation: _staggeredAnimations[animIdx],
                builder: (context, child) => Opacity(
                  opacity: _staggeredAnimations[animIdx].value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _staggeredAnimations[animIdx].value)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ParticipantCard(
                    user: _resolveUser(uid),
                    split: entry.value,
                    isCurrentUser: uid == currentUid,
                    isPayer: isPayer,
                    isPayerUser: uid == expense.paidBy,
                    isProcessing: _processingSettlements.contains(uid),
                    onRequestSettlement:
                        uid != currentUid || _processingSettlements.contains(uid)
                            ? null
                            : () => _requestSettlement(expense, uid),
                    onConfirmSettlement:
                        _processingSettlements.contains(uid)
                            ? null
                            : () => _confirmSettlement(expense, uid),
                    onRejectSettlement:
                        _processingSettlements.contains(uid)
                            ? null
                            : () => _rejectSettlement(expense, uid),
                    onSendReminder:
                        uid != expense.paidBy && currentUid == expense.paidBy
                            ? () => _sendReminder(expense, uid)
                            : null,
                  ),
                ),
              );
            },
          ),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _staggeredAnimations[4],
              builder: (context, child) => Opacity(
                opacity: _staggeredAnimations[4].value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _staggeredAnimations[4].value)),
                  child: child,
                ),
              ),
              child: const _SectionHeader(title: 'Activity'),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _staggeredAnimations[4],
              builder: (context, child) => Opacity(
                opacity: _staggeredAnimations[4].value,
                child: child,
              ),
              child: _SettlementTimeline(
                events: timeline,
                isDark: isDark,
              ),
            ),
          ],

          if (expense.description != null || expense.notes != null) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _staggeredAnimations[5],
              builder: (context, child) => Opacity(
                opacity: _staggeredAnimations[5].value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _staggeredAnimations[5].value)),
                  child: child,
                ),
              ),
              child: const _SectionHeader(title: 'Notes'),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _staggeredAnimations[5],
              builder: (context, child) => Opacity(
                opacity: _staggeredAnimations[5].value,
                child: child,
              ),
              child: _NotesCard(expense: expense, isDark: isDark),
            ),
          ],

          if (isCreator) ...[
            const SizedBox(height: 28),
            _DangerZone(
              isDark: isDark,
              onDelete: () => _deleteExpense(expense),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _payViaUpi(ExpenseModel expense) async {
    final payer = _participants[expense.paidBy];
    final upiId = payer?.upiId;
    if (upiId == null || upiId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payer has no UPI ID set')),
        );
      }
      return;
    }
    final payerName = payer?.displayName ?? expense.paidBy;
    final mySplit = expense.splits[SupabaseService.instance.currentUid];
    if (mySplit == null) return;
    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payerName)}&am=${mySplit.amount.toStringAsFixed(2)}&cu=INR',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No UPI app found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open UPI: $e')),
        );
      }
    }
  }

  Future<void> _requestSettlement(ExpenseModel expense, String uid) async {
    setState(() => _processingSettlements.add(uid));
    await ref.read(friendsRepositoryProvider).requestSettlement(expense.id, uid);
    setState(() {
      final oldSplit = _expense!.splits[uid];
      if (oldSplit != null) {
        final newSplit = oldSplit.copyWith(
          settlementRequestedAt: DateTime.now(),
          settlementRequestedBy: uid,
        );
        final newSplits = Map<String, SplitDetail>.from(_expense!.splits);
        newSplits[uid] = newSplit;
        _expense = _expense!.copyWith(splits: newSplits);
      }
      _processingSettlements.remove(uid);
    });
    _invalidateAfterMutation();
  }

  Future<void> _confirmSettlement(ExpenseModel expense, String uid) async {
    setState(() => _processingSettlements.add(uid));
    await ref
        .read(friendsRepositoryProvider)
        .confirmSettlement(expense.id, SupabaseService.instance.currentUid, uid);
    _invalidateAfterMutation();
    _fetchExpense();
  }

  Future<void> _rejectSettlement(ExpenseModel expense, String uid) async {
    setState(() => _processingSettlements.add(uid));
    await ref
        .read(friendsRepositoryProvider)
        .rejectSettlement(expense.id, uid);
    _invalidateAfterMutation();
    _fetchExpense();
  }

  void _invalidateAfterMutation() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(balanceSummaryProvider);
    ref.invalidate(friendBalancesProvider);
    ref.invalidate(awaitingConfirmationProvider);
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete expense?',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reverse all balances and notify participants. This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    showLoadingDialog(context, message: 'Deleting...');
    try {
      await ref
          .read(expensesRepositoryProvider)
          .deleteExpense(expense.id, SupabaseService.instance.currentUid);
      ref.invalidate(currentUserProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _sendReminder(ExpenseModel expense, String targetUid) async {
    try {
      await ref.read(friendsRepositoryProvider).sendReminder(expense.id, targetUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder sent')),
      );
    } catch (_) {
      if (!mounted) return;
      final cooldown =
          await ref.read(friendsRepositoryProvider).getReminderCooldown(expense.id, targetUid);
      final min = (cooldown / 60).ceil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Try again after $min min')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TIMELINE EVENT MODEL
// ═══════════════════════════════════════════════════════════════
enum _TimelineEventType { requested, confirmed, rejected }

class _TimelineEvent {
  final _TimelineEventType type;
  final String title;
  final String? description;
  final double amount;
  final DateTime timestamp;

  const _TimelineEvent({
    required this.type,
    required this.title,
    this.description,
    required this.amount,
    required this.timestamp,
  });
}

// ═══════════════════════════════════════════════════════════════
// HERO SECTION
// ═══════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryInfo cat;
  final String payerName;
  final bool isDark;
  final bool settled;
  final bool hasRequests;
  final String currentUid;
  final SplitDetail? mySplit;

  const _HeroSection({
    required this.expense,
    required this.cat,
    required this.payerName,
    required this.isDark,
    required this.settled,
    required this.hasRequests,
    required this.currentUid,
    required this.mySplit,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  cat.color.withValues(alpha: 0.25),
                  cat.color.withValues(alpha: 0.08),
                ]
              : [
                  cat.color.withValues(alpha: 0.2),
                  cat.color.withValues(alpha: 0.06),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cat.color.withValues(alpha: isDark ? 0.35 : 0.2),
                      cat.color.withValues(alpha: isDark ? 0.15 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cat.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    width: 1,
                  ),
                ),
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  expense.title,
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: text,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                settled: settled,
                hasRequests: hasRequests,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final displayAmount = expense.totalAmount * value;
              return Text(
                formatAmount(displayAmount),
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: text,
                  letterSpacing: -1.2,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 12, color: textMuted),
              const SizedBox(width: 4),
              Text(
                'Paid by ',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              Text(
                payerName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 3, height: 3,
                decoration: BoxDecoration(
                  color: textMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                expense.category,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const Spacer(),
              Text(
                timeAgo(expense.createdAt),
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS PILL
// ═══════════════════════════════════════════════════════════════
class _StatusPill extends StatelessWidget {
  final bool settled;
  final bool hasRequests;
  final bool isDark;

  const _StatusPill({
    required this.settled,
    required this.hasRequests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (settled) {
      label = 'Settled';
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
    } else if (hasRequests) {
      label = 'Pending';
      color = const Color(0xFFF59E0B);
      icon = Icons.schedule_rounded;
    } else {
      label = 'Active';
      color = Theme.of(context).colorScheme.primary;
      icon = Icons.circle_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.15),
            color.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIMARY ACTION CARD
// ═══════════════════════════════════════════════════════════════
class _PrimaryActionCard extends StatelessWidget {
  final SplitDetail split;
  final String payerName;
  final bool isDark;
  final VoidCallback? onPayViaUpi;

  const _PrimaryActionCard({
    required this.split,
    required this.payerName,
    required this.isDark,
    this.onPayViaUpi,
  });

  @override
  Widget build(BuildContext context) {
    final settled = split.settled;
    final text = Theme.of(context).colorScheme.onSurface;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accentColor = settled ? const Color(0xFF10B981) : const Color(0xFF126CDE);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: settled
              ? [
                  const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08),
                  const Color(0xFF10B981).withValues(alpha: isDark ? 0.05 : 0.02),
                ]
              : [
                  const Color(0xFF126CDE).withValues(alpha: isDark ? 0.2 : 0.08),
                  const Color(0xFF126CDE).withValues(alpha: isDark ? 0.06 : 0.02),
                ],
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: settled
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF126CDE), const Color(0xFF1E40AF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              settled ? Icons.check_circle_rounded : Icons.wallet_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        settled ? 'Settled' : 'You owe $payerName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final displayAmount = split.amount * value;
                      return Text(
                        formatAmount(displayAmount),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: settled ? const Color(0xFF10B981) : text,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (!settled)
            _CompactSettleButton(
              onTap: onPayViaUpi,
              isDark: isDark,
            ),
          if (settled && split.settledAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                timeAgo(split.settledAt!),
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactSettleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isDark;

  const _CompactSettleButton({this.onTap, required this.isDark});

  @override
  State<_CompactSettleButton> createState() => _CompactSettleButtonState();
}

class _CompactSettleButtonState extends State<_CompactSettleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF126CDE), const Color(0xFF1E40AF)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF126CDE)
                    .withValues(alpha: widget.isDark ? 0.3 : 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payment_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Pay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PARTICIPANT CARD
// ═══════════════════════════════════════════════════════════════
class _ParticipantCard extends StatelessWidget {
  final UserModel user;
  final SplitDetail split;
  final bool isCurrentUser;
  final bool isPayer;
  final bool isPayerUser;
  final bool isProcessing;
  final VoidCallback? onRequestSettlement;
  final VoidCallback? onConfirmSettlement;
  final VoidCallback? onRejectSettlement;
  final VoidCallback? onSendReminder;

  const _ParticipantCard({
    required this.user,
    required this.split,
    required this.isCurrentUser,
    required this.isPayer,
    required this.isPayerUser,
    required this.isProcessing,
    this.onRequestSettlement,
    this.onConfirmSettlement,
    this.onRejectSettlement,
    this.onSendReminder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).colorScheme.onSurface;
    final selected = isCurrentUser && isPayer;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C2E).withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(imageUrl: null, name: user.displayName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCurrentUser ? 'You' : user.displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isPayerUser)
                          _RoleBadge(
                            label: 'Payer',
                            isDark: isDark,
                          ),
                        if (isCurrentUser && !isPayerUser)
                          _RoleBadge(
                            label: 'You',
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isPayer && !isPayerUser && !split.settled)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ShakeWidget(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSendReminder,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              _ParticipantStatus(
                split: split,
                isPayerUser: isPayerUser,
                isProcessing: isProcessing,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FinanceLabel(
                label: 'Share',
                amount: split.amount,
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              if (split.settled || isPayerUser)
                _FinanceLabel(
                  label: 'Paid',
                  amount: split.amount,
                  isDark: isDark,
                  highlight: true,
                ),
              const Spacer(),
              _ActionsInline(
                split: split,
                isPayerUser: isPayerUser,
                isPayer: isPayer,
                isCurrentUser: isCurrentUser,
                isProcessing: isProcessing,
                onRequestSettlement: onRequestSettlement,
                onConfirmSettlement: onConfirmSettlement,
                onRejectSettlement: onRejectSettlement,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  const _ShakeWidget({required this.child});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
    ]).animate(_controller);
    Future.delayed(const Duration(milliseconds: 600), _controller.forward);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_animation.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  const _RoleBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _FinanceLabel extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDark;
  final bool highlight;

  const _FinanceLabel({
    required this.label,
    required this.amount,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAmount(amount),
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: highlight
                ? const Color(0xFF10B981)
                : Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _ParticipantStatus extends StatelessWidget {
  final SplitDetail split;
  final bool isPayerUser;
  final bool isProcessing;

  const _ParticipantStatus({
    required this.split,
    required this.isPayerUser,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (isPayerUser) {
      return _StatusChip(
        icon: Icons.check_circle_rounded,
        label: 'Paid',
        color: const Color(0xFF10B981),
      );
    }

    if (split.settled) {
      return _StatusChip(
        icon: Icons.check_circle_rounded,
        label: 'Paid',
        color: const Color(0xFF10B981),
      );
    }

    if (split.isSettlementRequested) {
      return _StatusChip(
        icon: Icons.schedule_rounded,
        label: 'Pending',
        color: const Color(0xFFF59E0B),
      );
    }

    return _StatusChip(
      icon: Icons.circle_rounded,
      label: 'Owes',
      color: const Color(0xFF126CDE),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.15),
            color.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACTION ROW
// ═══════════════════════════════════════════════════════════════
class _ActionsInline extends StatelessWidget {
  final SplitDetail split;
  final bool isPayerUser;
  final bool isPayer;
  final bool isCurrentUser;
  final bool isProcessing;
  final VoidCallback? onRequestSettlement;
  final VoidCallback? onConfirmSettlement;
  final VoidCallback? onRejectSettlement;
  final bool isDark;

  const _ActionsInline({
    required this.split,
    required this.isPayerUser,
    required this.isPayer,
    required this.isCurrentUser,
    required this.isProcessing,
    required this.isDark,
    this.onRequestSettlement,
    this.onConfirmSettlement,
    this.onRejectSettlement,
  });

  @override
  Widget build(BuildContext context) {
    if (isPayerUser || split.settled || isProcessing) {
      return const SizedBox.shrink();
    }

    if (split.isSettlementRequested && isPayer) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            label: 'Decline',
            color: const Color(0xFFEF4444),
            onTap: onRejectSettlement,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.check_rounded,
            label: 'Confirm',
            color: const Color(0xFF10B981),
            onTap: onConfirmSettlement,
            isDark: isDark,
          ),
        ],
      );
    }

    if (split.isSettlementRequested || isPayer || !isCurrentUser) {
      return const SizedBox.shrink();
    }

    return _ActionButton(
      icon: Icons.double_arrow_rounded,
      label: 'Request',
      color: const Color(0xFF126CDE),
      onTap: onRequestSettlement,
      isDark: isDark,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETTLEMENT TIMELINE
// ═══════════════════════════════════════════════════════════════
class _SettlementTimeline extends StatelessWidget {
  final List<_TimelineEvent> events;
  final bool isDark;

  const _SettlementTimeline({
    required this.events,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C2E).withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(events.length, (i) {
            final event = events[i];
            final isLast = i == events.length - 1;
            return _TimelineRow(
              event: event,
              isLast: isLast,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  final bool isDark;

  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = switch (event.type) {
      _TimelineEventType.requested => Icons.send_rounded,
      _TimelineEventType.confirmed => Icons.check_circle_rounded,
      _TimelineEventType.rejected => Icons.cancel_rounded,
    };
    final color = switch (event.type) {
      _TimelineEventType.requested => const Color(0xFFF59E0B),
      _TimelineEventType.confirmed => const Color(0xFF10B981),
      _TimelineEventType.rejected => const Color(0xFFEF4444),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, size: 14, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (event.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(event.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTES CARD
// ═══════════════════════════════════════════════════════════════
class _NotesCard extends StatelessWidget {
  final ExpenseModel expense;
  final bool isDark;

  const _NotesCard({required this.expense, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasDescription = expense.description != null;
    final hasNotes = expense.notes != null;
    final text = Theme.of(context).colorScheme.onSurface;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (!hasDescription && !hasNotes) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C2E).withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDescription)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expense.description!,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: text,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          if (hasDescription && hasNotes) const SizedBox(height: 16),
          if (hasNotes)
            Text(
              expense.notes!,
              style: TextStyle(
                fontSize: 13,
                color: textMuted,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DANGER ZONE
// ═══════════════════════════════════════════════════════════════
class _DangerZone extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDelete;

  const _DangerZone({
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Expense',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reverse balances and notify participants',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
