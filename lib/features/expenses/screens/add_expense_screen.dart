import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/expenses_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/split_detail_model.dart';
import '../../../shared/models/sub_item_model.dart';
import '../../../shared/constants/categories.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/split_calculator.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../services/supabase_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _loading = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Food';
  DateTime _expenseDate = DateTime.now();

  List<UserModel> _friends = [];
  final List<String> _selectedUids = [];

  final List<SubItem> _subItems = [];
  String _friendSearchQuery = '';

  final Map<String, double> _customAmounts = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final Set<String> _lockedParticipants = {};
  String _splitSeedKey = '';

  static const _stepLabels = ['Details', 'People', 'Items', 'Split', 'Review'];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final uid = SupabaseService.instance.currentUid;
      final friendIds = await SupabaseService.instance.getFriendIds(uid);
      final friends = await SupabaseService.instance.getFriends(friendIds);
      if (mounted) {
        setState(() => _friends = friends);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _titleError;
  String? _amountError;
  String? _participantsError;

  /// Payer first, then each selected friend once (avoids double-counting balances
  /// and totals if the payer uid was also selected or the list had duplicates).
  List<String> _participantUidsForExpense() {
    final payer = SupabaseService.instance.currentUid;
    final out = <String>[payer];
    final seen = <String>{payer};
    for (final id in _selectedUids) {
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      out.add(id);
    }
    return out;
  }

  bool _validateStep() {
    setState(() {
      _titleError = null;
      _amountError = null;
      _participantsError = null;
    });
    if (_step == 0) {
      if (_titleController.text.trim().isEmpty) {
        setState(() => _titleError = 'Enter a title');
        return false;
      }
      final amt = double.tryParse(_amountController.text) ?? 0;
      if (_amountController.text.isEmpty || amt <= 0) {
        setState(() => _amountError = 'Enter a valid amount');
        return false;
      }
      if (amt > 1000000) {
        setState(() => _amountError = 'Maximum is ₹10,00,000');
        return false;
      }
      return true;
    }
    if (_step == 1) {
      return true;
    }
    if (_step == 2) {
      final subTotal = _subItems.fold(0.0, (sum, item) => sum + item.amount);
      if (subTotal > (double.tryParse(_amountController.text) ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sub-items total cannot exceed expense total'),
          ),
        );
        return false;
      }
      return true;
    }
    if (_step == 3) {
      if (_subItems.isEmpty) {
        final total = double.tryParse(_amountController.text) ?? 0;
        final splits = _splitAmounts(_participantUidsForExpense());
        final assigned = splits.values.fold(0.0, (s, a) => s + a);
        if (splits.values.any((amount) => amount < 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Split amounts cannot be negative')),
          );
          return false;
        }
        if ((total - assigned).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Split amounts must add up to the total'),
            ),
          );
          return false;
        }
      }
      return true;
    }
    return true;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_validateStep()) {
      return;
    }
    if (_step < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.instance.currentUid;
      final total = double.parse(_amountController.text);
      if (total > 1000000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum expense amount is ₹10,00,000'),
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }
      final allParticipants = _participantUidsForExpense();
      Map<String, SplitDetail> splits;

      if (_subItems.isNotEmpty) {
        splits = calculateSubItemSplit(allParticipants, total, _subItems);
      } else {
        splits = calculateCustomSplit(_splitAmounts(allParticipants));
      }

      final totalAssigned = splits.values.fold(0.0, (s, v) => s + v.amount);
      if (splits.values.any((split) => split.amount < 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Split amounts cannot be negative')),
          );
        }
        setState(() => _loading = false);
        return;
      }
      if ((total - totalAssigned).abs() > 0.01) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Split amounts must equal the total')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final createdExpense = await ref
          .read(expensesRepositoryProvider)
          .createExpense(
            title: _titleController.text.trim(),
            description: _descController.text.isNotEmpty
                ? _descController.text
                : null,
            category: _category,
            totalAmount: total,
            paidBy: uid,
            createdBy: uid,
            splitType: _subItems.isNotEmpty ? 'subitem' : 'custom',
            splits: splits,
            expenseDate: _expenseDate,
          );

      // Notifications — catch separately, non-fatal

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense added!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        context.pop(createdExpense);
      }
    } catch (e) {
      debugPrint('Add expense error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add expense. Please try again.'),
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Expense',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _stepIndicator(primary, isDark),
          if (_step != 4) const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _step1(isDark),
                _step2(isDark),
                _step3(isDark),
                _step4(isDark),
                _step5(isDark),
              ],
            ),
          ),
          _bottomNav(primary, isDark),
        ],
      ),
    );
  }

  Widget _stepIndicator(Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: List.generate(5, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          final bgColor = isDone
              ? primary
              : (isActive
                    ? primary.withValues(alpha: 0.2)
                    : (isDark
                          ? const Color(0xFF2E2E42)
                          : Colors.grey.shade200));
          final textColor = isDone
              ? Colors.white
              : (isActive
                    ? primary
                    : (isDark
                          ? const Color(0xFF9E9EB8)
                          : Colors.grey.shade600));
          final labelColor = isActive
              ? Theme.of(context).colorScheme.onSurface
              : (isDark ? const Color(0xFF9E9EB8) : Colors.grey.shade500);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i <= _step
                              ? primary
                              : (isDark
                                    ? const Color(0xFF2E2E42)
                                    : Colors.grey.shade200),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                      ),
                    ),
                    if (i < 4)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < _step
                              ? primary
                              : (isDark
                                    ? const Color(0xFF2E2E42)
                                    : Colors.grey.shade200),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _stepLabels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _bottomNav(Color primary, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E2E42) : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : _back,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: _step == 0 ? 1 : 2,
            child: FilledButton(
              onPressed: _loading ? null : _next,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_step == 4 ? 'Save Expense' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step1(bool isDark) {
    final surfaceVariant = isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFF5F5FA);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense Details',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'What for?',
              hintText: 'e.g. Dinner, Groceries, Uber',
              prefixIcon: const Icon(Icons.edit_outlined),
              errorText: _titleError,
            ),
            maxLength: 60,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCategories.map((cat) {
              final selected = _category == cat.name;
              return GestureDetector(
                onTap: () => setState(() => _category = cat.name),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? cat.color.withValues(alpha: 0.15)
                        : surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? cat.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 16,
                        color: selected ? cat.color : null,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 13,
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
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Total Amount',
              prefixIcon: const Icon(Icons.money_rounded),
              errorText: _amountError,
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expenseDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _expenseDate = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                prefixIcon: const Icon(Icons.calendar_month),
                errorText: null,
              ),
              child: Text(
                '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _step2(bool isDark) {
    final selectedFriends = _friends
        .where((f) => _selectedUids.contains(f.uid))
        .toList();
    final uid = SupabaseService.instance.currentUid;
    final filtered = _friends
        .where(
          (f) =>
              _friendSearchQuery.isEmpty ||
              f.displayName.toLowerCase().contains(_friendSearchQuery),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who\'s involved?',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You + ${_selectedUids.toSet().length} selected',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _participantAvatar(null, 'You', uid),
                const SizedBox(width: 8),
                ...selectedFriends.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _participantAvatar(
                      null,
                      f.displayName,
                      f.uid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_participantsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _participantsError!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _friendSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _friendSearchQuery = ''),
                    )
                  : null,
            ),
            onChanged: (v) =>
                setState(() => _friendSearchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 8),
          ...filtered.map((f) {
            final selected = _selectedUids.contains(f.uid);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: isDark
                  ? const Color(0xFF1C1C2E).withValues(alpha: 0.75)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  if (selected) {
                    _selectedUids.remove(f.uid);
                  } else if (!_selectedUids.contains(f.uid)) {
                    _selectedUids.add(f.uid);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        imageUrl: null,
                        name: f.displayName,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark
                                  ? const Color(0xFF2E2E42)
                                  : Colors.grey.shade300),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _participantAvatar(String? url, String name, String? uid) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarWidget(imageUrl: url, name: name, radius: 22),
        const SizedBox(height: 4),
        SizedBox(
          width: 48,
          child: Text(
            name,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _step3(bool isDark) {
    final total = double.tryParse(_amountController.text) ?? 0;
    final subItemTotal = _subItems.fold(0.0, (s, item) => s + item.amount);
    final remaining = total - subItemTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sub-Items',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Break down the bill into items',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatAmount(total),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatAmount(remaining),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: remaining == 0
                              ? const Color(0xFF34D399)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _selectedUids.isEmpty ? null : _addSubItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_subItems.isEmpty)
            GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 40,
                      color: isDark
                          ? const Color(0xFF2E2E42)
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No items yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Skip to set a custom split',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._subItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final assignedNames = item.assignedTo
                  .map(
                    (uid) =>
                        _friends
                            .where((f) => f.uid == uid)
                            .firstOrNull
                            ?.displayName ??
                        uid,
                  )
                  .join(', ');
              return GlassCard(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            assignedNames,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatAmount(item.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _subItems.removeAt(i)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _step4(bool isDark) {
    final uid = SupabaseService.instance.currentUid;
    final total = double.tryParse(_amountController.text) ?? 0;
    final allParticipants = _participantUidsForExpense();
    _syncCustomControllers(allParticipants, total);

    if (_subItems.isNotEmpty) {
      final splits = calculateSubItemSplit(allParticipants, total, _subItems);
      return _splitPreview(splits, uid, allParticipants, isDark);
    }

    return _customSplitEditor(uid, total, allParticipants, isDark);
  }

  Widget _splitPreview(
    Map<String, SplitDetail> splits,
    String uid,
    List<String> allParticipants,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Preview',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated from sub-items',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...splits.entries.map(
            (entry) => _splitRow(entry.key, entry.value.amount, uid, isDark),
          ),
        ],
      ),
    );
  }

  Widget _customSplitEditor(
    String uid,
    double total,
    List<String> allParticipants,
    bool isDark,
  ) {
    final splits = _splitAmounts(allParticipants);
    final assigned = splits.values.fold(0.0, (s, a) => s + a);
    final delta = total - assigned;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Custom Split',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
                onPressed: () =>
                    setState(() => _setEqualSplit(allParticipants, total)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: delta.abs() < 0.01
                      ? const Color(0xFF34D399).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delta.abs() < 0.01
                      ? 'Balanced'
                      : '${formatAmount(delta.abs())} ${delta > 0 ? 'left' : 'over'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: delta.abs() < 0.01
                        ? const Color(0xFF34D399)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...allParticipants.map(
            (puid) => _splitRow(
              puid,
              _customAmounts[puid] ?? 0,
              uid,
              isDark,
              editable: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitRow(
    String puid,
    double amount,
    String currentUid,
    bool isDark, {
    bool editable = false,
  }) {
    final isYou = puid == currentUid;
    final friend = isYou
        ? null
        : _friends.where((f) => f.uid == puid).firstOrNull;
    // final displayName = friend?.displayName ?? puid;
    final displayName = isYou ? 'You' : (friend?.displayName ?? 'Unknown User');

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          AvatarWidget(imageUrl: null, name: displayName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isYou ? 'You' : displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Payer',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (editable)
            SizedBox(
              width: 90,
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '$kCurrencySymbol ',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: _amountControllers[puid],
                onChanged: (_) => _redistributeSplitFrom(
                  puid,
                  _participantUidsForExpense(),
                  double.tryParse(_amountController.text) ?? 0,
                ),
              ),
            )
          else
            Text(
              formatAmount(amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _step5(bool isDark) {
    final uid = SupabaseService.instance.currentUid;
    final total = double.tryParse(_amountController.text) ?? 0;
    final allParticipants = _participantUidsForExpense();
    final splits = _subItems.isNotEmpty
        ? calculateSubItemSplit(allParticipants, total, _subItems)
        : calculateCustomSplit(_splitAmounts(allParticipants));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryFromName(
                          _category,
                        ).color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        categoryFromName(_category).icon,
                        color: categoryFromName(_category).color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleController.text,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_category · ${formatDate(_expenseDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatAmount(total),
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Split',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${allParticipants.length} ways',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Shares',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...splits.entries.map(
            (entry) => _splitRow(entry.key, entry.value.amount, uid, isDark),
          ),
        ],
      ),
    );
  }

  void _syncCustomControllers(List<String> ids, double total) {
    for (final uid in ids) {
      _amountControllers.putIfAbsent(uid, () => TextEditingController());
    }
    final removed = _amountControllers.keys
        .where((uid) => !ids.contains(uid))
        .toList();
    for (final uid in removed) {
      _amountControllers.remove(uid)?.dispose();
    }
    final key = '${total.toStringAsFixed(2)}:${ids.join(',')}';
    if (_splitSeedKey != key && _subItems.isEmpty) {
      _setEqualSplit(ids, total);
      _splitSeedKey = key;
    }
  }

  Map<String, double> _splitAmounts(List<String> ids) {
    return {
      for (final uid in ids)
        uid: double.tryParse(_amountControllers[uid]?.text ?? '') ?? 0,
    };
  }

  void _setEqualSplit(List<String> ids, double total) {
    if (ids.isEmpty) {
      return;
    }
    _lockedParticipants.clear();
    final amounts = _allocateCents(total, ids.length);
    for (var i = 0; i < ids.length; i++) {
      final amount = amounts[i];
      _amountControllers[ids[i]]?.text = _formatSplitInput(amount);
      _customAmounts[ids[i]] = amount;
    }
  }

  void _redistributeSplitFrom(
    String editedUid,
    List<String> ids,
    double total,
  ) {
    _lockedParticipants.add(editedUid);
    final editedAmount =
        double.tryParse(_amountControllers[editedUid]?.text ?? '') ?? 0;
    _customAmounts[editedUid] = editedAmount;

    final unlocked = ids
        .where((uid) => !_lockedParticipants.contains(uid))
        .toList();
    if (unlocked.isEmpty) {
      setState(() {});
      return;
    }

    final lockedTotal = ids.fold(
      0.0,
      (sum, uid) => _lockedParticipants.contains(uid)
          ? sum + (_customAmounts[uid] ?? 0)
          : sum,
    );
    final remaining = total - lockedTotal;

    if (remaining < 0) {
      _amountControllers[editedUid]?.text = total.toStringAsFixed(
        total % 1 == 0 ? 0 : 2,
      );
      _customAmounts[editedUid] = total;
      for (final uid in unlocked) {
        _amountControllers[uid]?.text = '0';
        _customAmounts[uid] = 0;
      }
      setState(() {});
      return;
    }

    final amounts = _allocateCents(remaining, unlocked.length);
    for (var i = 0; i < unlocked.length; i++) {
      final amount = amounts[i];
      _amountControllers[unlocked[i]]?.text = _formatSplitInput(amount);
      _customAmounts[unlocked[i]] = amount;
    }
    setState(() {});
  }

  List<double> _allocateCents(double total, int count) {
    if (count <= 0) {
      return const [];
    }
    final totalCents = (total * 100).round();
    final base = totalCents ~/ count;
    var remainder = totalCents % count;
    return [
      for (var i = 0; i < count; i++)
        (base + (remainder-- > 0 ? 1 : 0)) / 100.0,
    ];
  }

  String _formatSplitInput(double amount) {
    return amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
  }

  void _addSubItem() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    final Set<String> assigned = {};
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Sub-Item'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Item name',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Who pays for this?',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setDialogState(() => searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                Text(
                  '${assigned.length} selected',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: () {
                        final filtered = _participantUidsForExpense().where((
                          uid,
                        ) {
                          if (searchQuery.isEmpty) {
                            return true;
                          }
                          final friend = _friends
                              .where((f) => f.uid == uid)
                              .firstOrNull;
                          return friend?.displayName.toLowerCase().contains(
                                searchQuery,
                              ) ??
                              true;
                        }).toList();
                        if (searchQuery.isEmpty) {
                          filtered.sort((a, b) {
                            final aSel = assigned.contains(a);
                            final bSel = assigned.contains(b);
                            if (aSel == bSel) {
                              return 0;
                            }
                            return aSel ? -1 : 1;
                          });
                        }
                        return filtered.map((uid) {
                          final friend = _friends
                              .where((f) => f.uid == uid)
                              .firstOrNull;
                          final displayName =
                              uid == SupabaseService.instance.currentUid
                              ? 'You'
                              : friend?.displayName ?? uid;
                          final isSelected = assigned.contains(uid);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: GestureDetector(
                              onTap: () => setDialogState(() {
                                if (isSelected) {
                                  assigned.remove(uid);
                                } else {
                                  assigned.add(uid);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.teal.shade100,
                                      child: Text(
                                        displayName[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.teal,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList();
                      }(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final total =
                          double.tryParse(_amountController.text) ?? 0;
                      final amt = double.tryParse(amountCtrl.text) ?? 0;
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter item name')),
                        );
                        return;
                      }
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter valid amount')),
                        );
                        return;
                      }
                      final currentSubTotal = _subItems.fold(
                        0.0,
                        (s, item) => s + item.amount,
                      );
                      if (currentSubTotal + amt > total) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Items total (${formatAmount(currentSubTotal + amt)}) exceeds total (${formatAmount(total)})',
                            ),
                          ),
                        );
                        return;
                      }
                      if (assigned.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assign at least one person'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _subItems.add(
                          SubItem(
                            itemId: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            name: nameCtrl.text.trim(),
                            amount: amt,
                            assignedTo: assigned.toList(),
                          ),
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime date) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
