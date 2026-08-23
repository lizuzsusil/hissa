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
import '../widgets/cards.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';
import 'income_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final space = state.space;
    final cycle = state.selectedCycle;

    if (space == null || cycle == null) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    final members = state.members;
    final balances = state.computeBalances();
    final totalSpent = state.totalSpent();
    final proposals = state.settlementProposals();
    final expenses = state.expensesInCycle;
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 244,
            backgroundColor: context.palette.bg,
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _YourBalanceCard(balances: balances),
                  const SizedBox(height: AppSpacing.lg),
                  _QuickActions(proposals: proposals),
                  // Shared hissa contribution summary. Income lowers the
                  // hissa's net expense, so surface it right next to the
                  // spending total whenever it exists this cycle.
                  if (state.hissaIncomesInCycle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _IncomeBanner(total: state.totalHissaIncome()),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(title: l10n.spaceBalances),
                  // Grouped members are represented by their Member Group, so
                  // only ungrouped members get an individual row.
                  ...members
                      .where((m) => !state.groupedUserIds.contains(m.userId))
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Reveal(
                            delay: Duration(milliseconds: 50 * entry.key),
                            child: _MemberBalanceCard(
                              member: entry.value,
                              avatarUrl: state.memberAvatarUrl(
                                entry.value.userId,
                              ),
                              balance: balances
                                  .where((b) => b.userId == entry.value.userId)
                                  .firstOrNull,
                              isYou:
                                  entry.value.userId == state.currentUser?.id,
                            ),
                          ),
                        ),
                      ),
                  // Member Groups are financial participants too: surface their
                  // balance so the sheet reconciles (§37).
                  ...state.repo.memberGroups
                      .where((g) => g.spaceId == space.id && g.isActive)
                      .map((g) {
                        final balance = balances
                            .where((b) => b.userId == g.id)
                            .firstOrNull;
                        if (balance == null || balance.balance.isZero) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _GroupBalanceCard(group: g, balance: balance),
                        );
                      }),
                  const SizedBox(height: AppSpacing.lg),
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
                        .take(5)
                        .toList()
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Reveal(
                              delay: Duration(milliseconds: 50 * entry.key),
                              child: _ExpenseTile(expense: entry.value),
                            ),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient statement header: space identity, cycle selector and this
