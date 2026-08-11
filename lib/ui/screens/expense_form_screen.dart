import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
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

  String? _categoryId;
  Money _amount = Money.zero();
  String? _paidByUserId;
  DateTime _date = DateTime.now();
  Set<String> _participants = {};
  SplitType _splitType = SplitType.equal;
  Map<String, double> _percentages = {};
  Map<String, Money> _customAmounts = {};
  Map<String, int> _shareUnits = {};

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
      _paidByUserId = expense.paidByUserId;
      _date = expense.date;
      final shares = state.sharesForExpense(expense.id);
      _participants = shares.map((s) => s.userId).toSet();
      _splitType = _detectSplitType(shares);
      _percentages = {
        for (final s in shares)
          if (s.percentage != null) s.userId: s.percentage!
      };
      _customAmounts = {for (final s in shares) s.userId: s.amount};
      _shareUnits = {for (final s in shares) if (s.shares != null) s.userId: s.shares!};
    }
  }

  SplitType _detectSplitType(List<ExpenseShare> shares) {
    if (shares.isNotEmpty && shares.every((s) => s.percentage != null)) {
      return SplitType.percentage;
    }
    if (shares.isNotEmpty && shares.every((s) => s.shares != null)) {
      return SplitType.shares;
    }
    final amounts = shares.map((s) => s.amount.paisa).toSet();
    if (amounts.length > 1) return SplitType.custom;
    return SplitType.equal;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_participants.isEmpty && state.members.isNotEmpty) {
      _participants = state.members.map((m) => m.userId).toSet();
      _paidByUserId ??= state.currentUser?.id;
      if (_splitType == SplitType.equal) {
        _percentages = {};
        _customAmounts = {};
        _shareUnits = {};
      }
    }

    final members = state.members;
    final categories = state.categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit expense' : 'Add expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryPicker(categories),
            const SizedBox(height: 20),
            AmountField(
              value: _amount,
              label: 'Amount',
              autofocus: !_isEdit,
              onChanged: (m) => setState(() => _amount = m),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What was this for?',
                suffixIcon: Icon(Icons.edit_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 24),
            _Label('Paid by'),
            const SizedBox(height: 10),
            _buildPayerSelector(members),
            const SizedBox(height: 24),
            _Label('Date'),
            const SizedBox(height: 10),
            _buildDatePicker(isDark),
            const SizedBox(height: 24),
            _Label('Split between'),
            const SizedBox(height: 10),
            _buildParticipantSelector(members),
            const SizedBox(height: 20),
            _buildSplitTypeSelector(),
            const SizedBox(height: 20),
            _buildSplitInput(state),
            const SizedBox(height: 24),
            _Label('Note'),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
                suffixIcon: Icon(Icons.sticky_note_2_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 28),
            _buildPreview(state),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add expense',
              icon: _isEdit ? Icons.save_rounded : Icons.add_rounded,
              onPressed: _canSave(state) ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Category'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in categories)
              GestureDetector(
                onTap: () => setState(() => _categoryId = c.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _categoryId == c.id
                        ? _colorOf(c).withValues(alpha: 0.16)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceAltDark
                            : AppColors.surfaceAlt),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _categoryId == c.id
                          ? _colorOf(c)
                          : Colors.transparent,
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
                          color: _categoryId == c.id
                              ? _colorOf(c)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _colorOf(Category c) =>
      c.colorValue == null ? AppColors.primary : Color(c.colorValue!);

  Widget _buildPayerSelector(List<HouseholdMember> members) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = members[index];
          final selected = _paidByUserId == m.userId;
          return GestureDetector(
            onTap: () => setState(() => _paidByUserId = m.userId),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2.4,
                    ),
                  ),
                  child: MemberAvatar(name: m.name, size: 52),
                ),
                const SizedBox(height: 6),
                Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return GestureDetector(
      onTap: () async {
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
            const Icon(Icons.calendar_today_outlined,
                size: 20, color: AppColors.primary),
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

  Widget _buildParticipantSelector(List<HouseholdMember> members) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in members)
          FilterChip(
            avatar: MemberAvatar(name: m.name, size: 22),
            label: Text(m.name),
            selected: _participants.contains(m.userId),
            onSelected: (selected) => setState(() {
              if (selected) {
                _participants.add(m.userId);
              } else {
                _participants.remove(m.userId);
                _percentages.remove(m.userId);
                _customAmounts.remove(m.userId);
                _shareUnits.remove(m.userId);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildSplitTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceAltDark
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final type in SplitType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _splitType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _splitType == type
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceDark
                            : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _splitLabel(type),
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
    );
  }

  String _splitLabel(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.percentage:
        return 'Percent';
      case SplitType.custom:
        return 'Amounts';
      case SplitType.shares:
        return 'Shares';
    }
  }

  Widget _buildSplitInput(AppState state) {
    final participants =
        state.members.where((m) => _participants.contains(m.userId)).toList();
    if (participants.isEmpty) {
      return const Text('Select at least one participant.',
          style: TextStyle(color: AppColors.negative));
    }

    switch (_splitType) {
      case SplitType.equal:
        final shares = SplitCalculator.build(
          expenseId: 'preview',
          amount: _amount,
          participantIds: participants.map((m) => m.userId).toList(),
        );
        return Column(
          children: [
            for (var i = 0; i < participants.length; i++)
              _SharePreviewRow(
                member: participants[i],
                share: shares[i].amount,
              ),
          ],
        );
      case SplitType.percentage:
        return _percentageInput(participants: participants);
      case SplitType.custom:
        return _customAmountInput(participants: participants);
      case SplitType.shares:
        return _sharesInput(participants: participants);
    }
  }

  Widget _buildPreview(AppState state) {
    final participants =
        state.members.where((m) => _participants.contains(m.userId)).toList();
    if (participants.isEmpty || _amount.isZero) return const SizedBox.shrink();
    final shares = SplitCalculator.build(
      expenseId: 'preview',
      amount: _amount,
      participantIds: participants.map((m) => m.userId).toList(),
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
          const Text(
            'Split preview',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final share in shares)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  MemberAvatar(
                      name: state.memberName(share.userId) ?? '?', size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.memberName(share.userId) ?? '?',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatMoney(share.amount),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                formatMoney(_amount),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave(AppState state) {
    if (_amount.isZero) return false;
    if (_participants.isEmpty) return false;
    if (_paidByUserId == null) return false;
    if (_splitType == SplitType.percentage) {
      final sum = _percentages.values.fold<double>(0, (a, b) => a + b);
      if ((sum - 100).abs() > 0.01) return false;
    }
    if (_splitType == SplitType.custom) {
      final sum = _customAmounts.values
          .fold<int>(0, (a, m) => a + m.paisa);
      if (sum != _amount.paisa) return false;
    }
    if (_splitType == SplitType.shares) {
      if (_shareUnits.values.fold<int>(0, (a, b) => a + b) <= 0) return false;
    }
    return true;
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final expense = widget.expense;
    final participants = _participants.toList();
    if (expense == null) {
      await state.addExpense(
        description: _descriptionController.text,
        amount: _amount,
        paidByUserId: _paidByUserId!,
        date: _date,
        categoryId: _categoryId,
        note: _noteController.text,
        participantIds: participants,
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
        paidByUserId: _paidByUserId!,
        date: _date,
        categoryId: _categoryId,
        note: _noteController.text,
        participantIds: participants,
        splitType: _splitType,
        percentages: _percentages,
        customAmounts: _customAmounts,
        shareUnits: _shareUnits,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ---- split type inputs ----

  Widget _percentageInput({required List<HouseholdMember> participants}) {
    final sum = _percentages.values.fold<double>(0, (a, b) => a + b);
    return Column(
      children: [
        for (final m in participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                MemberAvatar(name: m.name, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 78,
                  child: TextField(
                    key: ValueKey('pct_${m.userId}'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    controller: TextEditingController(
                        text: (_percentages[m.userId] ?? 0)
                            .toStringAsFixed(0)),
                    textAlign: TextAlign.right,
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      setState(() => _percentages[m.userId] = val);
                    },
                    decoration: const InputDecoration(
                      suffixText: '%',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            const Text('Total',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _customAmountInput({required List<HouseholdMember> participants}) {
    var assigned = 0;
    for (final m in participants) {
      assigned += (_customAmounts[m.userId] ?? Money.zero()).paisa;
    }
    final ok = assigned == _amount.paisa;
    return Column(
      children: [
        for (final m in participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                MemberAvatar(name: m.name, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: ValueKey('amt_${m.userId}'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    controller: TextEditingController(
                        text: _customAmountText(_customAmounts[m.userId])),
                    textAlign: TextAlign.right,
                    onChanged: (v) {
                      final val = double.tryParse(v.replaceAll(',', '')) ?? 0;
                      setState(() =>
                          _customAmounts[m.userId] = Money((val * 100).round()));
                    },
                    decoration: const InputDecoration(
                      prefixText: 'Rs. ',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            const Text('Assigned',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _sharesInput({required List<HouseholdMember> participants}) {
    final total = _shareUnits.values.fold<int>(0, (a, b) => a + b);
    return Column(
      children: [
        for (final m in participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                MemberAvatar(name: m.name, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  _shareAmountFor(m.userId, total),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      final current = _shareUnits[m.userId] ?? 1;
                      _shareUnits[m.userId] = current > 1 ? current - 1 : 1;
                    });
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text(
                  '${_shareUnits[m.userId] ?? 1}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _shareUnits[m.userId] = (_shareUnits[m.userId] ?? 1) + 1;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
          ),
        Row(
          children: [
            const Text('Total shares',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              '$total',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }

  String _shareAmountFor(String userId, int totalUnits) {
    if (_amount.isZero || totalUnits == 0) return '';
    final units = _shareUnits[userId] ?? 1;
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

class _SharePreviewRow extends StatelessWidget {
  final HouseholdMember member;
  final Money share;

  const _SharePreviewRow({required this.member, required this.share});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          MemberAvatar(name: member.name, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(member.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
