import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/money.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/motion.dart';
import 'estimated_expense_sheet.dart';

/// Constrains personal-space content to a comfortable reading width on large
/// screens so the redesigned Personal Mode feels intentional on desktop and
/// tablet while staying full-width on phones.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 1100
        ? 780.0
        : width >= 640
        ? 620.0
        : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A labeled value in a [SegmentedControl].
class SegmentOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A pill-style segmented control with an animated sliding indicator, used for
/// the Insights graph filter and spending-period toggle so the active choice
/// is always obvious.
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 44,
    this.fontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = options.indexWhere((o) => o.value == value);
    final clamp = selectedIndex < 0 ? 0 : selectedIndex;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: clamp * width,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: cardShadow(opacity: isDark ? 0.35 : 0.10),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        selected: option.value == value,
                        button: true,
                        child: InkWell(
                          onTap: () {
                            if (option.value != value) onChanged(option.value);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: height - 8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (option.icon != null) ...[
                                  Icon(
                                    option.icon,
                                    size: fontSize + 3,
                                    color: option.value == value
                                        ? AppColors.primary
                                        : isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    option.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: option.value == value
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: option.value == value
                                          ? AppColors.primary
                                          : isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A compact summary comparing actual spending against a month's estimate.
/// Used on the Personal dashboard and the Monthly Insights view. Never mixes
/// the estimate into actual spending figures — it only visualizes the two side
/// by side so the distinction stays obvious.
class EstimateProgressCard extends StatelessWidget {
  final DateTime month;
  final Money spent;
  final Money estimated;
  final VoidCallback? onAddEstimate;
  final VoidCallback? onManageEstimates;
  final bool showEmptyAction;

  const EstimateProgressCard({
    super.key,
    required this.month,
    required this.spent,
    required this.estimated,
    this.onAddEstimate,
    this.onManageEstimates,
    this.showEmptyAction = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasEstimate = !estimated.isZero;
    final fraction =
        estimated.isZero ? 0.0 : (spent.paisa / estimated.paisa).clamp(0.0, 1.0);
    final over = spent - estimated;
    final remaining = estimated - spent;

    final progressColor = !hasEstimate
        ? AppColors.tertiary
        : over.isPositive
        ? AppColors.negative
        : AppColors.primary;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(
                    hasEstimate ? AppColors.tertiary : AppColors.tertiary,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasEstimate
                      ? Icons.fact_check_outlined
                      : Icons.flag_outlined,
                  size: 20,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.estimateForMonth(formatMonthYear(month)),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.estimateSectionSubtitle,
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
              if (hasEstimate && onManageEstimates != null)
                _RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: l10n.editEstimate,
                  onTap: onManageEstimates,
                ),
            ],
          ),
          if (!hasEstimate) ...[
            const SizedBox(height: 14),
            Text(
              l10n.noEstimatesYet,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noEstimatesMessage,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            if (onAddEstimate != null && showEmptyAction) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAddEstimate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addEstimate),
              ),
            ],
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: l10n.spentSoFar,
                    value: formatMoneyCompact(spent),
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    label: l10n.estimatedTotalShort,
                    value: formatMoneyCompact(estimated),
                    color: AppColors.tertiary,
                  ),
                ),
                if (over.isPositive)
                  Expanded(
                    child: _StatColumn(
                      label: l10n.overEstimateBy(''),
                      value: formatMoneyCompact(over, showSymbol: false),
                      color: AppColors.negative,
                    ),
                  )
                else
                  Expanded(
                    child: _StatColumn(
                      label: l10n.remainingFromEstimate,
                      value: formatMoneyCompact(remaining, showSymbol: false),
                      color: AppColors.positive,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: progressColor.withValues(alpha: 0.14),
                color: progressColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.spentOfEstimate(
                formatMoneyCompact(spent),
                formatMoneyCompact(estimated),
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single planned amount shown in the Estimates list. Tapping it opens the
/// edit sheet; a trailing menu offers remove.
class EstimateTile extends StatelessWidget {
  final EstimatedExpense estimate;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const EstimateTile({
    super.key,
    required this.estimate,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = state.categoryFor(estimate.categoryId);

    return PressableScale(
      onTap: onEdit,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        child: Row(
          children: [
            CategoryIcon(category: category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estimate.description ?? l10n.estimatedExpense,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.estimatedExpense,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          formatMonthYear(estimate.month),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatMoney(estimate.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.estimatedExpense,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.editEstimate),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.negative,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.removeEstimate,
                        style: const TextStyle(color: AppColors.negative),
                      ),
                    ],
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

/// Small circular icon button used inside cards.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 20,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? AppColors.surfaceAltDark
            : AppColors.surfaceAlt,
        minimumSize: const Size(36, 36),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirmation dialog before removing an estimate.
Future<bool> confirmRemoveEstimate(BuildContext context) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.removeEstimateTitle),
      content: Text(l10n.removeEstimateMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            l10n.removeEstimate,
            style: const TextStyle(color: AppColors.negative),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows the full list of estimates for [month] in a bottom sheet, allowing
/// add / edit / remove. Falls back to the add-estimate sheet when the month
/// has no estimates yet.
Future<void> showMonthEstimatesSheet(
  BuildContext context, {
  required DateTime month,
}) async {
  final l10n = context.l10n;
  final estimates =
      context.read<AppState>().estimatedExpensesForMonth(month);
  if (estimates.isEmpty) {
    await showEstimatedExpenseSheet(context);
    return;
  }
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.estimatedExpenses,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMonthYear(month),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final estimate in estimates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EstimateTile(
                        estimate: estimate,
                        onEdit: () {
                          Navigator.pop(context);
                          showEstimatedExpenseSheet(
                            context,
                            estimate: estimate,
                          );
                        },
                        onRemove: () {
                          Navigator.pop(context);
                          final appState = context.read<AppState>();
                          confirmRemoveEstimate(context).then((ok) {
                            if (ok) {
                              appState.deleteEstimatedExpense(estimate.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}