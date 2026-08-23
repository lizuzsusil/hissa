import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/toasts.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final isPersonal = state.isPersonalMode;
    final expenses = isPersonal
        ? state.personalExpenses
        : state.expensesInCycle;
    final cycle = state.selectedCycle;
    final l10n = context.l10n;

    final csv = _buildCsv(state, expenses);
    final lines = csv.split('\n').take(6).toList();
    final preview =
        lines.join('\n') + (lines.length < csv.split('\n').length ? '\n…' : '');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.export)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            HeroCard(
              gradient: AppColors.heroGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.table_chart_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.csvExport,
                        style: AppText.labelM.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    cycle?.name ?? l10n.currentCycleFallback,
                    style: AppText.displayM.copyWith(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.expensesAndTotal(
                      expenses.length,
                      formatMoney(state.totalSpent()),
                    ),
                    style: AppText.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.preview,
              style: AppText.titleM.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: SelectableText(
                  preview,
                  style: AppText.bodyM.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.copyCsv,
              icon: Icons.copy_rounded,
              onPressed: expenses.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: csv));
                      if (context.mounted) {
                        showToast(
                          context,
                          l10n.csvCopied,
                          type: ToastType.success,
                        );
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: l10n.shareReport,
              icon: Icons.ios_share_rounded,
              onPressed: expenses.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: csv));
                      if (context.mounted) {
                        showToast(
                          context,
                          l10n.csvCopiedShare,
                          type: ToastType.success,
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _buildCsv(AppState state, List expenses) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Description,Category,Paid By,Amount');
    for (final expense in expenses) {
      final category = state.categoryFor(expense.categoryId);
      buffer.writeln(
        '${formatShortDate(expense.date)},'
        '"${(expense.description ?? '').replaceAll('"', '""')}",'
        '"${category?.name ?? ''}",'
        '"${state.memberName(expense.paidByUserId) ?? ''}",'
        '${expense.amount.major}',
      );
    }
    return buffer.toString();
  }
}
