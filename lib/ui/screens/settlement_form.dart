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
import '../widgets/cards.dart';
import '../widgets/form_bits.dart';
import '../widgets/misc.dart';
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
    final p = context.palette;
    final l10n = context.l10n;
    final fromName = state.memberName(widget.fromUserId) ?? '?';
    final toName = state.memberName(widget.toUserId) ?? '?';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          l10n.requestSettlementTitle,
          style: AppText.titleL.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MemberAvatar(name: fromName, size: 40),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      fromName,
                      textAlign: TextAlign.center,
                      style: AppText.labelL.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.pays,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    MemberAvatar(name: toName, size: 40),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      toName,
                      textAlign: TextAlign.center,
                      style: AppText.labelL.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.receives,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AmountField(
          value: _amount,
          label: l10n.amount,
          errorText: _amountError,
          onChanged: (m) => setState(() => _amount = m),
        ),
        Center(
          child: Text(
            l10n.maxOutstanding(formatMoney(_maxOutstanding(state))),
            style: AppText.labelM.copyWith(color: p.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InfoBanner(
          icon: Icons.hourglass_top_rounded,
          message: l10n.creditorApprovalNote(toName),
          tone: InfoTone.warning,
        ),
        const SizedBox(height: AppSpacing.lg),
        FormLabel(l10n.paymentMethod),
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
        const SizedBox(height: AppSpacing.lg),
        DatePickerField(
          value: _date,
          format: formatShortDate,
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
        ),
        const SizedBox(height: AppSpacing.lg),
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
        // Bottom inset so the button never hides behind the keyboard / gesture bar.
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? AppSpacing.md : 0),
      ],
    ),
    );
  }
}
