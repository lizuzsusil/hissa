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
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import '../widgets/sheets.dart';
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl * 2 + AppSpacing.xl,
          ),
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
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.whoOwesWhom),
              const SizedBox(height: AppSpacing.xs),
              for (final proposal in proposals)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Reveal(child: _ProposalCard(proposal: proposal)),
                ),
            ],
            if (pendingRequests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              SectionHeader(title: l10n.pendingRequestsSection),
              const SizedBox(height: AppSpacing.xs),
              for (final request in pendingRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Reveal(child: _PendingRequestRow(settlement: request)),
                ),
            ],
            if (proposals.isNotEmpty && pendingRequests.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              InfoBanner(
                icon: Icons.lightbulb_outline_rounded,
                message: l10n.settleHint,
                tone: InfoTone.warning,
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              SectionHeader(title: l10n.settlementHistory),
              const SizedBox(height: AppSpacing.xs),
              for (final settlement in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _HistoryRow(settlement: settlement),
                ),
            ],
            if (proposals.isEmpty && pendingRequests.isEmpty && history.isEmpty)
              const SizedBox(height: AppSpacing.xxl),
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
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      maxHeightFactor: 0.92,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
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

/// Accent-gradient statement of everything still awaiting settlement.
class _OutstandingCard extends StatelessWidget {
  final Money totalOutstanding;

  const _OutstandingCard({required this.totalOutstanding});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: HeroCard(
        gradient: AppGradients.accent,
        radius: BorderRadius.circular(AppRadius.xl),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.toBeSettled,
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedMoney(
                    paisa: totalOutstanding.paisa,
                    formatter: (p) => formatMoney(Money(p)),
                    style: AppText.displayM.copyWith(
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Celebratory all-clear shown once every balance is zero.
class _AllSettledCard extends StatelessWidget {
  final Money totalOutstanding;

  const _AllSettledCard({required this.totalOutstanding});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dark = context.isDark;
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(
          AppColors.positive,
          alpha: dark ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(
                AppColors.positive,
                alpha: dark ? 0.22 : 0.16,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.positive.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.positive,
              size: 36,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.allSettled,
            style: AppText.titleL.copyWith(color: AppColors.positive),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.allSettledMessage,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: p.textSecondary),
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
    final p = context.palette;
    final iAmDebtor = myEntity == proposal.fromUserId;
    final iAmCreditor = myEntity == proposal.toUserId;

    return SurfaceCard(
      child: Row(
        children: [
          _AvatarPair(fromName: fromName, toName: toName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.owes(fromName, toName),
                  style: AppText.titleS.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(proposal.amount),
                  style: AppText.bodyL.copyWith(
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
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (iAmDebtor)
            _MiniPillButton(
              label: l10n.settleAction,
              background: AppColors.secondary,
              foreground: Colors.white,
              onTap: () => SettleScreen.openSettlementSheet(
                context,
                fromUserId: proposal.fromUserId,
                toUserId: proposal.toUserId,
                amount: proposal.amount,
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
/// debtor) sees a waiting state. Layout is multi-row so the approve/reject
/// actions never cramp the text.
class _PendingRequestRow extends StatelessWidget {
  final Settlement settlement;

  const _PendingRequestRow({required this.settlement});

  Future<void> _reject(BuildContext context) async {
    final l10n = context.l10n;
    final debtorName =
        context.read<AppState>().memberName(settlement.fromUserId) ?? '?';
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.reject,
      message: l10n.creditorApprovalNote(debtorName),
      confirmLabel: l10n.reject,
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed || !context.mounted) return;
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

  void _showDetail(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: context.l10n.requestSettlementTitle,
      builder: (_) => _SettlementDetailSheet(settlement: settlement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myEntity = state.myFinancialEntityId;
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final l10n = context.l10n;
    final p = context.palette;
    final dark = context.isDark;
    final iAmCreditor = settlement.isCreditor(myEntity);

    return PressableScale(
      onTap: () => _showDetail(context),
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(AppColors.warning, alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fromTo(fromName, toName),
                        style: AppText.titleS.copyWith(color: p.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        iAmCreditor
                            ? '${l10n.requestedBy} $fromName'
                            : l10n.waitingApprovalFrom(toName),
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                _statusBadge(settlement.status, context),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MetaPill(
                  icon: Icons.payments_outlined,
                  label: formatMoney(settlement.amount),
                ),
                _MetaPill(
                  icon: Icons.account_balance_wallet_outlined,
                  label: settlement.paymentMethod,
                ),
                _MetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: formatShortDate(settlement.date),
                ),
              ],
            ),
            if (settlement.note != null &&
                settlement.note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                settlement.note!,
                style: AppText.bodyM.copyWith(
                  color: p.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (iAmCreditor)
              Row(
                children: [
                  Expanded(
                    child: _MiniPillButton(
                      label: l10n.approve,
                      background: AppColors.positive,
                      foreground: Colors.white,
                      onTap: () => _approve(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MiniPillButton(
                      label: l10n.reject,
                      background: dark
                          ? AppColors.negative.withValues(alpha: 0.16)
                          : AppColors.negativeSoft,
                      foreground: AppColors.negative,
                      onTap: () => _reject(context),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.creditorApprovalNote(toName),
                      style: AppText.caption.copyWith(color: p.textMuted),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: p.textSecondary,
            ),
          ),
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

  void _showDetail(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: context.l10n.settlementHistory,
      builder: (_) => _SettlementDetailSheet(settlement: settlement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myEntity = state.myFinancialEntityId;
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final l10n = context.l10n;
    final p = context.palette;
    final rejected = settlement.status == SettlementStatus.rejected;
    final iAmDebtor = settlement.isDebtor(myEntity) && rejected;

    return PressableScale(
      onTap: () => _showDetail(context),
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(
                      rejected ? AppColors.negative : AppColors.positive,
                      alpha: 0.12,
                    ),
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
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fromTo(fromName, toName),
                        style: AppText.titleS.copyWith(color: p.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settlementMethodDay(
                          settlement.paymentMethod,
                          formatRelativeDay(settlement.date, l10n: l10n),
                        ),
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(settlement.amount),
                      style: AppText.titleS.copyWith(
                        fontWeight: FontWeight.w800,
                        color: rejected
                            ? AppColors.negative
                            : AppColors.positive,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _statusBadge(settlement.status, context),
                  ],
                ),
              ],
            ),
            if (iAmDebtor) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: _MiniPillButton(
                  label: l10n.requestAgain,
                  background: p.surfaceAlt,
                  foreground: p.textSecondary,
                  onTap: () => SettleScreen.openSettlementSheet(
                    context,
                    fromUserId: settlement.fromUserId,
                    toUserId: settlement.toUserId,
                    amount: settlement.amount,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen detail for any settlement — pending, approved or rejected.
/// Tapped from the dashboard rows so the user can see method, dates, note
/// and status without cramping the list row.
class _SettlementDetailSheet extends StatelessWidget {
  final Settlement settlement;
  const _SettlementDetailSheet({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final l10n = context.l10n;
    final fromName = state.memberName(settlement.fromUserId) ?? '?';
    final toName = state.memberName(settlement.toUserId) ?? '?';
    final fromAvatar = state.memberAvatarUrl(settlement.fromUserId);
    final toAvatar = state.memberAvatarUrl(settlement.toUserId);

    return SingleChildScrollView(
      child: Padding(
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
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        MemberAvatar(
                          name: fromName,
                          avatarUrl: fromAvatar,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          fromName,
                          textAlign: TextAlign.center,
                          style: AppText.labelL.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.pays,
                          style: AppText.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        MemberAvatar(
                          name: toName,
                          avatarUrl: toAvatar,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          toName,
                          textAlign: TextAlign.center,
                          style: AppText.labelL.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.receives,
                          style: AppText.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _AmountWithPillTile(
                    amount: formatMoney(settlement.amount),
                    method: settlement.paymentMethod,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  'Status: ',
                  style: AppText.labelM.copyWith(color: p.textMuted),
                ),
                _statusBadge(settlement.status, context),
              ],
            ),
            if (settlement.note != null &&
                settlement.note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.note,
                style: AppText.labelM.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  settlement.note!,
                  style: AppText.bodyM.copyWith(color: p.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: p.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Paid: ${formatShortDate(settlement.date)}',
                  style: AppText.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
            if (settlement.respondedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: p.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Responded: ${formatShortDate(settlement.respondedAt!)}',
                    style: AppText.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountWithPillTile extends StatelessWidget {
  final String amount;
  final String method;
  const _AmountWithPillTile({required this.amount, required this.method});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.amount,
            style: AppText.caption.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  amount,
                  style: AppText.titleM.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Text(
                    method,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact pill action shared by settle / approve / reject / request-again.
class _MiniPillButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _MiniPillButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.labelM.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// Maps a settlement lifecycle state onto the shared [StatusBadge] tones.
StatusBadge _statusBadge(SettlementStatus status, BuildContext context) {
  final l10n = context.l10n;
  switch (status) {
    case SettlementStatus.pendingApproval:
      return StatusBadge(label: l10n.pendingApproval, tone: BadgeTone.warning);
    case SettlementStatus.approved:
    case SettlementStatus.paid:
      return StatusBadge(
        label: status == SettlementStatus.approved
            ? l10n.statusApproved
            : l10n.statusSettled,
        tone: BadgeTone.positive,
      );
    case SettlementStatus.rejected:
      return StatusBadge(label: l10n.statusRejected, tone: BadgeTone.negative);
    case SettlementStatus.partiallyPaid:
      return StatusBadge(label: l10n.statusPartiallyPaid, tone: BadgeTone.info);
    case SettlementStatus.pending:
      return StatusBadge(label: l10n.statusPending, tone: BadgeTone.neutral);
    case SettlementStatus.cancelled:
      return StatusBadge(label: l10n.statusCancelled, tone: BadgeTone.neutral);
  }
}
