import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import 'expense_detail_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _categoryFilter;
  String? _memberFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final isPersonal = state.isPersonalMode;

    final allExpenses = isPersonal
        ? state.personalExpenses
        : state.expensesInCycle;
    var filtered = allExpenses;

    if (_categoryFilter != null) {
      filtered = filtered.where((e) => e.categoryId == _categoryFilter).toList();
    }
    if (_memberFilter != null) {
      filtered =
          filtered.where((e) => e.paidByUserId == _memberFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((e) {
        final description = (e.description ?? '').toLowerCase();
        final payer = (state.memberName(e.paidByUserId) ?? '').toLowerCase();
        final category =
            (state.categoryFor(e.categoryId)?.name ?? '').toLowerCase();
        return description.contains(q) ||
            payer.contains(q) ||
            category.contains(q);
      }).toList();
    }

    final categories = state.categories;
    final members = state.members;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          IconAction(
            icon: _memberFilter != null || _categoryFilter != null
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            onPressed: () => _showFilterSheet(state, members, categories),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.searchExpenses,
                suffixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _FilterChip(
                  label: l10n.all,
                  selected: _categoryFilter == null && _memberFilter == null,
                  onTap: () => setState(() {
                    _categoryFilter = null;
                    _memberFilter = null;
                  }),
                ),
                for (final c in categories)
                  _FilterChip(
                    label: c.name,
                    selected: _categoryFilter == c.id,
                    onTap: () => setState(() {
                      _categoryFilter = _categoryFilter == c.id ? null : c.id;
                      _memberFilter = null;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noMatchingExpenses,
                    message: l10n.noMatchingMessage,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      for (final entry
                          in _groupByDay(filtered).entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
                          child: Row(
                            children: [
                              Text(
                                formatRelativeDay(entry.value.first.date,
                                    l10n: l10n),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _dayTotal(entry.value),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final expense in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExpenseRow(expense: expense),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _dayTotal(List<Expense> items) {
    var total = 0;
    for (final e in items) {
      total += e.amount.paisa;
    }
    return formatMoneyCompact(Money(total), showSymbol: false);
  }

  Map<String, List<Expense>> _groupByDay(List<Expense> expenses) {
    final map = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = DateTime(e.date.year, e.date.month, e.date.day)
          .toIso8601String();
      map.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  void _showFilterSheet(
    AppState state,
    List<SpaceMember> members,
    List<Category> categories,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.filterExpenses,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                if (state.isPersonalMode) ...[
                  Text(context.l10n.category,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.all),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setSheetState(() => _categoryFilter = null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          avatar:
                              Icon(iconForCodePoint(c.iconCodePoint), size: 16),
                          label: Text(c.name),
                          selected: _categoryFilter == c.id,
                          onSelected: (_) => setSheetState(
                              () => _categoryFilter = c.id),
                        ),
                    ],
                  ),
                ] else ...[
                  Text(context.l10n.paidBy,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.everyone),
                        selected: _memberFilter == null,
                        onSelected: (_) =>
                            setSheetState(() => _memberFilter = null),
                      ),
                      for (final m in members)
                        ChoiceChip(
                          label: Text(m.name),
                          selected: _memberFilter == m.userId,
                          onSelected: (_) => setSheetState(
                              () => _memberFilter = m.userId),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.category,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.all),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setSheetState(() => _categoryFilter = null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          avatar:
                              Icon(iconForCodePoint(c.iconCodePoint), size: 16),
                          label: Text(c.name),
                          selected: _categoryFilter == c.id,
                          onSelected: (_) => setSheetState(
                              () => _categoryFilter = c.id),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButtonLocal(
                  label: context.l10n.apply,
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButtonLocal extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const PrimaryButtonLocal({
    super.key,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;

  const _ExpenseRow({required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final category = state.categoryFor(expense.categoryId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.paidByMemberDay(
                      state.memberName(expense.paidByUserId) ?? l10n.unknown,
                      formatRelativeDay(expense.date, l10n: l10n),
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(expense.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
