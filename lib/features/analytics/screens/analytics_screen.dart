import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/category_pie_chart.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/constants/categories.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/models/expense_model.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<DateTime, double> _monthlyData = {};
  Map<String, double> _categoryData = {};
  bool _loading = true;
  DateTimeRange? _range;
  final Set<String> _activeCategoryFilters = {};
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.instance.currentUid;
      if (uid.isEmpty) {
        return;
      }
      final expenses = await SupabaseService.instance.getExpenses(
        uid,
        pageSize: 200,
      );
      setState(() {
        _monthlyData = _calculateMonthly(expenses, uid);
        _categoryData = _calculateCategories(expenses, uid);
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<ExpenseModel> _applyFilters(List<ExpenseModel> items) {
    return items.where((e) {
      if (_range != null &&
          (e.createdAt.isBefore(_range!.start) ||
              e.createdAt.isAfter(_range!.end.add(const Duration(days: 1))))) {
        return false;
      }
      if (_activeCategoryFilters.isNotEmpty &&
          !_activeCategoryFilters.contains(e.category)) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<DateTime, double> _calculateMonthly(List<ExpenseModel> items, String uid) {
    final filtered = _applyFilters(items);
    final sixMonths = lastSixMonths();
    final monthly = <DateTime, double>{};
    for (final month in sixMonths) {
      monthly[month] = 0;
    }
    for (final e in filtered) {
      final month = DateTime(e.createdAt.year, e.createdAt.month, 1);
      if (sixMonths.contains(month)) {
        monthly[month] = (monthly[month] ?? 0) + _userShare(e, uid);
      }
    }
    return monthly;
  }

  Map<String, double> _calculateCategories(
    List<ExpenseModel> items,
    String uid,
  ) {
    final filtered = _applyFilters(items);
    final cat = <String, double>{};
    for (final e in filtered) {
      cat[e.category] = (cat[e.category] ?? 0) + _userShare(e, uid);
    }
    return cat;
  }

  double _userShare(ExpenseModel expense, String uid) {
    return expense.splits[uid]?.amount ?? 0;
  }

  bool get _hasActiveFilters =>
      _range != null || _activeCategoryFilters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final balanceAsync = ref.watch(balanceSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              label: Text(
                '${_activeCategoryFilters.length + (_range != null ? 1 : 0)}',
              ),
              child: Icon(
                _showFilters ? Icons.filter_alt_off : Icons.filter_alt_outlined,
              ),
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: _loading
          ? const ShimmerGrid()
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentUserProvider);
                await _load();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: userAsync.when(
                  loading: () => const SizedBox(),
                  error: (e, _) {
                    debugPrint('Analytics error: $e');
                    return const SizedBox();
                  },
                  data: (user) {
                    final totalSpent = _categoryData.values.fold(
                      0.0,
                      (a, b) => a + b,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedCrossFade(
                          firstChild: _buildFilterBar(context, isDark, primary),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _showFilters
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 200),
                        ),
                        const SizedBox(height: 16),
                        _kpiRow(balanceAsync, totalSpent, isDark),
                        const SizedBox(height: 24),
                        _sectionHeader(context, 'Monthly Spending'),
                        const SizedBox(height: 10),
                        GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(16),
                          child: MonthlyBarChart(
                            monthlyData: _monthlyData,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionHeader(context, 'Category Breakdown'),
                        const SizedBox(height: 10),
                        GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(16),
                          child: _categoryData.isEmpty
                              ? _emptyState(
                                  isDark,
                                  'No spending data',
                                  'Add expenses to see your breakdown',
                                )
                              : CategoryPieChart(
                                  categoryData: _categoryData,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C2E).withValues(alpha: 0.75)
            : const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E42) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 16),
              const SizedBox(width: 8),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_range != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _range = null;
                    _onFilterChanged();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _range?.start ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final end = _range?.end ?? DateTime.now();
                      setState(
                        () => _range = DateTimeRange(
                          start: picked,
                          end: end.isBefore(picked) ? picked : end,
                        ),
                      );
                      _onFilterChanged();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'From',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _range != null ? formatDate(_range!.start) : 'Any',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _range?.end ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final start = _range?.start ?? DateTime(2020);
                      setState(
                        () => _range = DateTimeRange(
                          start: start.isAfter(picked) ? picked : start,
                          end: picked,
                        ),
                      );
                      _onFilterChanged();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'To',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _range != null ? formatDate(_range!.end) : 'Any',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Categories',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kCategories.map((cat) {
              final selected = _activeCategoryFilters.contains(cat.name);
              return GestureDetector(
                onTap: () {
                  if (selected) {
                    _activeCategoryFilters.remove(cat.name);
                  } else {
                    _activeCategoryFilters.add(cat.name);
                  }
                  _onFilterChanged();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? cat.color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? cat.color
                          : (isDark
                                ? const Color(0xFF2E2E42)
                                : Colors.grey.shade300),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 14,
                        color: selected ? cat.color : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? cat.color : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(
    AsyncValue<Map<String, double>> balanceAsync,
    double totalSpent,
    bool isDark,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final totals =
        balanceAsync.asData?.value ?? {'totalOwed': 0.0, 'totalOwe': 0.0};
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Total Spent',
            formatAmount(totalSpent),
            Icons.trending_up,
            primary,
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'You Owe',
            formatAmount(totals['totalOwe'] ?? 0),
            Icons.arrow_circle_down,
            const Color(0xFFEF4444),
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Owed',
            formatAmount(totals['totalOwed'] ?? 0),
            Icons.arrow_circle_up,
            const Color(0xFF34D399),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    String label,
    String amount,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.15 : 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9E9EB8) : const Color(0xFF6B6B80),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: isDark ? const Color(0xFF2E2E42) : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9E9EB8) : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9E9EB8) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFilterChanged() {
    final uid = SupabaseService.instance.currentUid;
    if (uid.isEmpty) {
      return;
    }
    SupabaseService.instance.getExpenses(uid, pageSize: 200).then((expenses) {
      if (mounted) {
        setState(() {
          _monthlyData = _calculateMonthly(expenses, uid);
          _categoryData = _calculateCategories(expenses, uid);
        });
      }
    });
  }
}
