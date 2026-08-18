import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  // Persistent per-party controllers for the percentage / custom amount
  // inputs. Recreating a controller on every rebuild makes the TextField drop
  // focus after each keystroke, so these are created once per party and
  // reused (and disposed) alongside the input fields.
  final Map<String, TextEditingController> _pctControllers = {};
  final Map<String, FocusNode> _pctFocusNodes = {};
  final Map<String, TextEditingController> _amtControllers = {};
  final Map<String, FocusNode> _amtFocusNodes = {};

  String? _categoryId;
  Money _amount = Money.zero();
  DateTime _date = DateTime.now();
  Set<String> _participants = {};
  List<ParticipantGroup> _groups = [];
  SplitType _splitType = SplitType.equal;
  Map<String, double> _percentages = {};
  Map<String, Money> _customAmounts = {};
  Map<String, int> _shareUnits = {};
  bool _attemptedSave = false;
  bool _saving = false;
  String? _descriptionError;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense != null) {
      final state = context.read<AppState>();
      _descriptionController.text = expense.description ?? '';
      _noteController.text = expense.note ?? '';
      _categoryId = expense.categoryId;
      _amount = expense.amount;
      _date = expense.date;
      final shares = state.sharesForExpense(expense.id);

      // Handle both old (Phase-6) and new (persistent MemberGroup) share models.
      // New model: share.isGroup with memberGroupId + groupSnapshot.
      // Old model: share.expenseGroupId with expense.participantGroups.
      _participants = shares
          .where((s) => !s.isGroup && s.userId != null)
          .map((s) => s.userId!)
          .toSet();
      _groups = expense.participantGroups.toList();
      _splitType = _detectSplitType(shares, _groups);
      _percentages = {};
      _customAmounts = {};
      _shareUnits = {};
      for (final s in shares) {
        final key = s.expenseGroupId ?? s.userId ?? s.memberGroupId ?? '';
        if (key.isEmpty) continue;
        if (s.percentage != null) _percentages[key] = s.percentage!;
        if (s.shares != null) _shareUnits[key] = s.shares!;
      }
      // For custom splits, a group's party-level amount is the sum of its
      // members' shares (old model) or the single share amount (new model).
      for (final g in _groups) {
        final total = shares
            .where((s) => s.expenseGroupId == g.id)
            .fold<int>(0, (sum, s) => sum + s.amount.paisa);
        if (total > 0) _customAmounts[g.id] = Money(total);
      }
      for (final s in shares) {
        if (s.expenseGroupId == null && s.userId != null) {
          _customAmounts[s.userId!] = s.amount;
        }
      }
    }
  }

  SplitType _detectSplitType(
    List<ExpenseShare> shares,
    List<ParticipantGroup> groups,
  ) {
    if (shares.isNotEmpty && shares.every((s) => s.percentage != null)) {
      return SplitType.percentage;
    }
    if (shares.isNotEmpty && shares.every((s) => s.shares != null)) {
      return SplitType.shares;
    }
    // Grouped custom splits record the party-level amount on the group.
    if (groups.any((g) => g.customAmountPaisa != null)) {
      return SplitType.custom;
    }
    // Party-level amount for each individual is its own share.
    final partyAmounts = <int>{};
    for (final g in groups) {
      partyAmounts.add(g.customAmountPaisa ?? 0);
    }
    for (final s in shares) {
      if (s.expenseGroupId == null) partyAmounts.add(s.amount.paisa);
    }
    partyAmounts.removeWhere((p) => p == 0);
    if (partyAmounts.length > 1) return SplitType.custom;
    return SplitType.equal;
  }

  /// The split parties currently in effect: users not in a group are
  /// individual parties; each group is one party containing its members.
  List<SplitParty> get _parties {
    // Handle both old (ParticipantGroup) and new (persistent MemberGroup) models
    final groupedUserIds = <String>{};
    final groupParties = <SplitParty>[];

    // Old model: ad-hoc ParticipantGroup from expense form
    for (final g in _groups) {
      groupedUserIds.addAll(g.userIds);
      groupParties.add(SplitParty.group(groupId: g.id, name: g.name, userIds: g.userIds));
    }

    // New model: persistent MemberGroups selected from Settings
    for (final g in _selectedGroups) {
      groupedUserIds.addAll(g.allUserIds);
      groupParties.add(SplitParty.group(groupId: g.id, name: g.name, userIds: g.memberIds));
    }

    // Users represented by any active Member Group are only split via their
    // group, never as individual parties (Rule 8 / Rule 10).
    final allGrouped = groupedUserIds;
    for (final g in context.read<AppState>().activeMemberGroups) {
      allGrouped.addAll(g.allUserIds);
    }

    return [
      for (final id in _participants)
        if (!allGrouped.contains(id)) SplitParty.individual(id),
      ...groupParties,
    ];
  }

  String _partyLabel(SplitParty party, AppState state) {
    if (party.isGroup) return party.name ?? '?';
    return state.memberName(party.id) ?? '?';
  }

  /// The user id of the owner of the group behind [share], when the share is a
  /// Member Group participant. Used to show the group owner's avatar.
  String? _ownerIdOf(ExpenseShare share, AppState state) {
    final gid = share.memberGroupId;
    if (gid == null) return null;
    for (final g in state.activeMemberGroups) {
      if (g.id == gid) return g.ownerUserId;
    }
    return share.groupSnapshot?.ownerUserId;
  }

  /// The display name of the group behind [share].
  String _groupNameOf(ExpenseShare share, AppState state) {
    final gid = share.memberGroupId;
    for (final g in _selectedGroups) {
      if (g.id == gid) return g.name;
    }
    for (final g in state.activeMemberGroups) {
      if (g.id == gid) return g.name;
    }
    return gid ?? '?';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _noteController.dispose();
    for (final c in _pctControllers.values) {
      c.dispose();
    }
    for (final f in _pctFocusNodes.values) {
      f.dispose();
    }
    for (final c in _amtControllers.values) {
      c.dispose();
    }
    for (final f in _amtFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Returns a stable controller for a split input. The controller is created
  /// once and reused across rebuilds so typing never drops focus. External
  /// value changes are pushed into the field text only while it isn't focused.
  TextEditingController _reuseController(
    Map<String, TextEditingController> controllers,
    Map<String, FocusNode> focusNodes,
    String id,
    String text,
  ) {
    final controller = controllers[id];
    if (controller != null) {
      final node = focusNodes[id];
      if (node != null && !node.hasFocus && controller.text != text) {
        controller.text = text;
      }
      return controller;
    }
    final created = TextEditingController(text: text);
    controllers[id] = created;
    focusNodes[id] = FocusNode();
    return created;
  }

  /// Disposes controllers/nodes for parties that are no longer in the split,
  /// so a re-added party starts from its current (often zeroed) value.
  void _pruneControllers(
    Map<String, TextEditingController> controllers,
    Map<String, FocusNode> focusNodes,
    Set<String> liveIds,
  ) {
    controllers.removeWhere((id, controller) {
      if (liveIds.contains(id)) return false;
      controller.dispose();
      focusNodes.remove(id)?.dispose();
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPersonal = state.isPersonalMode;
    if (!isPersonal && _participants.isEmpty && state.members.isNotEmpty) {
      // Default to every member NOT represented by an active group (Rule 8),
      // and every active Member Group, so all participants are preselected.
      final grouped = state.groupedUserIds;
      _participants = state.members
          .where((m) => !grouped.contains(m.userId))
          .map((m) => m.userId)
          .toSet();
      final activeGroups = state.activeMemberGroups;
      if (_selectedGroups.isEmpty && activeGroups.isNotEmpty) {
        _selectedGroups.addAll(activeGroups);
      }
      if (_splitType == SplitType.equal) {
        _percentages = {};
        _customAmounts = {};
        _shareUnits = {};
      }
    }

    final categories = state.categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editExpense : l10n.addExpense)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryPicker(categories),
            const SizedBox(height: 20),
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
                labelText: l10n.description,
                hintText: l10n.descriptionHint,
                prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                errorText: _descriptionError,
              ),
              onChanged: (_) {
                if (_descriptionError != null) {
                  setState(() => _descriptionError = null);
                }
              },
            ),
            const SizedBox(height: 24),
            _Label(l10n.date),
            const SizedBox(height: 10),
            _buildDatePicker(isDark),
            if (!isPersonal) ...[
              const SizedBox(height: 24),
              _Label(l10n.paidBy),
              const SizedBox(height: 10),
              _buildPayerDisplay(state),
              const SizedBox(height: 24),
              _Label(l10n.splitBetween),
              const SizedBox(height: 10),
              _buildParticipantSelector(state),
              const SizedBox(height: 20),
              _buildSplitTypeSelector(),
              const SizedBox(height: 20),
              _buildSplitInput(state),
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
            if (!isPersonal) ...[
              const SizedBox(height: 28),
              _buildPreview(state),
            ],
            const SizedBox(height: 20),
            if (_attemptedSave && !_canSave(state, l10n)) ...[
              Container(
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
                        _validationMessage(state, l10n)!,
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
              label: _isEdit ? l10n.saveChanges : l10n.addExpense,
              icon: _isEdit ? Icons.save_rounded : Icons.add_rounded,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPayerDisplay(AppState state) {
    final l10n = context.l10n;
    final uid = state.currentUserId;
    final name = uid == null
        ? l10n.you
        : (state.memberName(uid) ?? state.currentUser?.name ?? l10n.you);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceAltDark
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          MemberAvatar(name: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          if (uid != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.you,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
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
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              formatFullDate(_date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  /// Builds the unified participant selector showing both individual members
  /// and persistent Member Groups.
  Widget _buildParticipantSelector(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get active Member Groups for this space
    final currentSpaceId = state.space?.id;
    final memberGroups = state.repo.memberGroups
        .where((g) => g.spaceId == currentSpaceId && g.isActive)
        .toList();

    // Users represented by ANY active group are only selectable via their
    // group, never as individual participants (Rule 8 / Rule 10).
    final allGroupedUserIds = <String>{};
    for (final g in memberGroups) {
      allGroupedUserIds.addAll(g.allUserIds);
    }

    // Collect all user IDs represented by the selected groups (owner + members)
    // so no one is double-counted both inside a group and individually.
    final groupedUserIds = <String>{};
    for (final g in _selectedGroups) {
      groupedUserIds.addAll(g.allUserIds);
    }

    // A member is selectable only when they are not part of any selected group
    // AND not represented by any existing active group.
    bool isMemberSelectable(String userId) =>
        !groupedUserIds.contains(userId) &&
        !allGroupedUserIds.contains(userId);

    // Check if a group is selectable (none of its represented users are selected individually)
    bool isGroupSelectable(MemberGroup group) {
      return !group.allUserIds.any((id) => _participants.contains(id));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unified participant chips: individual members (not in any group) and
        // persistent Member Groups are shown together and both are selectable.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in state.members)
              if (!allGroupedUserIds.contains(m.userId))
                FilterChip(
                  avatar: MemberAvatar(name: m.name, size: 22),
                  label: Text(m.name),
                  selected: _participants.contains(m.userId),
                  onSelected: isMemberSelectable(m.userId) && !_saving
                      ? (selected) => setState(() {
                            if (selected) {
                              _participants.add(m.userId);
                            } else {
                              _participants.remove(m.userId);
                              _percentages.remove(m.userId);
                              _customAmounts.remove(m.userId);
                              _shareUnits.remove(m.userId);
                            }
                          })
                      : null,
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                ),
            for (final g in memberGroups)
              FilterChip(
                avatar: MemberAvatar(
                  name: state.memberName(g.ownerUserId) ?? '?',
                  size: 22,
                ),
                label: Text(g.name),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                selected: _selectedGroups.any((sg) => sg.id == g.id),
                onSelected: isGroupSelectable(g) && !_saving
                    ? (selected) => setState(() {
                          if (selected) {
                            _selectedGroups.add(g);
                            // Auto-remove any individual users (owner + members)
                            // that are represented by this group
                            for (final id in g.allUserIds) {
                              _participants.remove(id);
                              _percentages.remove(id);
                              _customAmounts.remove(id);
                              _shareUnits.remove(id);
                            }
                          } else {
                            _selectedGroups.removeWhere((sg) => sg.id == g.id);
                          }
                        })
                    : null,
                showCheckmark: false,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                tooltip: g.memberIds.isNotEmpty
                    ? '${context.l10n.groupMembers}: ${g.memberIds.map((id) => state.memberName(id) ?? id).join(', ')}'
                    : null,
              ),
          ],
        ),
        if (memberGroups.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.groupCountsAsOneParticipant,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // Selected persistent Member Groups (replaces _groups)
  final List<MemberGroup> _selectedGroups = [];

  // No more _buildGroupSection, _openGroupPicker, _removeUserFromGroups
  // Groups are now selected from persistent MemberGroups only

  Widget _buildSplitTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final values = SplitType.values;
          final width = constraints.maxWidth / values.length;
          final selected = values.indexOf(_splitType);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: selected * width,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final type in values)
                    Expanded(
                      child: GestureDetector(
                        onTap: _saving
                            ? null
                            : () => setState(() => _splitType = type),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _splitLabel(type),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _splitType == type
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
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

  String _splitLabel(SplitType type) {
    final l10n = context.l10n;
    switch (type) {
      case SplitType.equal:
        return l10n.splitLabelEqual;
      case SplitType.percentage:
        return l10n.splitLabelPercent;
      case SplitType.custom:
        return l10n.splitLabelAmounts;
      case SplitType.shares:
        return l10n.splitLabelShares;
    }
  }

  Widget _buildSplitInput(AppState state) {
    final parties = _parties;
    if (parties.isEmpty) {
      return Text(
        context.l10n.selectParticipant,
        style: const TextStyle(color: AppColors.negative),
      );
    }

    switch (_splitType) {
      case SplitType.equal:
        final shares = SplitCalculator.buildGrouped(
          expenseId: 'preview',
          amount: _amount,
          parties: parties,
        );
        return Column(
          children: [
            for (var i = 0; i < parties.length; i++)
              _PartyPreviewRow(
                party: parties[i],
                label: _partyLabel(parties[i], state),
                share: shares[i].amount,
                state: state,
              ),
          ],
        );
      case SplitType.percentage:
        return _percentageInput(state: state, parties: parties);
      case SplitType.custom:
        return _customAmountInput(state: state, parties: parties);
      case SplitType.shares:
        return _sharesInput(state: state, parties: parties);
    }
  }

  Widget _buildPreview(AppState state) {
    final parties = _parties;
    if (parties.isEmpty || _amount.isZero) return const SizedBox.shrink();
    final shares = SplitCalculator.buildGrouped(
      expenseId: 'preview',
      amount: _amount,
      parties: parties,
      type: _splitType,
      percentages: _percentages,
      customAmounts: _customAmounts,
      shareUnits: _shareUnits,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.splitPreview,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final share in shares)
            if (share.userId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    MemberAvatar(
                      name: state.memberName(share.userId!) ?? '?',
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.memberName(share.userId!) ?? '?',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(share.amount),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (share.isGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    MemberAvatar(
                      name: state.memberName(_ownerIdOf(share, state) ?? '') ?? '?',
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _groupNameOf(share, state),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(share.amount),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 20),
          Row(
            children: [
              Text(
                context.l10n.total,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(_amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave(AppState state, AppLocalizations l10n) =>
      _validationMessage(state, l10n) == null;

  String? _validationMessage(AppState state, AppLocalizations l10n) {
    if (_amount.isZero) return l10n.expenseAmountError;
    if (_descriptionController.text.trim().isEmpty) {
      return l10n.expenseDescriptionError;
    }
    if (state.isPersonalMode) return null;
    if (_participants.isEmpty) return l10n.expenseParticipantError;
    switch (_splitType) {
      case SplitType.percentage:
        final sum = _percentages.values.fold<double>(0, (a, b) => a + b);
        if ((sum - 100).abs() > 0.01) {
          return l10n.expensePercentError;
        }
        break;
      case SplitType.custom:
        final sum = _customAmounts.values.fold<int>(0, (a, m) => a + m.paisa);
        if (sum != _amount.paisa) {
          return l10n.expenseCustomError;
        }
        break;
      case SplitType.shares:
        if (_shareUnits.values.fold<int>(0, (a, b) => a + b) <= 0) {
          return l10n.expenseSharesError;
        }
        break;
      case SplitType.equal:
        break;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() {
      _attemptedSave = true;
      _descriptionError = _descriptionController.text.trim().isEmpty
          ? l10n.expenseDescriptionError
          : null;
    });
    final state = context.read<AppState>();
    if (!_canSave(state, l10n)) return;
    setState(() => _saving = true);
    final expense = widget.expense;
    try {
      if (state.isPersonalMode) {
        if (expense == null) {
          await state.addPersonalExpense(
            description: _descriptionController.text,
            amount: _amount,
            date: _date,
            categoryId: _categoryId,
            note: _noteController.text,
          );
        } else {
          await state.updatePersonalExpense(
            expense,
            description: _descriptionController.text,
            amount: _amount,
            date: _date,
            categoryId: _categoryId,
            note: _noteController.text,
          );
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final participants = _participants.toList();
      // Keep old ParticipantGroup for backward compat (ad-hoc groups created in expense form)
      final groups = _groups.map((g) {
        final percentage = _splitType == SplitType.percentage
            ? _percentages[g.id]
            : null;
        final shares = _splitType == SplitType.shares ? _shareUnits[g.id] : null;
        final custom = _splitType == SplitType.custom
            ? _customAmounts[g.id]?.paisa
            : null;
        return ParticipantGroup(
          id: g.id,
          expenseId: g.expenseId,
          name: g.name,
          userIds: g.userIds,
          percentage: percentage,
          shares: shares,
          customAmountPaisa: custom,
        );
      }).toList();
      // New persistent MemberGroups from Settings
      final memberGroups = _selectedGroups.toList();
      if (expense == null) {
        await state.addExpense(
          description: _descriptionController.text,
          amount: _amount,
          date: _date,
          categoryId: _categoryId,
          note: _noteController.text,
          participantIds: participants,
          groups: groups,
          memberGroups: memberGroups,
          splitType: _splitType,
          percentages: _percentages,
          customAmounts: _customAmounts,
          shareUnits: _shareUnits,
        );
      } else {
        await state.updateExpense(
          expense,
          description: _descriptionController.text,
          amount: _amount,
          date: _date,
          categoryId: _categoryId,
          note: _noteController.text,
          participantIds: participants,
          groups: groups,
          memberGroups: _selectedGroups.toList(),
          splitType: _splitType,
          percentages: _percentages,
          customAmounts: _customAmounts,
          shareUnits: _shareUnits,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- split type inputs ----

  Widget _percentageInput({
    required AppState state,
    required List<SplitParty> parties,
  }) {
    final sum = _percentages.values.fold<double>(0, (a, b) => a + b);
    final livePctIds = parties.map((p) => p.id).toSet();
    _pruneControllers(_pctControllers, _pctFocusNodes, livePctIds);
    for (final p in parties) {
      _reuseController(
        _pctControllers,
        _pctFocusNodes,
        p.id,
        (_percentages[p.id] ?? 0).toStringAsFixed(0),
      );
    }
    return Column(
      children: [
        for (final p in parties)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _PartyAvatar(party: p, state: state, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _partyLabel(p, state),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: TextField(
                    key: ValueKey('pct_${p.id}'),
                    focusNode: _pctFocusNodes[p.id]!,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    controller: _pctControllers[p.id]!,
                    textAlign: TextAlign.right,
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      setState(() => _percentages[p.id] = val);
                    },
                    decoration: const InputDecoration(
                      suffixText: '%',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              context.l10n.total,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${NumberFormat.decimalPattern('en_IN').format(sum)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: (sum - 100).abs() <= 0.01
                    ? AppColors.positive
                    : AppColors.negative,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customAmountInput({
    required AppState state,
    required List<SplitParty> parties,
  }) {
    var assigned = 0;
    for (final p in parties) {
      assigned += (_customAmounts[p.id] ?? Money.zero()).paisa;
    }
    final ok = assigned == _amount.paisa;
    final liveAmtIds = parties.map((p) => p.id).toSet();
    _pruneControllers(_amtControllers, _amtFocusNodes, liveAmtIds);
    for (final p in parties) {
      _reuseController(
        _amtControllers,
        _amtFocusNodes,
        p.id,
        _customAmountText(_customAmounts[p.id]),
      );
    }
    return Column(
      children: [
        for (final p in parties)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _PartyAvatar(party: p, state: state, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _partyLabel(p, state),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: ValueKey('amt_${p.id}'),
                    focusNode: _amtFocusNodes[p.id]!,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    controller: _amtControllers[p.id]!,
                    textAlign: TextAlign.right,
                    onChanged: (v) {
                      final val = double.tryParse(v.replaceAll(',', '')) ?? 0;
                      setState(
                        () => _customAmounts[p.id] = Money(
                          (val * 100).round(),
                        ),
                      );
                    },
                    decoration: const InputDecoration(
                      prefixText: 'Rs. ',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              context.l10n.assigned,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${formatMoneyCompact(Money(assigned), showSymbol: false)} / ${formatMoneyCompact(_amount, showSymbol: false)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: ok ? AppColors.positive : AppColors.negative,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _customAmountText(Money? money) {
    if (money == null || money.isZero) return '';
    final major = money.paisa.abs() / 100;
    final isWhole = major == major.roundToDouble();
    return isWhole ? major.round().toString() : major.toStringAsFixed(2);
  }

  Widget _sharesInput({
    required AppState state,
    required List<SplitParty> parties,
  }) {
    final total = _shareUnits.values.fold<int>(0, (a, b) => a + b);
    return Column(
      children: [
        for (final p in parties)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _PartyAvatar(party: p, state: state, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _partyLabel(p, state),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _shareAmountFor(p.id, total),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            final current = _shareUnits[p.id] ?? 1;
                            _shareUnits[p.id] = current > 1 ? current - 1 : 1;
                          });
                        },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text(
                  '${_shareUnits[p.id] ?? 1}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _shareUnits[p.id] = (_shareUnits[p.id] ?? 1) + 1;
                          });
                        },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              context.l10n.totalShares,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '$total',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }

  String _shareAmountFor(String partyId, int totalUnits) {
    if (_amount.isZero || totalUnits == 0) return '';
    final units = _shareUnits[partyId] ?? 1;
    final share = (_amount.paisa * units) ~/ totalUnits;
    return formatMoney(Money(share), showSymbol: false);
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

class _PartyPreviewRow extends StatelessWidget {
  final SplitParty party;
  final String label;
  final Money share;
  final AppState state;

  const _PartyPreviewRow({
    required this.party,
    required this.label,
    required this.share,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _PartyAvatar(party: party, state: state, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatMoney(share),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PartyAvatar extends StatelessWidget {
  final SplitParty party;
  final AppState state;
  final double size;

  const _PartyAvatar({
    required this.party,
    required this.state,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!party.isGroup) {
      return MemberAvatar(
        name: state.memberName(party.id) ?? '?',
        size: size,
      );
    }
    // Group participant: show the group owner's avatar.
    final ownerName =
        state.memberName(_ownerIdForGroup(party) ?? '') ?? '?';
    return MemberAvatar(name: ownerName, size: size);
  }

  String? _ownerIdForGroup(SplitParty party) {
    for (final g in state.activeMemberGroups) {
      if (g.id == party.id) return g.ownerUserId;
    }
    // Fall back to the first member if the group can't be resolved.
    return party.userIds.isNotEmpty ? party.userIds.first : null;
  }
}
