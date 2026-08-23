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
import '../../widgets/dialogs.dart';
import '../../widgets/motion.dart';
import '../../widgets/sheets.dart';
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
    final p = context.palette;
    final selectedIndex = options.indexWhere((o) => o.value == value);
    final clamp = selectedIndex < 0 ? 0 : selectedIndex;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.medium,
                curve: AppMotion.ease,
                left: clamp * width,
                width: width,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.26),
                    ),
                    boxShadow: [
                      ...AppShadows.card(dark: context.isDark),
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          child: SizedBox(
                            height: height - AppSpacing.sm,
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
                                        : p.textMuted,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
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
                                          : p.textSecondary,
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
    final p = context.palette;

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
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(AppColors.tertiary),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  hasEstimate
                      ? Icons.fact_check_outlined
                      : Icons.flag_outlined,
                  size: 20,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.estimateForMonth(formatMonthYear(month)),
                      style:
                          AppText.titleS.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.estimateSectionSubtitle,
                      style: AppText.caption.copyWith(color: p.textSecondary),
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
            const SizedBox(height: AppSpacing.lg - 2),
            Text(
              l10n.noEstimatesYet,
              style: AppText.bodyM.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noEstimatesMessage,
              style: AppText.labelM.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: p.textSecondary,
              ),
            ),
            if (onAddEstimate != null && showEmptyAction) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onAddEstimate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addEstimate),
              ),
            ],
          ] else ...[
            const SizedBox(height: AppSpacing.lg - 2),
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: l10n.spentSoFar,
                    value: formatMoneyCompact(spent),
                    color: p.textPrimary,
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
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: progressColor.withValues(alpha: 0.14),
                color: progressColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.spentOfEstimate(
                formatMoneyCompact(spent),
                formatMoneyCompact(estimated),
              ),
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
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
    final p = context.palette;
    final category = state.categoryFor(estimate.categoryId);

    return PressableScale(
      onTap: onEdit,
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estimate.description ?? l10n.estimatedExpense,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleS.copyWith(color: p.textPrimary),
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            l10n.estimatedExpense,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.overline.copyWith(
                              letterSpacing: 0.1,
                              fontSize: 10.5,
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
                          style:
                              AppText.caption.copyWith(color: p.textSecondary),
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
                  style: AppText.titleL.copyWith(
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: p.textPrimary,
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
                      const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.sm),
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
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 20,
        color: context.palette.textSecondary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: context.palette.surfaceAlt,
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
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.overline.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            color: p.textMuted,
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
  return showConfirmDialog(
    context: context,
    title: l10n.removeEstimateTitle,
    message: l10n.removeEstimateMessage,
    confirmLabel: l10n.removeEstimate,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
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
  await showAppSheet<void>(
    context: context,
    title: l10n.estimatedExpenses,
    builder: (sheetContext) {
      final p = sheetContext.palette;
      return Padding(
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
            Text(
              formatMonthYear(month),
              style: AppText.bodyM.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final estimate in estimates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                      child: EstimateTile(
                        estimate: estimate,
                        onEdit: () {
                          Navigator.pop(sheetContext);
                          showEstimatedExpenseSheet(
                            context,
                            estimate: estimate,
                          );
                        },
                        onRemove: () {
                          Navigator.pop(sheetContext);
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
          ],
        ),
      );
    },
  );
}
