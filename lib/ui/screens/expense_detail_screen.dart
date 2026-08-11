import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/cards.dart';
import '../widgets/category_icon.dart';
import '../widgets/buttons.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cycle = state.selectedCycle;
    final canEdit = cycle == null || cycle.status == CycleStatus.active;
    final category = state.categoryFor(expense.categoryId);
    final shares = state.sharesForExpense(expense.id);
    final payer = state.memberName(expense.paidByUserId) ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense details'),
        actions: [
          if (canEdit)
            IconAction(
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ExpenseFormScreen(expense: expense),
                ));
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
            child: Column(
              children: [
                CategoryIcon(category: category, size: 64),
                const SizedBox(height: 16),
                Text(
                  expense.description ?? 'Expense',
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${category?.name ?? 'General'} · ${formatFullDate(expense.date)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
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
                  label: 'Paid by',
                  value: payer,
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Split',
                  value: '${shares.length} person${shares.length == 1 ? '' : 's'}',
                ),
                if (expense.note != null) ...[
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Note',
                    value: expense.note!,
                  ),
                ],
                if (expense.receiptUrl != null) ...[
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.receipt_outlined,
                    label: 'Receipt',
                    value: 'Attached',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeaderLocal('Who pays what'),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                for (final share in shares)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        MemberAvatar(
                            name: state.memberName(share.userId) ?? '?',
                            size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.memberName(share.userId) ?? '?',
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (share.userId == expense.paidByUserId)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              'Paid',
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
                              fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!canEdit) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'This cycle is closed, so expenses can no longer be edited.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text(
          'Deleting an expense changes the current household balances for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Delete'),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
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
