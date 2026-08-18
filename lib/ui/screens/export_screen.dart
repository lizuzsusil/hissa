import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
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
                      const SizedBox(width: 8),
                      Text(
                        l10n.csvExport,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cycle?.name ?? l10n.currentCycleFallback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.expensesAndTotal(
                      expenses.length,
                      formatMoney(state.totalSpent()),
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.preview,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              child: SelectableText(
                preview,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 10),
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
