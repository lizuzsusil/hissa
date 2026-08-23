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
    final p = context.palette;
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

    return Scaffold(
      appBar: AppBar(title: Text(cycle.name)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderRadius: AppRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cycle.name,
                          style: AppText.titleL.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      StatusBadge(
                        label: _cycleStatusLabel(l10n, cycle.status),
                        tone: _cycleStatusTone(cycle.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _cycleRange(cycle),
                    style: AppText.bodyM.copyWith(
                      fontSize: 13,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.space?.cycleType == CycleType.custom
                        ? l10n.customCycle
                        : l10n.monthlyCycle,
                    style: AppText.labelM.copyWith(color: AppColors.primary),
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
            const SizedBox(height: AppSpacing.xl),
            if (balances.isNotEmpty) ...[
              SectionHeader(title: l10n.whoPaidThisCycle),
              const SizedBox(height: AppSpacing.sm),
              for (final b in balances) _BalanceRow(state: state, info: b),
              const SizedBox(height: AppSpacing.xl),
            ],
            SectionHeader(title: l10n.expenses),
            const SizedBox(height: AppSpacing.sm),
            if (expenses.isEmpty)
              SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.noExpensesInCycle,
                  style: AppText.bodyM.copyWith(color: p.textSecondary),
                ),
              )
            else
              for (final expense in expenses)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CycleExpenseTile(expense: expense),
                ),
          ],
        ),
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
    final p = context.palette;
    final cycles = state.closedCycles;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.previousCycles)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: cycles.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: Center(
                        child: Text(
                          l10n.noPreviousCycles,
                          style: AppText.bodyM.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final c in cycles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CycleDetailScreen(cycleId: c.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppGradients.tint(AppColors.primary),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: AppText.titleS.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _cycleRange(c),
                                    style: AppText.bodyM.copyWith(
                                      fontSize: 12.5,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              formatMoney(state.totalSpent(c.id)),
                              style: AppText.labelL.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Maps a cycle status to the shared semantic badge tone.
BadgeTone _cycleStatusTone(CycleStatus status) {
  switch (status) {
    case CycleStatus.active:
      return BadgeTone.positive;
    case CycleStatus.readyToSettle:
      return BadgeTone.warning;
    case CycleStatus.settled:
      return BadgeTone.brand;
    case CycleStatus.closed:
      return BadgeTone.neutral;
  }
}

class _StatLabel extends StatelessWidget {
  final String value;
  final String label;

  const _StatLabel({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppText.titleL.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppText.labelM.copyWith(color: p.textSecondary),
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
    final p = context.palette;
    final name = state.memberName(info.userId) ?? '?';
    final remaining = info.remaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        borderRadius: AppRadius.md,
        child: Row(
          children: [
            MemberAvatar(name: name, size: 34),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppText.labelL.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoney(info.paid)} · ${context.l10n.spentLabel}',
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              remaining.isNegative
                  ? '· ${formatMoney(remaining.abs())}'
                  : formatMoney(remaining),
              style: AppText.labelL.copyWith(
                fontWeight: FontWeight.w800,
                color:
                    remaining.isNegative ? AppColors.negative : AppColors.positive,
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
    final p = context.palette;
    final category = state.categoryFor(expense.categoryId);
    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ),
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description ?? l10n.expense,
                    style: AppText.titleS.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${state.memberName(expense.paidByUserId)} · ${formatRelativeDay(expense.date, l10n: l10n)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyM.copyWith(
                      fontSize: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(expense.amount),
              style: AppText.titleS.copyWith(fontWeight: FontWeight.w800),
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
