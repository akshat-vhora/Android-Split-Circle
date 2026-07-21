import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/expenses_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/badge_widget.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/constants/categories.dart';
import '../../../services/supabase_service.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});
  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final _scrollController = ScrollController();
  int _page = 0;
  final List<ExpenseModel> _allExpenses = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 20;
  bool _initialLoading = true;
  int _filter = 0;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  String? get _dateError {
    if (_filterStartDate != null &&
        _filterEndDate != null &&
        _filterStartDate!.isAfter(_filterEndDate!)) {
      return 'Start date must be before end date';
    }
    return null;
  }

  void _swapIfInvalid() {
    if (_filterStartDate != null &&
        _filterEndDate != null &&
        _filterStartDate!.isAfter(_filterEndDate!)) {
      final temp = _filterStartDate;
      _filterStartDate = _filterEndDate;
      _filterEndDate = temp;
    }
  }

  static const _filterLabels = ['All', 'You Owe', 'Owes You', 'Settled'];

  List<ExpenseModel> get _filteredExpenses {
    final uid = SupabaseService.instance.currentUid;
    var filtered = _allExpenses.where((e) {
      switch (_filter) {
        case 1:
          return e.paidBy != uid && !e.isFullySettled;
        case 2:
          return e.paidBy == uid && !e.isFullySettled;
        case 3:
          return e.isFullySettled;
        default:
          return true;
      }
    });
    if (_filterStartDate != null) {
      filtered = filtered.where(
        (e) => !e.createdAt.isBefore(_filterStartDate!),
      );
    }
    if (_filterEndDate != null) {
      filtered = filtered.where(
        (e) =>
            !e.createdAt.isAfter(_filterEndDate!.add(const Duration(days: 1))),
      );
    }
    return filtered.toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _page++;
    setState(() => _loadingMore = true);
    ref.read(expensesRefreshProvider.notifier).trigger();
  }

  Future<void> _refresh() async {
    ref.read(expensesRefreshProvider.notifier).trigger();
    setState(() {
      _page = 0;
      _hasMore = true;
      _allExpenses.clear();
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesListProvider((_page, 0)));

    if (expensesAsync.hasValue && (_page == 0 || _loadingMore)) {
      final pageExpenses = expensesAsync.value ?? <ExpenseModel>[];
      _loadingMore = false;
      if (_page == 0) {
        _allExpenses
          ..clear()
          ..addAll(pageExpenses);
        _initialLoading = false;
      } else {
        _allExpenses.addAll(pageExpenses);
        _loadingMore = false;
      }
      if (pageExpenses.length < _pageSize) {
        _hasMore = false;
      }
    }
    if (expensesAsync.hasError) {
      _loadingMore = false;
      _initialLoading = false;
    }

    final expenses = _filteredExpenses;

    // Apply optimistic patches from shared state (badge updates)
    final patches = ref.watch(expensePatchProvider);
    if (patches.isNotEmpty) {
      bool applied = false;
      for (var i = 0; i < _allExpenses.length; i++) {
        final patched = patches[_allExpenses[i].id];
        if (patched != null) {
          _allExpenses[i] = patched;
          applied = true;
        }
      }
      if (applied) {
        ref.read(expensePatchProvider.notifier).clearAll();
        setState(() {});
      }
    }

    if (_initialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
        body: const ShimmerList(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addExpense',
        onPressed: () async {
          final expense = await context.push<ExpenseModel>('/expenses/add');
          if (expense != null && mounted) {
            ref.invalidate(currentUserProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Filter Pills ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: _filterLabels[i],
                      selected: _filter == i,
                      onTap: () => setState(() => _filter = i),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Date Range Row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _filterStartDate,
                    errorText: _dateError,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _filterStartDate ??
                            _filterEndDate ??
                            DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: _filterEndDate ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _filterStartDate = picked;
                          _swapIfInvalid();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'To',
                    value: _filterEndDate,
                    errorText: _dateError,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _filterEndDate ??
                            _filterStartDate ??
                            DateTime.now(),
                        firstDate: _filterStartDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _filterEndDate = picked;
                          _swapIfInvalid();
                        });
                      }
                    },
                  ),
                ),
                if (_filterStartDate != null || _filterEndDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() {
                      _filterStartDate = null;
                      _filterEndDate = null;
                    }),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Expense List ──────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: expenses.isEmpty && _page == 0
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        EmptyState(
                          icon: Icons.receipt_long,
                          title: 'No expenses',
                          subtitle: '',
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: expenses.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= expenses.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        // return _buildCard(expenses[i], onDelete: () {
                        return _AnimatedExpenseCard(
                          // key: ValueKey(expenses[i].id),
                          key: ValueKey('${_filter}_${expenses[i].id}'),
                          child: _buildCard(
                            expenses[i],
                            onDelete: () {
                              ref.invalidate(currentUserProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Deleted successfully'),
                                  backgroundColor: Color(0xFF34D399),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ExpenseModel expense, {VoidCallback? onDelete}) {
    final cat = categoryFromName(expense.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final deleted = await context.push<bool>('/expenses/${expense.id}');
            if (deleted == true && mounted) {
              onDelete?.call();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF16162A).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
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
                      const SizedBox(height: 3),
                      Text(
                        '${formatAmount(expense.totalAmount)} \u00b7 ${formatDate(expense.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _expenseBadge(expense),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expenseBadge(ExpenseModel expense) {
    final uid = SupabaseService.instance.currentUid;
    if (expense.isFullySettled) {
      return BadgeWidget.settled();
    }
    final mySplit = expense.splits[uid];
    if (mySplit != null) {
      if (mySplit.settlementRequestedAt != null) {
        if (mySplit.settled) {
          return BadgeWidget.settled();
        }
        return BadgeWidget.settlementRequested();
      }
      if (mySplit.settled) {
        return BadgeWidget.settled();
      }
    }
    if (expense.paidBy == uid) {
      return BadgeWidget.theyOwe();
    }
    return BadgeWidget.youOwe();
  }
}

// ── Animated Card — slide + fade on mount ───────────────────
// ── Premium Filter Chip ─────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: selected
                ? null
                : (isDark ? const Color(0xFF1C1C2E) : const Color(0xFFEEEEF4)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date Field ──────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String? errorText;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    this.errorText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_month, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          errorText: errorText,
        ),
        child: Text(
          value != null
              ? '${value!.day}/${value!.month}/${value!.year}'
              : 'Any',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AnimatedExpenseCard extends StatefulWidget {
  final Widget child;

  const _AnimatedExpenseCard({super.key, required this.child});

  @override
  State<_AnimatedExpenseCard> createState() => _AnimatedExpenseCardState();
}

class _AnimatedExpenseCardState extends State<_AnimatedExpenseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _size;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _size = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _size, child: widget.child),
      ),
    );
  }
}
