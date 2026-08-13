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
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            const SizedBox(width: 12),
            IconAction(
              icon: Icons.delete_outline_rounded,
              foreground: AppColors.negative,
              background: AppColors.negativeSoft,
              onPressed: () => _confirmDelete(context, state),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatMoney(expense.amount),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatFullDate(expense.date),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
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
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      category?.name ?? l10n.general,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.paidBy,
                  value: payer,
                ),
                if (!isPersonal) ...[
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    label: l10n.split,
                    value: l10n.splitPersons(shares.length),
                  ),
                ],
                if (expense.note != null) ...[
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: l10n.note,
                    value: expense.note!,
                  ),
                ],
                if (expense.receiptUrl != null) ...[
                  const SizedBox(height: 14),
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
            const SizedBox(height: 20),
            SectionHeaderLocal(l10n.whoPaysWhat),
            const SizedBox(height: 8),
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  for (final share in shares)
                    if (share.groupId == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            MemberAvatar(
                              name: state.memberName(share.userId) ?? '?',
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.memberName(share.userId) ?? '?',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (share.userId == expense.paidByUserId)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Text(
                                  l10n.paid,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.positive,
                                  ),
                                ),
                              ),
                            Text(
                              formatMoney(share.amount),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  for (final g in expense.participantGroups) ...[
                    _GroupPartyRow(
                      group: g,
                      shares: shares
                          .where((s) => s.groupId == g.id)
                          .toList(),
                      memberName: (uid) =>
                          state.memberName(uid) ?? '?',
                      paidByUserId: expense.paidByUserId,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!canEdit) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                l10n.cycleClosedHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(l10n.deleteExpenseMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    final totalPaisa =
        shares.fold<int>(0, (sum, s) => sum + s.amount.paisa);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatMoney(Money(totalPaisa)),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final share in shares)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Row(
                children: [
                  MemberAvatar(name: memberName(share.userId), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      memberName(share.userId),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (share.userId == paidByUserId)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        context.l10n.paid,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.positive,
                        ),
                      ),
                    ),
                  Text(
                    formatMoney(share.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 50),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class SectionHeaderLocal extends StatelessWidget {
  final String title;

  const SectionHeaderLocal(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
