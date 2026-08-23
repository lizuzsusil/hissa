import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final l10n = context.l10n;
    final isPersonal = expense.cycleId == null;
    final cycle = state.selectedCycle;
    final cycleOpen = cycle == null || cycle.status == CycleStatus.active;
    final canEdit = cycleOpen && state.canEditExpense(expense);
    final category = state.categoryFor(expense.categoryId);
    final shares = state.sharesForExpense(expense.id);
    final payer = state.memberName(expense.paidByUserId) ?? l10n.unknown;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenseDetails),
        actions: [
          if (canEdit)
            IconAction(
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExpenseFormScreen(expense: expense),
                  ),
                );
              },
            ),
          if (canEdit) ...[
            const SizedBox(width: AppSpacing.md),
            IconAction(
              icon: Icons.delete_outline_rounded,
              foreground: AppColors.negative,
              background: AppColors.negativeSoft,
              onPressed: () => _confirmDelete(context, state),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl + AppSpacing.xs,
          ),
          children: [
            HeroCard(
              radius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main content is completely independent of
                  // the category pill and stays centered.
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          expense.description ?? l10n.expense,
                          textAlign: TextAlign.center,
                          style: AppText.titleL.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AnimatedMoney(
                          paisa: expense.amount.paisa,
                          formatter: (value) => formatMoney(Money(value)),
                          style: AppText.displayL.copyWith(
                            fontSize: 34,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          formatFullDate(expense.date),
                          textAlign: TextAlign.center,
                          style: AppText.bodyM.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Absolutely positioned category pill.
                  Positioned(
                    top: -12,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        category?.name ?? l10n.general,
                        style: AppText.labelM.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SurfaceCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: l10n.paidBy,
                    value: payer,
                  ),
                  if (!isPersonal) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.split,
                      value: l10n.splitPersons(shares.length),
                    ),
                  ],
                  if (expense.note != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      label: l10n.note,
                      value: expense.note!,
                    ),
                  ],
                  if (expense.receiptUrl != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.receipt_outlined,
                      label: l10n.receipt,
                      value: l10n.attached,
                    ),
                  ],
                ],
              ),
            ),
            if (!isPersonal) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.whoPaysWhat),
              const SizedBox(height: AppSpacing.sm),
              SurfaceCard(
                child: Column(
                  children: [
                    // New model: GROUP participant (single share with memberGroupId + snapshot)
                    for (final share in shares)
                      if (share.isGroup) ...[
                        _GroupSnapshotRow(
                          share: share,
                          memberName: (uid) => state.memberName(uid) ?? '?',
                          paidByUserId: expense.paidByUserId,
                        ),
                      ],
                    // Old Phase-6 model: expense-scoped participant groups
                    for (final g in expense.participantGroups) ...[
                      _GroupPartyRow(
                        group: g,
                        shares: shares
                            .where((s) => s.expenseGroupId == g.id)
                            .toList(),
                        memberName: (uid) => state.memberName(uid) ?? '?',
                        paidByUserId: expense.paidByUserId,
                      ),
                    ],
                    // Individual participants (USER type)
                    for (final share in shares)
                      if (!share.isGroup && share.userId != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              MemberAvatar(
                                name: state.memberName(share.userId!) ?? '?',
                                size: 36,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  state.memberName(share.userId!) ?? '?',
                                  style: AppText.titleS.copyWith(
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              if (share.userId == expense.paidByUserId)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    l10n.paid,
                                    style: AppText.caption.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.positive,
                                    ),
                                  ),
                                ),
                              Text(
                                formatMoney(share.amount),
                                style: AppText.titleS.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
            if (!canEdit) ...[
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  expense.createdBy == null
                      ? l10n.legacyExpenseHint
                      : l10n.cycleClosedHint,
                  textAlign: TextAlign.center,
                  style: AppText.bodyM.copyWith(
                    fontSize: 13,
                    color: p.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteExpenseTitle,
      message: l10n.deleteExpenseMessage,
      confirmLabel: l10n.delete,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed) {
      await state.deleteExpense(expense.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _GroupPartyRow extends StatelessWidget {
  final ParticipantGroup group;
  final List<ExpenseShare> shares;
  final String Function(String) memberName;
  final String paidByUserId;

  const _GroupPartyRow({
    required this.group,
    required this.shares,
    required this.memberName,
    required this.paidByUserId,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final totalPaisa = shares.fold<int>(0, (sum, s) => sum + s.amount.paisa);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(AppColors.primary),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  group.name,
                  style: AppText.titleS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                formatMoney(Money(totalPaisa)),
                style: AppText.titleS.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final share in shares)
            if (share.userId != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 36 + AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    MemberAvatar(name: memberName(share.userId!), size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        memberName(share.userId!),
                        style: AppText.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    if (share.userId == paidByUserId)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Text(
                          context.l10n.paid,
                          style: AppText.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.positive,
                          ),
                        ),
                      ),
                    Text(
                      formatMoney(share.amount),
                      style: AppText.bodyM.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textSecondary,
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

class _GroupSnapshotRow extends StatelessWidget {
  final ExpenseShare share;
  final String Function(String) memberName;
  final String paidByUserId;

  const _GroupSnapshotRow({
    required this.share,
    required this.memberName,
    required this.paidByUserId,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final snapshot = share.groupSnapshot;
    final members = snapshot?.allUserIds ?? [];
    final totalPaisa = share.amount.paisa;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(AppColors.primary),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  snapshot?.ownerUserId != null
                      ? '${memberName(snapshot!.ownerUserId)}\'s Group'
                      : 'Member Group',
                  style: AppText.titleS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                formatMoney(Money(totalPaisa)),
                style: AppText.titleS.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final uid in members)
              Padding(
                padding: const EdgeInsets.only(
                  left: 36 + AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    MemberAvatar(name: memberName(uid), size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        memberName(uid),
                        style: AppText.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    if (uid == paidByUserId)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Text(
                          context.l10n.paid,
                          style: AppText.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.positive,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: AppText.labelL.copyWith(color: p.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.xxxl + AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: AppText.labelL.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
