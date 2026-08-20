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

/// Bottom sheet for adding or editing a planned (estimated) spending amount.
/// Everything here is scoped to Personal Mode and the language makes it
/// unambiguous that the amount is a plan, never an actual transaction. New
/// estimates are always attached to the current month.
Future<void> showEstimatedExpenseSheet(
  BuildContext context, {
  EstimatedExpense? estimate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceDark
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _EstimatedExpenseSheet(estimate: estimate),
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppGradients.tint(AppColors.tertiary),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_outlined : Icons.flag_outlined,
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
                          _isEdit
                              ? l10n.editEstimate
                              : l10n.estimateForMonth(
                                  formatMonthYear(
                                    DateTime(
                                      DateTime.now().year,
                                      DateTime.now().month,
                                    ),
                                  ),
                                ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 24),
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