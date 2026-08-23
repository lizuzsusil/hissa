import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/money.dart';
import '../../../l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/amount_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheets.dart';
import '../../widgets/toasts.dart';

/// Bottom sheet for adding or editing a planned (estimated) spending amount.
/// Everything here is scoped to Personal Mode and the language makes it
/// unambiguous that the amount is a plan, never an actual transaction. New
/// estimates are always attached to the current month.
Future<void> showEstimatedExpenseSheet(
  BuildContext context, {
  EstimatedExpense? estimate,
}) {
  final l10n = context.l10n;
  final isEdit = estimate != null;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    title: isEdit
        ? l10n.editEstimate
        : l10n.estimateForMonth(
            formatMonthYear(
              DateTime(DateTime.now().year, DateTime.now().month),
            ),
          ),
    builder: (_) => _EstimatedExpenseSheet(estimate: estimate),
  );
}

class _EstimatedExpenseSheet extends StatefulWidget {
  final EstimatedExpense? estimate;

  const _EstimatedExpenseSheet({this.estimate});

  @override
  State<_EstimatedExpenseSheet> createState() => _EstimatedExpenseSheetState();
}

class _EstimatedExpenseSheetState extends State<_EstimatedExpenseSheet> {
  Money _amount = Money.zero();
  bool _attemptedSave = false;
  bool _saving = false;

  bool get _isEdit => widget.estimate != null;

  @override
  void initState() {
    super.initState();
    final estimate = widget.estimate;
    if (estimate != null) {
      _amount = estimate.amount;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _attemptedSave = true);
    if (_amount.isZero) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    try {
      if (_isEdit) {
        final estimate = widget.estimate!;
        // Preserve the original month and any previously set description;
        // only the planned amount is edited here.
        await state.updateEstimatedExpense(
          estimate,
          description: estimate.description ?? 'Planned expense',
          amount: _amount,
        );
      } else {
        await state.addEstimatedExpense(
          description: 'Planned expense',
          amount: _amount,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showToast(context, context.l10n.estimateSaveError,
            type: ToastType.danger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppGradients.tint(AppColors.tertiary),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_outlined : Icons.flag_outlined,
                      size: 20,
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.estimateSectionSubtitle,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AmountField(
                value: _amount,
                label: l10n.estimatedAmount,
                autofocus: !_isEdit,
                enabled: !_saving,
                errorText: _attemptedSave && _amount.isZero
                    ? l10n.estimateAmountError
                    : null,
                onChanged: (m) => setState(() => _amount = m),
              ),
              const SizedBox(height: AppSpacing.xxl - AppSpacing.xs),
              PrimaryButton(
                label: _isEdit ? l10n.updateEstimate : l10n.saveEstimate,
                icon: _isEdit ? Icons.save_rounded : Icons.add_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
