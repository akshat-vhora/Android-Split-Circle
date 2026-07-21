import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/recent_expense_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../services/supabase_service.dart';
import '../../friends/providers/friends_providers.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../../shared/models/expense_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _userNames = {};
  final Set<String> _confirming = {};
  final _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted) {
      return;
    }
    if (_tabController.indexIsChanging) {
      return;
    }
    // Scroll to top on tab switch so the new content starts at the top
    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final awaitingAsync = ref.watch(awaitingConfirmationProvider);
    final balanceAsync = ref.watch(balanceSummaryProvider);

    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Circle'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) {
          debugPrint('Dashboard error: $e');
          return Center(
            child: Text(
              'Could not load dashboard.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
        data: (user) => _buildDashboard(user, awaitingAsync, balanceAsync),
      ),
    );
  }

  Widget _buildDashboard(
    UserModel user,
    AsyncValue<List<ExpenseModel>> awaitingAsync,
    AsyncValue<Map<String, double>> balanceAsync,
  ) {
    final awaitingCount = awaitingAsync.asData?.value.length ?? 0;
    final totals =
        balanceAsync.asData?.value ?? {'totalOwed': 0.0, 'totalOwe': 0.0};

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(balanceSummaryProvider);
        ref.read(expensesRefreshProvider.notifier).trigger();
        ref.invalidate(awaitingConfirmationProvider);
      },
      child: CustomScrollView(
        controller: _mainScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Hero Card ──────────────────────────────
          SliverToBoxAdapter(
            child: _heroCard(
              totals['totalOwed'] ?? 0,
              totals['totalOwe'] ?? 0,
            ),
          ),

          // ── Quick Actions ──────────────────────────
          SliverToBoxAdapter(child: _quickActions()),

          // ── Tab Bar ────────────────────────────────
          SliverToBoxAdapter(child: _buildTabBar(awaitingCount)),

          // ── Tab Content (conditional) ──────────────
          if (_tabController.index == 0)
            ..._buildRecentSlivers()
          else
            ..._buildAwaitingSlivers(awaitingAsync),
        ],
      ),
    );
  }

  // ── Hero Card ─────────────────────────────────────────────
  Widget _heroCard(double totalOwed, double totalOwe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final net = totalOwed - totalOwe;
    final netColor = net > 0
        ? const Color(0xFF34D399)
        : (net < 0 ? const Color(0xFFEF4444) : textMuted);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1C1C2E), const Color(0xFF12121E)]
              : [const Color(0xFFFFFBFA), const Color(0xFFF5F5FA)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
              if (net != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        net > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: netColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        net > 0 ? "You're owed overall" : 'You owe overall',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: netColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            formatAmount(net.abs()),
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: netColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You owe',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatAmount(totalOwe),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Owed',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatAmount(totalOwed),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Actions Row ────────────────────────────────────
  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _actionTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Settle Up',
              color: const Color(0xFF06D6A0),
              onTap: () => context.push('/friends'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionTile(
              icon: Icons.group_add_rounded,
              label: 'Add Friends',
              color: const Color(0xFF42A5F5),
              onTap: () => context.push('/friends/add'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionTile(
              icon: Icons.add_rounded,
              label: 'Add Expense',
              color: Theme.of(context).colorScheme.primary,
              onTap: () async {
                await context.push('/expenses/add');
                ref.invalidate(currentUserProvider);
                ref.read(expensesRefreshProvider.notifier).trigger();
                ref.invalidate(awaitingConfirmationProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? const Color(0xFF1C1C2E).withValues(alpha: 0.75)
          : const Color(0xFFFFFBFA).withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────
  Widget _buildTabBar(int awaitingCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C2E) : const Color(0xFFEEEEF4),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const Text('Recent')],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Awaiting'),
                  if (awaitingCount > 0) ...[
                    const SizedBox(width: 6),
                    _badge(awaitingCount),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFD166),
        ),
      ),
    );
  }

  // ── Recent Tab Slivers ───────────────────────────────────
  List<Widget> _buildRecentSlivers() {
    final expensesAsync = ref.watch(expensesListProvider((0, 0)));

    return expensesAsync.when(
      loading: () => [_buildShimmerSliver()],
      error: (e, _) {
        debugPrint('Recent tab error: $e');
        return [
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Could not load expenses.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ];
      },
      data: (expenses) {
        if (expenses.isEmpty) {
          return [
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.receipt_long,
                title: 'No expenses yet',
                subtitle: "Tap + to add your first expense",
              ),
            ),
          ];
        }
        final count = expenses.length > 5 ? 6 : expenses.length;
        return [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < 5 && index < expenses.length) {
                return RecentExpenseCard(
                  expense: expenses[index],
                  onTap: () => context.push('/expenses/${expenses[index].id}'),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: OutlinedButton(
                  onPressed: () => context.push('/expenses'),
                  child: Text('See all ${expenses.length} expenses'),
                ),
              );
            }, childCount: count),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ];
      },
    );
  }

  // ── Awaiting Tab Slivers ─────────────────────────────────
  List<Widget> _buildAwaitingSlivers(AsyncValue<List<ExpenseModel>> awaitingAsync) {
    return awaitingAsync.when(
      loading: () => [_buildShimmerSliver()],
      error: (e, _) {
        debugPrint('Awaiting tab error: $e');
        return [
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Could not load confirmations.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ];
      },
      data: (expenses) {
        final items = expenses
            .expand(
              (e) => e.splits.entries
                  .where(
                    (entry) =>
                        entry.value.isSettlementRequested &&
                        !entry.value.settled,
                  )
                  .map((entry) => {'expense': e, 'participantUid': entry.key}),
            )
            .toList();
        final uids = items
            .map((e) => e['participantUid'] as String)
            .toSet()
            .toList();
        final missing = uids
            .where((uid) => !_userNames.containsKey(uid))
            .toList();

        // If names haven't been loaded yet, batch-fetch them first
        if (missing.isNotEmpty) {
          _batchLoadNames(missing);
          return [_buildShimmerSliver()];
        }

        if (items.isEmpty) {
          return [
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'All settled',
                subtitle: 'No pending confirmations',
              ),
            ),
          ];
        }

        return [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              final expense = item['expense'] as ExpenseModel;
              final puid = item['participantUid'] as String;
              final name = _userNames[puid]!;
              final confirmKey = '${expense.id}_$puid';
              final isConfirming = _confirming.contains(
                '${confirmKey}_confirm',
              );
              final isRejecting = _confirming.contains('${confirmKey}_reject');
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

              final amount = formatAmount(
                expense.splits[puid]?.amount ?? 0,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16162A).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push('/expenses/${expense.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              imageUrl: null,
                              name: name,
                              radius: 18,
                              fontSize: 14,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        expense.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        amount,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isRejecting)
                                  const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  _compactAction(
                                    icon: Icons.close_rounded,
                                    color: const Color(0xFFEF4444),
                                    onTap: () async {
                                      setState(
                                        () => _confirming.add(
                                          '${confirmKey}_reject',
                                        ),
                                      );
                                      await ref
                                          .read(friendsRepositoryProvider)
                                          .rejectSettlement(expense.id, puid);
                                      ref.invalidate(currentUserProvider);
                                      ref.invalidate(
                                        awaitingConfirmationProvider,
                                      );
                                      ref.invalidate(balanceSummaryProvider);
                                      ref.invalidate(friendBalancesProvider);
                                    },
                                  ),
                                const SizedBox(width: 8),
                                if (isConfirming)
                                  const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  _compactAction(
                                    icon: Icons.check_rounded,
                                    color: const Color(0xFF34D399),
                                    onTap: () async {
                                      setState(
                                        () => _confirming.add(
                                          '${confirmKey}_confirm',
                                        ),
                                      );
                                      await ref
                                          .read(friendsRepositoryProvider)
                                          .confirmSettlement(
                                            expense.id,
                                            SupabaseService.instance.currentUid,
                                            puid,
                                          );
                                      ref.invalidate(currentUserProvider);
                                      ref.invalidate(
                                        awaitingConfirmationProvider,
                                      );
                                      ref.invalidate(balanceSummaryProvider);
                                      ref.invalidate(friendBalancesProvider);
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: items.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ];
      },
    );
  }

  void _batchLoadNames(List<String> uids) {
    Future(() async {
      final users = await SupabaseService.instance.getFriends(uids);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final user in users) {
          _userNames[user.uid] = user.displayName;
        }
        for (final uid in uids) {
          _userNames.putIfAbsent(uid, () => uid);
        }
      });
    });
  }

  Widget _compactAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ── Shimmer (tab loading state) ──────────────────────────
  Widget _buildShimmerSliver() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1E1E30) : Colors.grey.shade300;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        childCount: 5,
      ),
    );
  }
}
