import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../logic/balances.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/category_icon.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import 'expense_detail_screen.dart';

const _months = [
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

String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _cycleRange(Cycle c) {
  final start = _shortDate(c.startDate);
  if (c.status == CycleStatus.closed && c.closedAt != null) {
    final end = _shortDate(c.closedAt!);
    return start == end ? start : '$start – $end';
  }
  final end = _shortDate(c.endDate);
  return start == end ? start : '$start – $end';
}

/// Details of a single spending cycle: its period, total spent, who paid what,
/// the settlement balances and every expense recorded in it.
class CycleDetailScreen extends StatelessWidget {
  final String cycleId;

  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cycle = state.cycles.where((c) => c.id == cycleId).firstOrNull;

    if (cycle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cycleDetails)),
        body: const Center(child: Text('')),
      );
    }

    final expenses = state.expensesForCycle(cycleId);
    final balances = state.computeBalances(cycleId);
    final total = state.totalSpent(cycleId);
    final isClosed = cycle.status == CycleStatus.closed;

    return Scaffold(
      appBar: AppBar(title: Text(cycle.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cycle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusBadge(closed: isClosed, label: _cycleStatusLabel(l10n, cycle.status)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _cycleRange(cycle),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.space?.cycleType == CycleType.custom
                      ? l10n.customCycle
                      : l10n.monthlyCycle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _StatLabel(
                        value: formatMoney(total),
                        label: l10n.totalSpent,
                      ),
                    ),
                    Expanded(
                      child: _StatLabel(
                        value: '${expenses.length}',
                        label: l10n.expensesCount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (balances.isNotEmpty) ...[
            SectionHeader(title: l10n.whoPaidThisCycle),
            const SizedBox(height: 8),
            for (final b in balances) _BalanceRow(state: state, info: b),
            const SizedBox(height: 20),
          ],
          SectionHeader(title: l10n.expenses),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Text(
                l10n.noExpensesInCycle,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final expense in expenses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CycleExpenseTile(expense: expense),
              ),
        ],
      ),
    );
  }
}

/// Lists the closed (historical) cycles of the current Space. Tapping one opens
/// its details.
class PreviousCyclesScreen extends StatelessWidget {
  const PreviousCyclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cycles = state.closedCycles;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.previousCycles)),
      body: cycles.isEmpty
          ? Center(
              child: Text(
                l10n.noPreviousCycles,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final c in cycles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CycleDetailScreen(cycleId: c.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _cycleRange(c),
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
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(state.totalSpent(c.id)),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool closed;
  final String label;

  const _StatusBadge({required this.closed, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = closed ? AppColors.textMuted : AppColors.positive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  final String value;
  final String label;

  const _StatLabel({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final AppState state;
  final BalanceInfo info;

  const _BalanceRow({required this.state, required this.info});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = state.memberName(info.userId) ?? '?';
    final remaining = info.remaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 14,
        child: Row(
          children: [
            MemberAvatar(name: name, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoney(info.paid)} · ${context.l10n.spentLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              remaining.isNegative
                  ? '· ${formatMoney(remaining.abs())}'
                  : formatMoney(remaining),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: remaining.isNegative ? AppColors.negative : AppColors.positive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleExpenseTile extends StatelessWidget {
  final Expense expense;

  const _CycleExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final category = state.categoryFor(expense.categoryId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ),
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        child: Row(
          children: [
            CategoryIcon(category: category, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
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
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

String _cycleStatusLabel(AppLocalizations l10n, CycleStatus status) {
  switch (status) {
    case CycleStatus.active:
      return l10n.cycleStatusActive;
    case CycleStatus.readyToSettle:
      return l10n.cycleStatusReadyToSettle;
    case CycleStatus.settled:
      return l10n.cycleStatusSettled;
    case CycleStatus.closed:
      return l10n.cycleStatusClosed;
  }
}
