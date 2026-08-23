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
    final estimatedTotal = state.estimatedTotalForMonth(_month);
    final now = DateTime.now();
    final thisMonthEstimates = state.estimatedExpensesForMonth(
      DateTime(now.year, now.month),
    );
    final currentEstimate =
        thisMonthEstimates.isEmpty ? null : thisMonthEstimates.first;
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 208,
            backgroundColor: context.palette.bg,
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg + 2,
                AppSpacing.xl,
                0,
              ),
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
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _PrimaryAction(
                          icon: Icons.add_rounded,
                          label: l10n.addExpense,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExpenseFormScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _TonalAction(
                          icon: currentEstimate == null
                              ? Icons.flag_outlined
                              : Icons.edit_outlined,
                          label: currentEstimate == null
                              ? l10n.addEstimate
                              : l10n.editEstimate,
                          onTap: () => _openEstimateSheet(
                            estimate: currentEstimate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
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
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Reveal(
                              delay: Duration(milliseconds: 60 * entry.key),
                              child: _PersonalExpenseTile(expense: entry.value),
                            ),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.xxxl - AppSpacing.sm),
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
}

/// Gradient statement header: identity, month switcher and this month's
/// total spend — the single most important number on the page.
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
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 8, AppSpacing.xl, AppSpacing.xl + 2),
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
                    const SizedBox(width: AppSpacing.sm + 2),
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
                            style:
                                AppText.titleM.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(child: ModeChip(label: l10n.personalMode)),
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
                style: AppText.labelM.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
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
                        style:
                            AppText.displayL.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _deltaLabel(l10n),
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatMonthYear(month),
                style: AppText.labelM.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chevron(Icons.chevron_left_rounded, onPrevious),
          Text(
            label,
            style: AppText.labelM.copyWith(color: Colors.white),
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

/// The dominant quick action: solid brand gradient fill with a soft shadow.
class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleS.copyWith(
                    letterSpacing: -0.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet secondary quick action with a colour-coded icon.
class _TonalAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TonalAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          height: 76,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: AppColors.tertiary),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 42),
            const SizedBox(width: AppSpacing.lg - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    style: AppText.titleS.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatRelativeDay(expense.date, l10n: l10n),
                    style: AppText.caption.copyWith(color: p.textSecondary),
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
