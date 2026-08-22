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
import '../widgets/toasts.dart';
import 'settlement_form.dart';

class SettleScreen extends StatelessWidget {
  const SettleScreen({super.key});

  /// A proposal disappears from "who owes whom" once a pending request
  /// between the same two parties already covers its full amount.
  static bool _coveredByPendingRequest(
    SettlementProposal proposal,
    List<Settlement> pending,
  ) {
    return pending.any(
      (s) =>
          s.fromUserId == proposal.fromUserId &&
          s.toUserId == proposal.toUserId &&
          s.amount.paisa >= proposal.amount.paisa,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final balances = state.computeBalances();
    final pendingRequests = state.pendingSettlementRequests;
    final proposals = state
        .settlementProposals()
        .where((p) => !_coveredByPendingRequest(p, pendingRequests))
        .toList();
    final history = state.resolvedSettlements;
    final hasExpenses = state.expensesInCycle.isNotEmpty;
    final totalOutstanding = balances.fold<int>(
      0,
      (sum, b) => sum + (b.remaining.isNegative ? -b.remaining.paisa : 0),
    );
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settleUp)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            if (proposals.isEmpty && pendingRequests.isEmpty)
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
            if (pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(title: l10n.pendingRequestsSection),
              const SizedBox(height: 4),
              for (final request in pendingRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Reveal(
                    child: _PendingRequestRow(settlement: request),
                  ),
                ),
            ],
            if (proposals.isNotEmpty && pendingRequests.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.warning,
                    ),
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
            if (proposals.isEmpty &&
                pendingRequests.isEmpty &&
                history.isEmpty)
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static void openSettlementSheet(
    BuildContext context, {
    required String fromUserId,
    required String toUserId,
    required Money amount,
  }) {
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
          fromUserId: fromUserId,
          toUserId: toUserId,
          amount: amount,
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 28,
            ),
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.positive,
              size: 40,
            ),
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
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.nothingToSettleTitle,
        message: l10n.noSettlementsMessage,
      ),
    );
  }
}

/// One row of the "who owes whom" breakdown. Only the DEBTOR sees a Settle
/// action — settlement can only be initiated by the member who owes money.
class _ProposalCard extends StatelessWidget {
  final SettlementProposal proposal;

  const _ProposalCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myEntity = state.myFinancialEntityId;
    final fromName = state.memberName(proposal.fromUserId) ?? '?';
    final toName = state.memberName(proposal.toUserId) ?? '?';
    final l10n = context.l10n;
    final iAmDebtor = myEntity == proposal.fromUserId;
    final iAmCreditor = myEntity == proposal.toUserId;

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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
                // The creditor cannot record the payment themselves; they
                // wait for the debtor's request and approve it afterwards.
                if (iAmCreditor) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.awaitingDebtorRequest(fromName),
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (iAmDebtor)
            PressableScale(
              onTap: () => SettleScreen.openSettlementSheet(
                context,
                fromUserId: proposal.fromUserId,
                toUserId: proposal.toUserId,
                amount: proposal.amount,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
          Positioned(left: 0, child: MemberAvatar(name: fromName, size: 40)),
          Positioned(
            right: 0,
            child: MemberAvatar(name: toName, size: 40, outline: true),
          ),
        ],
      ),
    );
  }
}

/// A settlement request that still awaits the creditor's decision. The
/// creditor gets Approve / Reject actions; everyone else (including the
/// debtor) sees a waiting state.
class _PendingRequestRow extends StatelessWidget {
  final Settlement settlement;

  const _PendingRequestRow({required this.settlement});

  Future<void> _reject(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reject),
        content: Text(l10n.creditorApprovalNote(
          dialogContext.read<AppState>().memberName(settlement.fromUserId) ??
              '?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.reject,
              style: const TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final state = context.read<AppState>();
    final ok = await state.rejectSettlement(settlement.id);
    if (!context.mounted) return;
    showToast(
      context,
      ok
          ? context.l10n.settlementRejectedToast
          : context.l10n.groupRequestRejectFail,
      type: ok ? ToastType.warning : ToastType.danger,
    );
  }

  Future<void> _approve(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await state.approveSettlement(settlement.id);
    if (!context.mounted) return;
    showToast(
      context,
      ok
          ? context.l10n.settlementApprovedToast
          : context.l10n.groupRequestApprovedFail,
      type: ok ? ToastType.success : ToastType.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myEntity = state.myFinancialEntityId;
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final l10n = context.l10n;
    final iAmCreditor = settlement.isCreditor(myEntity);

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fromTo(fromName, toName),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  iAmCreditor
                      ? '${l10n.requestedBy} $fromName'
                      : l10n.waitingApprovalFrom(toName),
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
          if (iAmCreditor) ...[
            PressableScale(
              onTap: () => _approve(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  l10n.approve,
                  style: const TextStyle(
                    color: AppColors.positive,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: () => _reject(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.negative.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  l10n.reject,
                  style: const TextStyle(
                    color: AppColors.negative,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ] else
            _StatusChip(status: settlement.status),
        ],
      ),
    );
  }
}

/// A resolved settlement in the history list: approved/settled rows confirm
/// the payment, rejected rows let the debtor submit a new request.
class _HistoryRow extends StatelessWidget {
  final Settlement settlement;

  const _HistoryRow({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myEntity = state.myFinancialEntityId;
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final l10n = context.l10n;
    final rejected = settlement.status == SettlementStatus.rejected;
    final iAmDebtor =
        settlement.isDebtor(myEntity) && rejected;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: rejected
                  ? AppColors.negative.withValues(alpha: 0.10)
                  : AppColors.positive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              rejected
                  ? Icons.close_rounded
                  : Icons.check_circle_outline_rounded,
              color: rejected ? AppColors.negative : AppColors.positive,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fromTo(fromName, toName),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(settlement.amount),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: rejected ? AppColors.negative : AppColors.positive,
                ),
              ),
              const SizedBox(height: 4),
              if (iAmDebtor)
                PressableScale(
                  onTap: () => SettleScreen.openSettlementSheet(
                    context,
                    fromUserId: settlement.fromUserId,
                    toUserId: settlement.toUserId,
                    amount: settlement.amount,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      l10n.requestAgain,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                )
              else
                _StatusChip(status: settlement.status),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill visualising where a settlement stands in the approval flow.
class _StatusChip extends StatelessWidget {
  final SettlementStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String label;
    final Color color;
    switch (status) {
      case SettlementStatus.pendingApproval:
        label = l10n.pendingApproval;
        color = AppColors.warning;
      case SettlementStatus.approved:
      case SettlementStatus.paid:
        label = status == SettlementStatus.approved
            ? l10n.statusApproved
            : l10n.statusSettled;
        color = AppColors.positive;
      case SettlementStatus.rejected:
        label = l10n.statusRejected;
        color = AppColors.negative;
      case SettlementStatus.pending:
        label = l10n.statusPending;
        color = AppColors.textMuted;
      case SettlementStatus.partiallyPaid:
        label = l10n.statusPartiallyPaid;
        color = AppColors.textMuted;
      case SettlementStatus.cancelled:
        label = l10n.statusCancelled;
        color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
