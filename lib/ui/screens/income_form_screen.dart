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

  /// Members eligible as individual participants: ungrouped members only —
  /// grouped members' finances are carried by their Member Group (Rule 8),
  /// which appears as its own selectable party below.
  List<SpaceMember> _eligibleMembers(AppState state) {
    final grouped = state.groupedUserIds;
    return state.members.where((m) => !grouped.contains(m.userId)).toList();
  }

  /// Whether [id] refers to an active Member Group (a single financial
  /// participant) rather than an individual member.
  bool _isGroupId(AppState state, String id) {
    return state.activeMemberGroups.any((g) => g.id == id);
  }

  /// The split parties currently in effect, mirroring the expense form:
  /// ungrouped members are individual parties, each selected Member Group is
  /// ONE party whose share is never divided between its members.
  List<SplitParty> _parties(AppState state) {
    return [
      for (final id in _participants)
        _isGroupId(state, id)
            ? SplitParty.group(
                groupId: id,
                name: state.memberName(id) ?? id,
                userIds: const [],
              )
            : SplitParty.individual(id),
    ];
  }

  void _ensureDefaults(AppState state) {
    final groups = state.activeMemberGroups;
    if (_receivedByUserId == null && state.members.isNotEmpty) {
      // Default to the signed-in user when they participate as an
      // individual; otherwise fall back to the first eligible party.
      final me = state.currentUserId;
      final eligible = me != null && !state.groupedUserIds.contains(me);
      _receivedByUserId = eligible
          ? me
          : (_eligibleMembers(state).firstOrNull?.userId ??
                groups.firstOrNull?.id);
    }
    if (_participants.isEmpty && state.members.isNotEmpty) {
      // Preselect every ungrouped member AND every active Member Group,
      // exactly like the expense form does.
      _participants = _eligibleMembers(state)
          .map((m) => m.userId)
          .followedBy(groups.map((g) => g.id))
          .toSet();
      if (!_participants.contains(_receivedByUserId)) {
        final receiver = _receivedByUserId;
        if (receiver != null) {
          if (!state.groupedUserIds.contains(receiver) ||
              groups.any((g) => g.id == receiver)) {
            _participants.add(receiver);
          }
        }
      }
    }
  }

  List<({String id, int paisa})> _previewShares(AppState state) {
    final amounts = SplitCalculator.buildGrouped(
      expenseId: 'preview',
      amount: _amount,
      parties: _parties(state),
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
            // "Received by" sits directly after the source so it is never
            // lost below the fold: it is core to what a household income is.
            _Label(l10n.receivedBy),
            const SizedBox(height: 4),
            Text(
              l10n.receivedByHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in members)
                  _receiverChip(m, selected: m.userId == _receivedByUserId),
                // Member Groups are financial participants too: they may
                // receive household income on behalf of their members.
                for (final g in state.activeMemberGroups)
                  _groupReceiverChip(g, selected: g.id == _receivedByUserId),
              ],
            ),
            if (members.isEmpty && state.activeMemberGroups.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.expenseParticipantError,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.negative,
                ),
              ),
            ],
            const SizedBox(height: 14),
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
            _buildCategoryPicker(state.categories),
            const SizedBox(height: 24),
            _Label(l10n.date),
            const SizedBox(height: 10),
            _datePicker(isDark),
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
                // Each Member Group joins the split as a SINGLE participant —
                // its share is never divided between its members.
                for (final g in state.activeMemberGroups)
                  _groupChip(
                    state,
                    g,
                    selected: _participants.contains(g.id),
                    onTap: () => setState(() {
                      if (_participants.contains(g.id)) {
                        if (_participants.length > 1) {
                          _participants.remove(g.id);
                          _percentages.remove(g.id);
                        }
                      } else {
                        _participants.add(g.id);
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

  /// The category picker mirrors Add Expense exactly: two horizontally
  /// scrollable rows of icon+name chips, tap-to-select (no toggle-off), so
  /// both forms manage categories identically.
  Widget _buildCategoryPicker(List<Category> categories) {
    final midpoint = (categories.length / 2).ceil();
    final firstRow = categories.take(midpoint).toList();
    final secondRow = categories.skip(midpoint).toList();

    Widget categoryChip(Category c) {
      final selected = _categoryId == c.id;

      return GestureDetector(
        onTap: _saving ? null : () => setState(() => _categoryId = c.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _colorOf(c).withValues(alpha: 0.16)
                : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceAltDark
                      : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _colorOf(c) : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconForCodePoint(c.iconCodePoint),
                size: 16,
                color: _colorOf(c),
              ),
              const SizedBox(width: 6),
              Text(
                c.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? _colorOf(c) : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget categoryRow(List<Category> items) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            categoryChip(items[i]),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(context.l10n.category),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categoryRow(firstRow),
              const SizedBox(height: 10),
              categoryRow(secondRow),
            ],
          ),
        ),
      ],
    );
  }

  Color _colorOf(Category c) =>
      c.colorValue == null ? AppColors.primary : Color(c.colorValue!);

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

  /// Prominent single-select chip for "Received by". Always outlined so it
  /// is visible in both themes; the selected party gets a filled primary
  /// style plus a check icon.
  Widget _receiverChip(SpaceMember member, {required bool selected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _saving
          ? null
          : () => setState(() {
              _receivedByUserId = member.userId;
              if (!_participants.contains(member.userId)) {
                _participants.add(member.userId);
              }
            }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(name: member.name, size: 26),
            const SizedBox(width: 8),
            Text(
              member.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : null,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  size: 17, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  /// "Received by" chip for a Member Group. A group is one financial
  /// participant: the income it receives belongs to the household and its
  /// benefit still splits across all selected parties.
  Widget _groupReceiverChip(MemberGroup group, {required bool selected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _saving
          ? null
          : () => setState(() {
              _receivedByUserId = group.id;
              if (!_participants.contains(group.id)) {
                _participants.add(group.id);
              }
            }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: AppGradients.tint(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              group.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : null,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  size: 17, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  /// Multi-select split chip for a Member Group in "Split between".
  Widget _groupChip(
    AppState state,
    MemberGroup group, {
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
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: AppGradients.tint(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              group.name,
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
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: selected ? 1.6 : 1,
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
