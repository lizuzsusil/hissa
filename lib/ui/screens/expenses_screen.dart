import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/category_icon.dart';
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/toasts.dart';
import 'expense_detail_screen.dart';
import 'income_form_screen.dart';

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
  _Period _period = _Period.all;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final l10n = context.l10n;
    final isPersonal = state.isPersonalMode;

    final allExpenses = isPersonal
        ? state.personalExpenses
        : state.expensesInCycle;
    // Hissa income lives alongside expenses in Split Spaces; it is a
    // separate section, unaffected by expense filters.
    final incomes = isPersonal
        ? const <HissaIncome>[]
        : state.hissaIncomesInCycle;
    final cycleOpen = state.selectedCycle?.status != CycleStatus.closed;
    var filtered = allExpenses;

    if (_categoryFilter != null) {
      filtered = filtered
          .where((e) => e.categoryId == _categoryFilter)
          .toList();
    }
    if (_memberFilter != null) {
      filtered = filtered
          .where((e) => e.paidByUserId == _memberFilter)
          .toList();
    }
    if (_period != _Period.all || _dateRange != null) {
      filtered = filtered.where((e) => _matchesTimeFilter(e.date)).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((e) {
        final description = (e.description ?? '').toLowerCase();
        final payer = (state.memberName(e.paidByUserId) ?? '').toLowerCase();
        final category = (state.categoryFor(e.categoryId)?.name ?? '')
            .toLowerCase();
        return description.contains(q) ||
            payer.contains(q) ||
            category.contains(q);
      }).toList();
    }

    final categories = state.categories;
    final members = state.members;

    final summaryCount = isPersonal ? filtered.length : 0;
    final summaryTotal = isPersonal
        ? filtered.fold<Money>(Money.zero(), (sum, e) => sum + e.amount)
        : Money.zero();
    final summaryAvg = summaryCount == 0
        ? Money.zero()
        : Money((summaryTotal.paisa / summaryCount).round());
    final summaryTitle = _summaryTitle(l10n);
    final previous = isPersonal ? _previousPeriod(allExpenses) : null;
    int? deltaPercent;
    if (previous != null && previous.previous.paisa > 0) {
      deltaPercent =
          ((summaryTotal.paisa - previous.previous.paisa) *
                  100 /
                  previous.previous.paisa)
              .round();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          if (!isPersonal && cycleOpen)
            IconAction(
              icon: Icons.savings_outlined,
              tooltip: l10n.addIncome,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IncomeFormScreen()),
                );
              },
            ),
          IconAction(
            icon: _dateRange != null
                ? Icons.date_range_rounded
                : Icons.date_range_outlined,
            tooltip: l10n.dateRange,
            onPressed: () => _pickDateRange(),
          ),
          if (!isPersonal) ...[
            const SizedBox(width: AppSpacing.sm),
            IconAction(
              icon:
                  _memberFilter != null ||
                      _categoryFilter != null ||
                      _period != _Period.all ||
                      _dateRange != null
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              tooltip: l10n.filterExpenses,
              onPressed: () => _showFilterSheet(state, members, categories),
            ),
          ],
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.searchExpenses,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.pageH,
              children: [
                _FilterChip(
                  label: l10n.all,
                  selected:
                      _categoryFilter == null &&
                      _memberFilter == null &&
                      _period == _Period.all &&
                      _dateRange == null,
                  onTap: () => setState(() {
                    _categoryFilter = null;
                    _memberFilter = null;
                    _period = _Period.all;
                    _dateRange = null;
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
                    leading: Icon(
                      iconForCodePoint(c.iconCodePoint),
                      size: 14,
                      color: _categoryFilter == c.id
                          ? Colors.white
                          : (c.colorValue == null
                                ? p.textSecondary
                                : Color(c.colorValue!)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.pageH,
              children: [
                _FilterChip(
                  label: l10n.allTimeTotal,
                  selected: _period == _Period.all && _dateRange == null,
                  onTap: () => setState(() {
                    _period = _Period.all;
                    _dateRange = null;
                  }),
                  compact: true,
                ),
                _FilterChip(
                  label: l10n.thisWeek,
                  selected: _period == _Period.week,
                  onTap: () => setState(() {
                    _period = _period == _Period.week
                        ? _Period.all
                        : _Period.week;
                    _dateRange = null;
                  }),
                  compact: true,
                ),
                _FilterChip(
                  label: l10n.thisMonthTotal,
                  selected: _period == _Period.month,
                  onTap: () => setState(() {
                    _period = _period == _Period.month
                        ? _Period.all
                        : _Period.month;
                    _dateRange = null;
                  }),
                  compact: true,
                ),
                _FilterChip(
                  label: l10n.thisYearTotal,
                  selected: _period == _Period.year,
                  onTap: () => setState(() {
                    _period = _period == _Period.year
                        ? _Period.all
                        : _Period.year;
                    _dateRange = null;
                  }),
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AppState>().refresh(),
              child: filtered.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: l10n.noMatchingExpenses,
                              message: l10n.noMatchingMessage,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.sm,
                        AppSpacing.xl,
                        100,
                      ),
                      children: [
                        if (isPersonal) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _LifetimeCard(
                            title: summaryTitle,
                            total: summaryTotal,
                            count: summaryCount,
                            average: summaryAvg,
                            deltaPercent: deltaPercent,
                            deltaLabel: previous?.label,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (incomes.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _IncomeSection(
                            incomes: incomes,
                            total: state.totalHissaIncome(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        for (final entry in _groupByDay(filtered).entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              2,
                              AppSpacing.lg,
                              2,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  formatRelativeDay(
                                    entry.value.first.date,
                                    l10n: l10n,
                                  ),
                                  style: AppText.overline.copyWith(
                                    color: p.textMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _dayTotal(entry.value),
                                  style: AppText.overline.copyWith(
                                    color: p.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final expense in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _ExpenseRow(expense: expense),
                            ),
                        ],
                      ],
                    ),
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
      final key = DateTime(
        e.date.year,
        e.date.month,
        e.date.day,
      ).toIso8601String();
      map.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  void _showFilterSheet(
    AppState state,
    List<SpaceMember> members,
    List<Category> categories,
  ) {
    final l10n = context.l10n;

    showAppSheet<void>(
      context: context,
      title: l10n.filterExpenses,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final p = context.palette;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!state.isPersonalMode) ...[
                  Text(
                    l10n.paidBy,
                    style: AppText.labelM.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.everyone),
                        selected: _memberFilter == null,
                        onSelected: (_) =>
                            setSheetState(() => _memberFilter = null),
                      ),
                      for (final m in members)
                        ChoiceChip(
                          label: Text(m.name),
                          selected: _memberFilter == m.userId,
                          onSelected: (_) =>
                              setSheetState(() => _memberFilter = m.userId),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _FilterDropdown(
                  label: l10n.category,
                  value: _categoryFilter ?? '',
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(l10n.allCategories),
                    ),
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setSheetState(
                    () => _categoryFilter = (v ?? '') == '' ? null : v,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: l10n.apply,
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _dateRange,
      helpText: l10n.dateRange,
      saveText: l10n.apply,
      cancelText: l10n.cancel,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateRange = picked;
        _period = _Period.all;
      });
    }
  }

  String _summaryTitle(AppLocalizations l10n) {
    if (_dateRange != null) {
      final start = _dateRange!.start;
      final end = _dateRange!.end;
      return '${DateFormat('d MMM').format(start)} – '
          '${DateFormat('d MMM').format(end)}';
    }
    switch (_period) {
      case _Period.week:
        return l10n.thisWeek;
      case _Period.month:
        return l10n.thisMonthTotal;
      case _Period.year:
        return l10n.thisYearTotal;
      case _Period.all:
        break;
    }
    if (_categoryFilter != null || _memberFilter != null) {
      return l10n.filteredSpending;
    }
    return l10n.lifetimeSpending;
  }

  ({Money previous, String label})? _previousPeriod(List<Expense> all) {
    if (_period == _Period.all && _dateRange == null) return null;
    final l10n = context.l10n;
    final now = DateTime.now();
    DateTimeRange? window;
    late String label;
    switch (_period) {
      case _Period.week:
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = DateTime(
          today.year,
          today.month,
          today.day - (today.weekday - 1),
        );
        final prevStart = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day - 7,
        );
        window = DateTimeRange(
          start: prevStart,
          end: DateTime(
            prevStart.year,
            prevStart.month,
            prevStart.day + 6,
            23,
            59,
            59,
            999,
          ),
        );
        label = l10n.vsLastWeek;
      case _Period.month:
        window = DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59, 999),
        );
        label = l10n.vsLastMonth;
      case _Period.year:
        window = DateTimeRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year - 1, 12, 31, 23, 59, 59, 999),
        );
        label = l10n.vsLastYear;
      case _Period.all:
        break;
    }
    if (window == null && _dateRange != null) {
      final length = _dateRange!.end.difference(_dateRange!.start);
      final prevEnd = _dateRange!.start.subtract(const Duration(days: 1));
      final prevStart = prevEnd.subtract(length);
      window = DateTimeRange(start: prevStart, end: prevEnd);
      label = l10n.vsPreviousPeriod;
    }
    if (window == null) return null;
    var total = Money.zero();
    for (final e in all) {
      if (_categoryFilter != null && e.categoryId != _categoryFilter) continue;
      if (_memberFilter != null && e.paidByUserId != _memberFilter) continue;
      if (!e.date.isBefore(window.start) && !e.date.isAfter(window.end)) {
        total += e.amount;
      }
    }
    return (previous: total, label: label);
  }

  bool _matchesTimeFilter(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = DateTime(
          today.year,
          today.month,
          today.day - (today.weekday - 1),
        );
        final weekEnd = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 6,
          23,
          59,
          59,
          999,
        );
        return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
      case _Period.month:
        return date.year == now.year && date.month == now.month;
      case _Period.year:
        return date.year == now.year;
      case _Period.all:
        break;
    }
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }
    return true;
  }
}

enum _Period { all, week, month, year }

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final Widget? leading;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(right: compact ? 6 : AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : p.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                style: AppText.labelM.copyWith(
                  fontSize: compact ? 12.5 : 13,
                  color: selected ? Colors.white : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// Spending summary shown at the top of the personal expenses list. Reflects
/// the active filters and compares the total against the previous period.
class _LifetimeCard extends StatelessWidget {
  final String title;
  final Money total;
  final int count;
  final Money average;
  final int? deltaPercent;
  final String? deltaLabel;

  const _LifetimeCard({
    required this.title,
    required this.total,
    required this.count,
    required this.average,
    this.deltaPercent,
    this.deltaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SurfaceCard(
      tint: AppColors.primary,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(AppColors.primary),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.titleS.copyWith(color: p.textPrimary),
                  ),
                ),
                if (deltaPercent != null && deltaLabel != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _DeltaChip(percent: deltaPercent!, label: deltaLabel!),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              formatMoney(total),
              style: AppText.displayL.copyWith(
                fontSize: 28,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.expenses}: $count · '
              '${l10n.average}: ${formatMoneyCompact(average)}',
              style: AppText.caption.copyWith(
                fontSize: 12.5,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final int percent;
  final String label;

  const _DeltaChip({required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusBadge(
          label: '${up ? '+' : '-'}${percent.abs()}%',
          tone: up ? BadgeTone.negative : BadgeTone.positive,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppText.caption.copyWith(color: context.palette.textMuted),
        ),
      ],
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
    final p = context.palette;
    final category = state.categoryFor(expense.categoryId);
    return PressableScale(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(expense: expense),
          ),
        );
      },
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 42),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleS.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.paidByMemberDay(
                      state.memberName(expense.paidByUserId) ?? l10n.unknown,
                      formatRelativeDay(expense.date, l10n: l10n),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontSize: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formatMoney(expense.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleS.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hissa income section: a shared contribution card listing every income
/// record of the current cycle. Tapping a row edits it; the trash icon
/// deletes it after confirmation. Balances update automatically through the
/// existing balance pipeline.
class _IncomeSection extends StatelessWidget {
  final List<HissaIncome> incomes;
  final Money total;

  const _IncomeSection({required this.incomes, required this.total});

  Future<void> _confirmDelete(BuildContext context, HissaIncome income) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteIncomeTitle,
      message: l10n.deleteIncomeMessage,
      confirmLabel: l10n.delete,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AppState>().deleteHissaIncome(income.id);
    if (context.mounted) {
      showToast(context, context.l10n.incomeDeletedToast, type: ToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(AppColors.positive),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  size: 20,
                  color: AppColors.positive,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.hissaIncomeSection,
                  style: AppText.titleS.copyWith(color: p.textPrimary),
                ),
              ),
              Text(
                '+ ${formatMoney(total)}',
                style: AppText.titleS.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.positive,
                ),
              ),
            ],
          ),
          for (final income in incomes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _IncomeRow(
                income: income,
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IncomeFormScreen(income: income),
                    ),
                  );
                },
                onDelete: () => _confirmDelete(context, income),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final HissaIncome income;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IncomeRow({
    required this.income,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final p = context.palette;
    return PressableScale(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            MemberAvatar(
              name: state.memberName(income.receivedByUserId) ?? '?',
              size: 30,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    income.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.receivedByMemberDay(
                      state.memberName(income.receivedByUserId) ?? l10n.unknown,
                      formatRelativeDay(income.date, l10n: l10n),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontSize: 11.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(income.amount),
              style: AppText.labelL.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.positive,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppColors.negative,
                ),
                tooltip: l10n.delete,
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