/// cycle's total spend — the single most important number on the page.
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
    final user = context.watch<AppState>().currentUser;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 6, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            space.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleM.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ModeChip(label: l10n.split),
                      ],
                    ),
                  ),
                  _CycleSelector(cycle: cycle),
                ],
              ),
              const Spacer(),
              if (user != null) ...[
                Row(
                  children: [
                    MemberAvatar(
                      name: user.name,
                      avatarUrl: user.avatarUrl,
                      size: 30,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        l10n.welcomeUser(user.name),
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelL.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                l10n.totalSpending,
                style: AppText.labelM.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedMoney(
                  paisa: totalSpent.paisa,
                  formatter: (p) => formatMoney(Money(p)),
                  style: AppText.displayL.copyWith(
                    fontSize: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
    final p = context.palette;
    return PopupMenuButton<String>(
      onSelected: (id) => state.selectCycle(id),
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: p.border),
      ),
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
                  color: c.id == cycle.id ? AppColors.primary : p.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(c.name),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cycle.name,
              style: AppText.labelM.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.expand_more_rounded,
              color: Colors.white,
              size: 17,
            ),
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
    // A grouped user's balance is carried by their Member Group.
    final mineId = state.currentUserGroup?.id ?? user.id;
    final mine = balances.where((b) => b.userId == mineId).firstOrNull;
    if (mine == null) return const SizedBox.shrink();

    return SurfaceCard(
      tint: AppColors.primary,
      elevation: 1,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.yourBalance,
                  style: AppText.titleS.copyWith(fontSize: 15),
                ),
              ),
              _BalanceChip(balance: mine.balance),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(width: AppSpacing.md),
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
    final p = context.palette;
    if (balance.isZero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          l10n.even,
          style: AppText.labelM.copyWith(color: p.textSecondary),
        ),
      );
    }
    final positive = balance.isPositive;
    final color = positive ? AppColors.positive : AppColors.negative;
    final soft = positive ? AppColors.positiveSoft : AppColors.negativeSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            positive ? l10n.youReceive : l10n.youOwe,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            formatMoney(balance.abs()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact tinted stat tile used inside the balance card.
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(color, alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: context.palette.textPrimary,
                    ),
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
              flex: 2,
              child: _PrimaryAction(
                icon: Icons.add_rounded,
                label: l10n.addExpense,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExpenseFormScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TonalAction(
                icon: Icons.savings_outlined,
                label: l10n.addIncome,
                tint: AppColors.positive,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const IncomeFormScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TonalAction(
                icon: Icons.swap_horiz_rounded,
                label: l10n.settleUp,
                tint: AppColors.secondary,
                onTap: () => context.read<ShellTabController>().switchTo(2),
              ),
            ),
          ],
        ),
        if (proposals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          PressableScale(
            onTap: () => context.read<ShellTabController>().switchTo(2),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppGradients.tint(
                  AppColors.primary,
                  alpha: context.isDark ? 0.22 : 0.12,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_flat_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.settlementsWaiting(proposals.length),
                      style: AppText.labelL.copyWith(
                        color: context.isDark
                            ? AppColors.primaryBright
                            : AppColors.primaryDeep,
                      ),
                    ),
                  ),
                  Text(
                    l10n.review,
                    style: TextStyle(
                      color: context.isDark
                          ? AppColors.primaryBright
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: context.isDark
                        ? AppColors.primaryBright
                        : AppColors.primary,
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

/// The dominant quick action: solid brand fill with a soft shadow.
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
              const Icon(Icons.add_rounded, size: 22, color: Colors.white),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
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

/// Quiet secondary quick action with a colour-coded icon well.
class _TonalAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  const _TonalAction({
    required this.icon,
    required this.label,
    required this.tint,
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
              Icon(icon, size: 21, color: tint),
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

class _GroupBalanceCard extends StatelessWidget {
  final MemberGroup group;
  final BalanceInfo balance;

  const _GroupBalanceCard({required this.group, required this.balance});

  @override
  Widget build(BuildContext context) {
    final b = balance;
    final statusColor = b.balance.isZero
        ? context.palette.textMuted
        : b.balance.isPositive
            ? AppColors.positive
            : AppColors.negative;
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(AppColors.primary),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 21,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: AppText.titleS.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.memberPaidShare(
                    formatMoneyCompact(b.paid, showSymbol: false),
                    formatMoneyCompact(b.share, showSymbol: false),
                  ),
                  style: AppText.bodyM.copyWith(
                    fontSize: 12.5,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _AmountTag(value: b.balance, color: statusColor),
        ],
      ),
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  final SpaceMember member;
  final String? avatarUrl;
  final BalanceInfo? balance;
  final bool isYou;

  const _MemberBalanceCard({
    required this.member,
    required this.avatarUrl,
    required this.balance,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = balance;
    final balanceValue = b?.balance ?? Money.zero();
    final statusColor = balanceValue.isZero
        ? context.palette.textMuted
        : balanceValue.isPositive
            ? AppColors.positive
            : AppColors.negative;

    return SurfaceCard(
      child: Row(
        children: [
          MemberAvatar(name: member.name, avatarUrl: avatarUrl, size: 44),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleS.copyWith(fontSize: 14.5),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          l10n.you,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.memberPaidShare(
                    formatMoneyCompact(
                      b?.paid ?? Money.zero(),
                      showSymbol: false,
                    ),
                    formatMoneyCompact(
                      b?.share ?? Money.zero(),
                      showSymbol: false,
                    ),
                  ),
                  style: AppText.bodyM.copyWith(
                    fontSize: 12.5,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _AmountTag(
            value: balanceValue,
            color: statusColor,
            zeroLabel: l10n.even,
          ),
        ],
      ),
    );
  }
}

/// Signed balance tag rendered as a tinted pill.
class _AmountTag extends StatelessWidget {
  final Money value;
  final Color color;
  final String? zeroLabel;

  const _AmountTag({
    required this.value,
    required this.color,
    this.zeroLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(color, alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        value.isZero && zeroLabel != null
            ? zeroLabel!
            : '${value.isPositive ? '+' : ''}${formatMoneyCompact(value, showSymbol: false)}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: color,
        ),
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
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 42),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleS.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.memberName(expense.paidByUserId)} · ${formatRelativeDay(expense.date, l10n: l10n)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyM.copyWith(
                      fontSize: 12.5,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatMoney(expense.amount),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact summary of the hissa income recorded this cycle. Tapping it
/// opens the expenses tab where income records can be added, edited and
/// deleted.
class _IncomeBanner extends StatelessWidget {
  final Money total;

  const _IncomeBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PressableScale(
      onTap: () => context.read<ShellTabController>().switchTo(1),
      child: InfoBanner(
        icon: Icons.savings_outlined,
        tone: InfoTone.positive,
        message: l10n.hissaIncome,
        actionLabel: '+${formatMoney(total)}',
      ),
    );
  }
}
