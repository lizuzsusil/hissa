import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../state/shell_tab_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

/// Home screen for Personal (solo) spaces: month-based total spending and
/// recent personal expenses. Never shows owed/received balances or
/// settlement actions.
class PersonalDashboardScreen extends StatefulWidget {
  const PersonalDashboardScreen({super.key});

  @override
  State<PersonalDashboardScreen> createState() =>
      _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _previousMonth =>
      DateTime(_month.year, _month.month - 1, 1);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final space = state.space;
    if (space == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final expenses = state.personalExpenses
        .where(
          (e) => e.date.year == _month.year && e.date.month == _month.month,
        )
        .toList();
    final total = state.personalTotalSpent(_month);
    final previous = state.personalTotalSpent(_previousMonth);
    final delta = total - previous;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 244,
          backgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _Header(
              space: space,
              month: _month,
              total: total,
              delta: delta,
              previousMonth: _previousMonth,
              onPreviousMonth: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1, 1),
              ),
              onNextMonth: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1, 1),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthSpendingCard(
                  total: total,
                  previous: previous,
                  previousMonth: _previousMonth,
                ),
                const SizedBox(height: 16),
                _AddExpenseButton(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ExpenseFormScreen(),
                    ));
                  },
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: l10n.recentExpenses,
                  actionLabel: l10n.viewAll,
                  onAction: () =>
                      context.read<ShellTabController>().switchTo(1),
                ),
                if (expenses.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noExpensesYet,
                    message: l10n.noExpensesMessage,
                  )
                else
                  ...expenses.take(8).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PersonalExpenseTile(expense: e),
                      )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Space space;
  final DateTime month;
  final Money total;
  final Money delta;
  final DateTime previousMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _Header({
    required this.space,
    required this.month,
    required this.total,
    required this.delta,
    required this.previousMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canGoNext = !(month.year == DateTime.now().year &&
        month.month == DateTime.now().month);
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.shimmerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            space.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ModeChip(label: l10n.personalMode),
                      ],
                    ),
                  ),
                  _MonthSwitcher(
                    label: formatMonthYear(month),
                    onPrevious: onPreviousMonth,
                    onNext: canGoNext ? onNextMonth : null,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                l10n.totalSpending,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.thisMonth} · ${_deltaLabel(l10n)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _deltaLabel(AppLocalizations l10n) {
    final monthLabel = formatMonthShort(previousMonth);
    if (delta.isZero) return l10n.even;
    final sign = delta.isPositive ? '+' : '−';
    return '$sign ${formatMoney(delta.abs(), showSymbol: false)} ${l10n.vsMonth(monthLabel)}';
  }
}

class _MonthSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chevron(Icons.chevron_left_rounded, onPrevious),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          _chevron(Icons.chevron_right_rounded, onNext),
        ],
      ),
    );
  }

  Widget _chevron(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white38 : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _MonthSpendingCard extends StatelessWidget {
  final Money total;
  final Money previous;
  final DateTime previousMonth;

  const _MonthSpendingCard({
    required this.total,
    required this.previous,
    required this.previousMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final delta = total - previous;
    final positive = delta.isPositive;
    final color = positive ? AppColors.positive : AppColors.negative;
    final soft = positive ? AppColors.positiveSoft : AppColors.negativeSoft;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.thisMonth,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.vsMonth(formatMonthShort(previousMonth)),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  delta.isZero
                      ? l10n.even
                      : '${positive ? '+' : '−'} ${formatMoney(delta.abs(), showSymbol: false)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: delta.isZero ? AppColors.textMuted : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddExpenseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.addExpense,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalExpenseTile extends StatelessWidget {
  final Expense expense;

  const _PersonalExpenseTile({required this.expense});

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
                    formatRelativeDay(expense.date, l10n: l10n),
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

/// Small white pill identifying the Space mode, shown in the dashboard header
/// so the active mode is always visible while inside a Space.
class _ModeChip extends StatelessWidget {
  final String label;

  const _ModeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}