import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

/// Step 1 of the Split-Mode approval flow: opened by the DEBTOR only. The
/// debtor picks the amount (capped at what is still outstanding), a payment
/// method and submits a settlement request. Nothing is marked settled until
/// the creditor approves the request.
class SettlementForm extends StatefulWidget {
  final String fromUserId;
  final String toUserId;

  /// Suggested amount (the pairwise outstanding). Still editable by the
  /// debtor for partial settlements.
  final Money amount;

  const SettlementForm({
    super.key,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  State<SettlementForm> createState() => _SettlementFormState();
}

class _SettlementFormState extends State<SettlementForm> {
  late String _method;
  DateTime _date = DateTime.now();
  Money _amount = Money.zero();
  final _noteController = TextEditingController();
  bool _saving = false;
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    _method = kPaymentMethods.first;
    _amount = widget.amount;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Money _maxOutstanding(AppState state) =>
      state.outstandingBetween(widget.fromUserId, widget.toUserId);

  String? get _amountError {
    if (!_attemptedSave) return null;
    final state = context.read<AppState>();
    final max = _maxOutstanding(state);
    if (_amount.isZero) return context.l10n.expenseAmountError;
    if (_amount.paisa > max.paisa) {
      return context.l10n.amountExceedsOutstanding;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _attemptedSave = true);
    final state = context.read<AppState>();
    final max = _maxOutstanding(state);
    if (_amount.isZero || _amount.paisa > max.paisa) return;

    setState(() => _saving = true);
    final ok = await state.requestSettlement(
      toUserId: widget.toUserId,
      amount: _amount,
      paymentMethod: _method,
      date: _date,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showToast(
        context,
        context.l10n.amountExceedsOutstanding,
        type: ToastType.danger,
      );
      return;
    }
    Navigator.pop(context);
    final creditorName = state.memberName(widget.toUserId) ?? '?';
    if (mounted) {
      showToast(
        context,
        context.l10n.settlementRequestedToast(creditorName),
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final fromName = state.memberName(widget.fromUserId) ?? '?';
    final toName = state.memberName(widget.toUserId) ?? '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.requestSettlementTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              MemberAvatar(name: fromName, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fromName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.pays,
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
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      toName,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.receives,
                      textAlign: TextAlign.end,
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
              const SizedBox(width: 8),
              MemberAvatar(name: toName, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AmountField(
          value: _amount,
          label: l10n.amount,
          errorText: _amountError,
          onChanged: (m) => setState(() => _amount = m),
        ),
        Center(
          child: Text(
            l10n.maxOutstanding(formatMoney(_maxOutstanding(state))),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.creditorApprovalNote(toName),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.paymentMethod,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in kPaymentMethods)
              ChoiceChip(
                label: Text(method),
                selected: _method == method,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _method = method),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _saving
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  formatShortDate(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          enabled: !_saving,
          decoration: InputDecoration(
            hintText: l10n.noteOptionalHint,
            prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: l10n.requestSettlementAction,
          icon: Icons.send_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
