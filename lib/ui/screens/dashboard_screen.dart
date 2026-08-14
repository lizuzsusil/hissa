import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../../logic/balances.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../state/shell_tab_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final space = state.space;
    final cycle = state.selectedCycle;

    if (space == null || cycle == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final members = state.members;
    final balances = state.computeBalances();
    final totalSpent = state.totalSpent();
    final proposals = state.settlementProposals();
    final expenses = state.expensesInCycle;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 236,
          backgroundColor:
              isDark ? AppColors.bgDark : AppColors.bg,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _Header(
              space: space,
              cycle: cycle,
              members: members,
              totalSpent: totalSpent,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _YourBalanceCard(balances: balances),
                const SizedBox(height: 16),
                _QuickActions(proposals: proposals),
                const SizedBox(height: 24),
                SectionHeader(title: l10n.spaceBalances),
                ...members.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemberBalanceCard(
                        member: m,
                        balance: balances
                            .where((b) => b.userId == m.userId)
                            .firstOrNull,
                        isYou: m.userId == state.currentUser?.id,
                      ),
                    )),
                const SizedBox(height: 16),
                SectionHeader(
                  title: l10n.recentExpenses,
                  actionLabel: l10n.viewAll,
                  onAction: () => context
                      .read<ShellTabController>()
                      .switchTo(1),
                ),
                if (expenses.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noExpensesYet,
                    message: l10n.noExpensesMessage,
                  )
                else
                  ...expenses.take(5).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExpenseTile(expense: e),
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
  final Cycle cycle;
  final List<SpaceMember> members;
  final Money totalSpent;

  const _Header({
    required this.space,
    required this.cycle,
    required this.members,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.home_work_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
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
                        _ModeChip(label: l10n.split),
                      ],
                    ),
                  ),
                  _CycleSelector(cycle: cycle),
                ],
              ),
              const Spacer(),
              Text(
                l10n.totalSpending,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(totalSpent),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AvatarStack(names: members.map((m) => m.name).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleSelector extends StatelessWidget {
  final Cycle cycle;

  const _CycleSelector({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopupMenuButton<String>(
      onSelected: (id) => state.selectCycle(id),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        for (final c in state.cycles)
          PopupMenuItem(
            value: c.id,
            child: Row(
              children: [
                Icon(
                  c.status == CycleStatus.closed
                      ? Icons.history_rounded
                      : Icons.radio_button_checked,
                  size: 18,
                  color: c.id == cycle.id
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(c.name),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cycle.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _YourBalanceCard extends StatelessWidget {
  final List<BalanceInfo> balances;

  const _YourBalanceCard({required this.balances});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();
    final mine = balances.where((b) => b.userId == user.id).firstOrNull;
    if (mine == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.yourBalance,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              _BalanceChip(balance: mine.balance),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l10n.youPaid,
                  value: formatMoneyCompact(mine.paid),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.positive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: l10n.yourShare,
                  value: formatMoneyCompact(mine.share),
                  icon: Icons.people_alt_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final Money balance;

  const _BalanceChip({required this.balance});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (balance.isZero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(l10n.even,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
    }
    final positive = balance.isPositive;
    final color = positive ? AppColors.positive : AppColors.negative;
    final soft = positive ? AppColors.positiveSoft : AppColors.negativeSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            positive ? l10n.youReceive : l10n.youOwe,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            formatMoney(balance.abs()),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final List proposals;

  const _QuickActions({required this.proposals});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_rounded,
                label: l10n.addExpense,
                gradient: true,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ExpenseFormScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.swap_horiz_rounded,
                label: l10n.settleUp,
                gradient: false,
                onTap: () => context.read<ShellTabController>().switchTo(2),
              ),
            ),
          ],
        ),
        if (proposals.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.read<ShellTabController>().switchTo(2),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_flat_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.settlementsWaiting(proposals.length),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    l10n.review,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = gradient ? Colors.white : AppColors.primary;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient ? AppColors.heroGradient : null,
            color: gradient ? null : bgColor,
            borderRadius: BorderRadius.circular(18),
            border: gradient
                ? null
                : Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 26, color: foreground),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  final SpaceMember member;
  final BalanceInfo? balance;
  final bool isYou;

  const _MemberBalanceCard({
    required this.member,
    required this.balance,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final b = balance;
    final balanceValue = b?.balance ?? Money.zero();
    final statusColor = balanceValue.isZero
        ? AppColors.textMuted
        : balanceValue.isPositive
            ? AppColors.positive
            : AppColors.negative;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          MemberAvatar(name: member.name, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.you,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.memberPaidShare(
                    formatMoneyCompact(b?.paid ?? Money.zero(), showSymbol: false),
                    formatMoneyCompact(b?.share ?? Money.zero(), showSymbol: false),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              balanceValue.isZero
                  ? l10n.even
                  : '${balanceValue.isPositive ? '+' : ''}${formatMoneyCompact(balanceValue, showSymbol: false)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;

  const _ExpenseTile({required this.expense});

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
                    '${state.memberName(expense.paidByUserId)} · ${formatRelativeDay(expense.date, l10n: l10n)}',
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
