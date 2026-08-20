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
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';
import 'personal/estimated_expense_sheet.dart';
import 'personal/personal_widgets.dart';

/// Home screen for Personal (personal) spaces: month-based total spending,
/// a planned-vs-actual estimate summary, recent personal expenses and the
/// month's planned amounts. Never shows owed/received balances or settlement
/// actions, and estimated amounts are always kept visually and numerically
/// distinct from real spending.
class PersonalDashboardScreen extends StatefulWidget {
  const PersonalDashboardScreen({super.key});

  @override
  State<PersonalDashboardScreen> createState() =>
      _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _previousMonth => DateTime(_month.year, _month.month - 1, 1);

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
    final estimates = state.estimatedExpensesForMonth(_month);
    final estimatedTotal = state.estimatedTotalForMonth(_month);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 208,
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
            child: ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EstimateProgressCard(
                    month: _month,
                    spent: total,
                    estimated: estimatedTotal,
                    showEmptyAction: false,
                    onAddEstimate: () => _openEstimateSheet(),
                    onManageEstimates: () => _openEstimatesEditor(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          gradient: AppGradients.accent,
                          icon: Icons.add_rounded,
                          label: l10n.addExpense,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExpenseFormScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          gradient: null,
                          icon: Icons.flag_outlined,
                          label: l10n.addEstimate,
                          onTap: () => _openEstimateSheet(),
                        ),
                      ),
                    ],
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
                    ...expenses
                        .take(8)
                        .toList()
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Reveal(
                              delay: Duration(milliseconds: 60 * entry.key),
                              child: _PersonalExpenseTile(expense: entry.value),
                            ),
                          ),
                        ),
                  if (estimates.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: l10n.estimatedExpenses,
                    actionLabel: l10n.viewAll,
                    onAction: () => _openEstimatesEditor(),
                  ),
                  ...estimates.take(8).map(
                    (estimate) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EstimateTile(
                        estimate: estimate,
                        onEdit: () => _openEstimateSheet(estimate: estimate),
                        onRemove: () => _removeEstimate(estimate),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEstimateSheet({EstimatedExpense? estimate}) {
    return showEstimatedExpenseSheet(context, estimate: estimate);
  }

  Future<void> _openEstimatesEditor() {
    return showMonthEstimatesSheet(context, month: _month);
  }

  Future<void> _removeEstimate(EstimatedExpense estimate) async {
    final appState = context.read<AppState>();
    final ok = await confirmRemoveEstimate(context);
    if (!ok) return;
    await appState.deleteEstimatedExpense(estimate.id);
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
    final user = context.watch<AppState>().currentUser;
    final canGoNext =
        !(month.year == DateTime.now().year &&
            month.month == DateTime.now().month);
    final firstName = user == null || user.name.trim().isEmpty
        ? null
        : user.name.trim().split(RegExp(r'\s+')).first;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.shimmerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (user != null) ...[
                    MemberAvatar(
                      name: user.name,
                      avatarUrl: user.avatarUrl,
                      size: 36,
                      outline: true,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            firstName != null
                                ? l10n.welcomeUser(firstName)
                                : space.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ModeChip(label: l10n.personalMode),
                      ],
                    ),
                  ),
                  _MonthSwitcher(
                    label: formatMonthShort(month),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedMoney(
                        paisa: total.paisa,
                        formatter: (p) => formatMoney(Money(p)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _deltaLabel(l10n),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatMonthYear(month),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
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
    return '$sign ${formatMoney(delta.abs(), showSymbol: false)} $monthLabel';
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

/// One of the two quick actions on the dashboard: adding a real expense
/// (gradient) or adding a planned amount (outlined, tertiary). The two are
/// deliberately styled differently so actual vs estimated is never ambiguous.
class _ActionButton extends StatelessWidget {
  final LinearGradient? gradient;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null
              ? (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt)
              : null,
          borderRadius: BorderRadius.circular(18),
          border: gradient == null
              ? Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                )
              : null,
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: AppColors.secondaryDark.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: gradient == null ? AppColors.tertiary : Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gradient == null
                      ? (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary)
                      : Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
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
    return PressableScale(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(expense: expense),
          ),
        );
      },
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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