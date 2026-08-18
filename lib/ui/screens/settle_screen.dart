import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../../logic/settlements.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import 'settlement_form.dart';

class SettleScreen extends StatelessWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final balances = state.computeBalances();
    final proposals = state.settlementProposals();
    final history = state.settlementsInCycle;
    final hasExpenses = state.expensesInCycle.isNotEmpty;
    final totalOutstanding = balances.fold<int>(
        0, (sum, b) => sum + (b.remaining.isNegative ? -b.remaining.paisa : 0));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settleUp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (proposals.isEmpty)
            // With no expenses at all there is nothing to settle, so a plain
            // "All settled up!" would be misleading.
            if (hasExpenses)
              _AllSettledCard(totalOutstanding: Money(totalOutstanding))
            else
              const _NothingToSettleCard()
          else ...[
            _OutstandingCard(totalOutstanding: Money(totalOutstanding)),
            const SizedBox(height: 20),
            SectionHeader(title: l10n.whoOwesWhom),
            const SizedBox(height: 4),
            for (final proposal in proposals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Reveal(child: _ProposalCard(proposal: proposal)),
              ),
          ],
          if (proposals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.settleHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionHeader(title: l10n.settlementHistory),
            const SizedBox(height: 4),
            for (final settlement in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryRow(settlement: settlement),
              ),
          ],
          if (proposals.isEmpty && history.isEmpty)
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  final Money totalOutstanding;

  const _OutstandingCard({required this.totalOutstanding});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.accent,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryDark.withValues(alpha: 0.40),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.toBeSettled,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedMoney(
                  paisa: totalOutstanding.paisa,
                  formatter: (p) => formatMoney(Money(p)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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

class _AllSettledCard extends StatelessWidget {
  final Money totalOutstanding;

  const _AllSettledCard({required this.totalOutstanding});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.positiveSoft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.positive.withValues(alpha: 0.3),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.positive, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.allSettled,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.positive,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.allSettledMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.positive.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state for a Space with no expenses recorded yet: settling
/// "up" doesn't make sense when there is nothing to split or owe.
class _NothingToSettleCard extends StatelessWidget {
  const _NothingToSettleCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.nothingToSettleTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noSettlementsMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final SettlementProposal proposal;

  const _ProposalCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fromName = state.memberName(proposal.fromUserId) ?? '?';
    final toName = state.memberName(proposal.toUserId) ?? '?';
    final l10n = context.l10n;

    return SurfaceCard(
      child: Row(
        children: [
          _AvatarPair(fromName: fromName, toName: toName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.owes(fromName, toName),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(proposal.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.negative,
                  ),
                ),
              ],
            ),
          ),
          PressableScale(
            onTap: () => _openSettlement(context, state),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.settleAction,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettlement(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SettlementForm(
          fromUserId: proposal.fromUserId,
          toUserId: proposal.toUserId,
          amount: proposal.amount,
        ),
      ),
    );
  }
}

class _AvatarPair extends StatelessWidget {
  final String fromName;
  final String toName;

  const _AvatarPair({required this.fromName, required this.toName});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 42,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: MemberAvatar(name: fromName, size: 40),
          ),
          Positioned(
            right: 0,
            child: MemberAvatar(name: toName, size: 40, outline: true),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Settlement settlement;

  const _HistoryRow({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.positive, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fromTo(fromName, toName),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settlementMethodDay(
                    settlement.paymentMethod,
                    formatRelativeDay(settlement.date, l10n: l10n),
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(settlement.amount),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.positive,
            ),
          ),
        ],
      ),
    );
  }
}
