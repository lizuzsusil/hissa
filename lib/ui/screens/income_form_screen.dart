import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../logic/splits.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

/// Add / edit a shared hissa contribution (Split Spaces only).
///
/// "Received by" records who physically holds the money; it does NOT decide
/// who benefits. The benefit is distributed across the selected members with
/// the same split rules used for expenses, so every balance, proposal and
/// settlement updates through the existing pipeline.
class IncomeFormScreen extends StatefulWidget {
  final HissaIncome? income;

  const IncomeFormScreen({super.key, this.income});

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  Money _amount = Money.zero();
  String? _categoryId;
  DateTime _date = DateTime.now();
  String? _receivedByUserId;
  Set<String> _participants = {};
  SplitType _splitType = SplitType.equal;
  Map<String, double> _percentages = {};

  bool get _isEdit => widget.income != null;
  bool _saving = false;
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    if (income != null) {
      _descriptionController.text = income.description;
      _noteController.text = income.note ?? '';
      _amount = income.amount;
      _categoryId = income.categoryId;
      _date = income.date;
      _receivedByUserId = income.receivedByUserId;
      _participants = Set.of(income.participantIds);
      _splitType = income.splitType;
      _percentages = Map.of(income.percentages);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Members eligible as participants: ungrouped members only — grouped
  /// members' finances are carried by their Member Group (Rule 8), which the
  /// balance calculator maps automatically.
  List<SpaceMember> _eligibleMembers(AppState state) {
    final grouped = state.groupedUserIds;
    return state.members.where((m) => !grouped.contains(m.userId)).toList();
  }

  void _ensureDefaults(AppState state) {
    if (_receivedByUserId == null && state.members.isNotEmpty) {
      // Default to the signed-in user when they are eligible.
      final me = state.currentUserId;
      final eligible = me != null && !state.groupedUserIds.contains(me);
      _receivedByUserId = eligible
          ? me
          : _eligibleMembers(state).firstOrNull?.userId;
    }
    if (_participants.isEmpty && state.members.isNotEmpty) {
      _participants = _eligibleMembers(state).map((m) => m.userId).toSet();
      if (!_participants.contains(_receivedByUserId)) {
        final receiver = _receivedByUserId;
        if (receiver != null && !state.groupedUserIds.contains(receiver)) {
          _participants.add(receiver);
        }
      }
    }
  }

  List<({String id, int paisa})> _previewShares(AppState state) {
    final ids = _participants.toList();
    final amounts = SplitCalculator.build(
      expenseId: 'preview',
      amount: _amount,
      participantIds: ids,
      type: _splitType,
      percentages: _percentages,
    );
    return [
      for (final share in amounts)
        (id: share.participantId, paisa: share.amount.paisa),
    ];
  }

  double get _percentageTotal => _percentages.values.fold(0, (a, b) => a + b);

  String? _validationMessage(AppState state) {
    final l10n = context.l10n;
    if (_descriptionController.text.trim().isEmpty) {
      return l10n.expenseDescriptionError;
    }
    if (_amount.isZero) return l10n.expenseAmountError;
    if (_receivedByUserId == null) return l10n.expensePayerError;
    if (_participants.isEmpty) return l10n.expenseParticipantError;
    if (_splitType == SplitType.percentage &&
        (_percentageTotal - 100).abs() > 0.01) {
      return l10n.expensePercentError;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _attemptedSave = true);
    final state = context.read<AppState>();
    if (_validationMessage(state) != null || _receivedByUserId == null) {
      return;
    }
    setState(() => _saving = true);
    final ok = widget.income == null
        ? await state.addHissaIncome(
            description: _descriptionController.text,
            amount: _amount,
            date: _date,
            receivedByUserId: _receivedByUserId!,
            categoryId: _categoryId,
            note: _noteController.text,
            participantIds: _participants.toList(),
            splitType: _splitType,
            percentages: _splitType == SplitType.percentage ? _percentages : {},
          )
        : await state.updateHissaIncome(
            widget.income!,
            description: _descriptionController.text,
            amount: _amount,
            date: _date,
            receivedByUserId: _receivedByUserId!,
            categoryId: _categoryId,
            note: _noteController.text,
            participantIds: _participants.toList(),
            splitType: _splitType,
            percentages: _splitType == SplitType.percentage ? _percentages : {},
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    Navigator.pop(context);
    showToast(
      context,
      _isEdit ? context.l10n.incomeUpdatedToast : context.l10n.incomeAddedToast,
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _ensureDefaults(state);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final members = _eligibleMembers(state);
    final error = _attemptedSave ? _validationMessage(state) : null;
    final receiverId = _receivedByUserId;
    final receiverName = receiverId == null
        ? l10n.you
        : (state.memberName(receiverId) ?? l10n.you);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editIncome : l10n.addIncome)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountField(
              value: _amount,
              label: l10n.amount,
              autofocus: !_isEdit,
              enabled: !_saving,
              errorText: _attemptedSave && _amount.isZero
                  ? l10n.expenseAmountError
                  : null,
              onChanged: (m) => setState(() => _amount = m),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.incomeDescriptionLabel,
                hintText: l10n.incomeDescriptionHint,
                prefixIcon: const Icon(Icons.savings_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 24),
            _Label(l10n.category),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in state.categories) _categoryChip(c)],
            ),
            const SizedBox(height: 24),
            _Label(l10n.date),
            const SizedBox(height: 10),
            _datePicker(isDark),
            const SizedBox(height: 24),
            _Label(l10n.receivedBy),
            const SizedBox(height: 4),
            Text(
              l10n.receivedByHint,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  _memberChip(
                    m,
                    selected: m.userId == _receivedByUserId,
                    onTap: () => setState(() {
                      _receivedByUserId = m.userId;
                      if (!_participants.contains(m.userId)) {
                        _participants.add(m.userId);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.positiveSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.positive,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.incomeSplitNote(receiverName),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppColors.positive.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Label(l10n.splitBetween),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  _memberChip(
                    m,
                    selected: _participants.contains(m.userId),
                    onTap: () => setState(() {
                      if (_participants.contains(m.userId)) {
                        if (_participants.length > 1) {
                          _participants.remove(m.userId);
                          _percentages.remove(m.userId);
                        }
                      } else {
                        _participants.add(m.userId);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.splitLabelEqual),
                  selected: _splitType == SplitType.equal,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                          _splitType = SplitType.equal;
                          _percentages = {};
                        }),
                ),
                ChoiceChip(
                  label: Text(l10n.splitLabelPercent),
                  selected: _splitType == SplitType.percentage,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                          _splitType = SplitType.percentage;
                          final even =
                              100 /
                              (_participants.isEmpty
                                  ? 1
                                  : _participants.length);
                          _percentages = {
                            for (final id in _participants) id: even,
                          };
                        }),
                ),
              ],
            ),
            if (_splitType == SplitType.percentage) ...[
              const SizedBox(height: 14),
              _percentageEditor(),
              if (_attemptedSave && (_percentageTotal - 100).abs() > 0.01)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.expensePercentError,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.negative,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            _Label(l10n.note),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              enabled: !_saving,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.noteOptionalHint,
                prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 28),
            if (_amount.isPositive && _participants.isNotEmpty)
              _sharePreview(state, l10n),
            if (error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.negativeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.negative,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.negative,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: _isEdit ? l10n.saveChanges : l10n.saveIncome,
              icon: _isEdit ? Icons.save_rounded : Icons.add_rounded,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(Category c) {
    final selected = _categoryId == c.id;
    final color = c.colorValue == null
        ? AppColors.primary
        : Color(c.colorValue!);
    return GestureDetector(
      onTap: _saving
          ? null
          : () => setState(() => _categoryId = selected ? null : c.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surfaceAltDark
                    : AppColors.surfaceAlt),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconForCodePoint(c.iconCodePoint), size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              c.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePicker(bool isDark) {
    return GestureDetector(
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
    );
  }

  Widget _memberChip(
    SpaceMember member, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(name: member.name, size: 22),
            const SizedBox(width: 7),
            Text(
              member.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _percentageEditor() {
    return Column(
      children: [
        for (final id in _participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    context.read<AppState>().memberName(id) ?? id,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    enabled: !_saving,
                    initialValue: ((_percentages[id] ?? 0)).toStringAsFixed(1),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}\.?\d{0,1}'),
                      ),
                    ],
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(suffixText: '%'),
                    onChanged: (v) => setState(() {
                      final parsed = double.tryParse(v) ?? 0;
                      _percentages[id] = parsed;
                    }),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sharePreview(AppState state, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceAltDark
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(l10n.splitPreview),
          const SizedBox(height: 10),
          for (final entry in _previewShares(state))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.memberName(entry.id) ?? '?',
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  Text(
                    '+ ${formatMoney(Money(entry.paisa))}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.positive,
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    );
  }
}
