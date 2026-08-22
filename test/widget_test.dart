import 'package:flutter_test/flutter_test.dart';

import 'package:hissa/core/ids.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/logic/balances.dart';
import 'package:hissa/logic/expense_auth.dart';
import 'package:hissa/logic/settlements.dart';
import 'package:hissa/logic/splits.dart';
import 'package:hissa/models/models.dart';

void main() {
  group('SplitCalculator', () {
    test('equal split distributes the full amount and handles rounding', () {
      final shares = SplitCalculator.build(
        expenseId: 'e',
        amount: const Money(280000),
        participantIds: ['a', 'b', 'c'],
      );
      expect(SplitCalculator.totalShares(shares), const Money(280000));
      expect(
        shares.map((s) => s.amount.paisa).toSet().length,
        2,
        reason: 'one participant absorbs the leftover paisa',
      );
    });

    test('percentage split sums to the expense amount', () {
      final shares = SplitCalculator.build(
        expenseId: 'e',
        amount: const Money(200000),
        participantIds: ['a', 'b', 'c'],
        type: SplitType.percentage,
        percentages: {'a': 50, 'b': 30, 'c': 20},
      );
      expect(SplitCalculator.totalShares(shares), const Money(200000));
      expect(shares[0].amount, const Money(100000));
      expect(shares[1].amount, const Money(60000));
      expect(shares[2].amount, const Money(40000));
    });

    test('custom split respects exact amounts', () {
      final shares = SplitCalculator.build(
        expenseId: 'e',
        amount: const Money(100000),
        participantIds: ['a', 'b'],
        type: SplitType.custom,
        customAmounts: {'a': const Money(70000), 'b': const Money(30000)},
      );
      expect(SplitCalculator.totalShares(shares), const Money(100000));
    });

    test('shares split is proportional and complete', () {
      final shares = SplitCalculator.build(
        expenseId: 'e',
        amount: const Money(900000),
        participantIds: ['a', 'b'],
        type: SplitType.shares,
        shareUnits: {'a': 2, 'b': 1},
      );
      expect(SplitCalculator.totalShares(shares), const Money(900000));
      expect(shares[0].amount, const Money(600000));
      expect(shares[1].amount, const Money(300000));
    });

    test('grouped equal split treats group as ONE participant (no internal division)', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(90000),
        parties: [
          SplitParty.individual('a'),
          SplitParty.group(groupId: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
      );
      expect(SplitCalculator.totalShares(shares), const Money(90000));
      // A = 450, Group = 450 (single share, NOT divided between b and c)
      expect(shares.length, 2);
      final a = shares.firstWhere((s) => s.participantType == ExpenseParticipantType.user && s.userId == 'a');
      final group = shares.firstWhere((s) => s.isGroup && s.memberGroupId == 'g1');
      expect(a.amount, const Money(45000));
      expect(group.amount, const Money(45000));
      expect(group.participantType, ExpenseParticipantType.group);
      expect(group.memberGroupId, 'g1');
      expect(group.groupSnapshot, isNull); // snapshot attached by caller
    });

    test('grouped percentage split gives group its full percentage share', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(100000),
        parties: [
          SplitParty.individual('a'),
          SplitParty.group(groupId: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.percentage,
        percentages: {'a': 50, 'g1': 50},
      );
      expect(SplitCalculator.totalShares(shares), const Money(100000));
      final a = shares.firstWhere((s) => s.participantType == ExpenseParticipantType.user && s.userId == 'a');
      final group = shares.firstWhere((s) => s.isGroup && s.memberGroupId == 'g1');
      expect(a.amount, const Money(50000));
      expect(group.amount, const Money(50000));
      expect(group.percentage, 50);
    });

    test('grouped custom split assigns exact amount to group', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(100000),
        parties: [
          SplitParty.individual('a'),
          SplitParty.group(groupId: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.custom,
        customAmounts: {
          'a': const Money(70000),
          'g1': const Money(30000),
        },
      );
      expect(SplitCalculator.totalShares(shares), const Money(100000));
      final a = shares.firstWhere((s) => s.participantType == ExpenseParticipantType.user && s.userId == 'a');
      final group = shares.firstWhere((s) => s.isGroup && s.memberGroupId == 'g1');
      expect(a.amount, const Money(70000));
      expect(group.amount, const Money(30000));
    });

    test('grouped shares split is proportional at party level', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(900000),
        parties: [
          SplitParty.individual('a'),
          SplitParty.group(groupId: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.shares,
        shareUnits: {'a': 2, 'g1': 1},
      );
      expect(SplitCalculator.totalShares(shares), const Money(900000));
      final a = shares.firstWhere((s) => s.participantType == ExpenseParticipantType.user && s.userId == 'a');
      final group = shares.firstWhere((s) => s.isGroup && s.memberGroupId == 'g1');
      expect(a.amount, const Money(600000));
      expect(group.amount, const Money(300000));
      expect(group.shares, 1);
    });
  });

  group('BalanceCalculator', () {
    test('balance is paid minus share (user only)', () {
      final balances = BalanceCalculator.compute(
        space: _space,
        members: _members,
        memberGroups: const [],
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 1000000, ['u_ram', 'u_sita'], 'c'),
        ],
        shares: SplitCalculator.build(
          expenseId: 'e1',
          amount: const Money(1000000),
          participantIds: ['u_ram', 'u_sita'],
        ),
        settlements: const [],
        incomes: const [],
      );
      final ram = balances.firstWhere((b) => b.id == 'u_ram');
      final sita = balances.firstWhere((b) => b.id == 'u_sita');
      expect(ram.balance, const Money(500000));
      expect(sita.balance, const Money(-500000));
      expect(ram.type, ExpenseParticipantType.user);
      expect(sita.type, ExpenseParticipantType.user);
    });

    test('settlement reduces outstanding balances', () {
      final balances = BalanceCalculator.compute(
        space: _space,
        members: _members,
        memberGroups: const [],
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 1000000, ['u_ram', 'u_sita'], 'c'),
        ],
        shares: SplitCalculator.build(
          expenseId: 'e1',
          amount: const Money(1000000),
          participantIds: ['u_ram', 'u_sita'],
        ),
        settlements: [_settlement('s1', 'u_sita', 'u_ram', 500000, 'c')],
        incomes: const [],
      );
      final ram = balances.firstWhere((b) => b.id == 'u_ram');
      final sita = balances.firstWhere((b) => b.id == 'u_sita');
      expect(ram.remaining, Money.zero());
      expect(sita.remaining, Money.zero());
    });

    test('group participant aggregates its members into one balance entry', () {
      final group = MemberGroup(
        id: 'g1',
        spaceId: 'space',
        ownerUserId: 'u_ram',
        name: 'Ram\'s Group',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final balances = BalanceCalculator.compute(
        space: _space,
        members: _members,
        memberGroups: [group],
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 1000000, ['g1', 'u_sita'], 'c'),
        ],
        shares: [
          ExpenseShare(
            id: genId(),
            expenseId: 'e1',
            userId: null,
            amount: const Money(500000),
            participantType: ExpenseParticipantType.group,
            memberGroupId: 'g1',
          ),
          ExpenseShare(
            id: genId(),
            expenseId: 'e1',
            userId: 'u_sita',
            amount: const Money(500000),
            participantType: ExpenseParticipantType.user,
          ),
        ],
        settlements: const [],
        incomes: const [],
      );
      // Grouped members never appear individually.
      expect(
        balances.any(
          (b) => b.id == 'u_ram' && b.type == ExpenseParticipantType.user,
        ),
        isFalse,
      );
      // The owner's payment rolls into the group.
      final grp =
          balances.firstWhere((b) => b.id == 'g1' && b.type == ExpenseParticipantType.group);
      expect(grp.paid, const Money(1000000));
      expect(grp.share, const Money(500000));
      expect(grp.balance, const Money(500000));
      expect(grp.type, ExpenseParticipantType.group);
      // The ungrouped member splits the rest.
      final sita = balances.firstWhere((b) => b.id == 'u_sita');
      expect(sita.balance, const Money(-500000));
    });
  });

  group('SettlementCalculator', () {
    test('minimizes transactions between two parties', () {
      final proposals = SettlementCalculator.minimize({
        'u_ram': const Money(500000),
        'u_sita': const Money(-500000),
      });
      expect(proposals.length, 1);
      expect(proposals.first.fromUserId, 'u_sita');
      expect(proposals.first.toUserId, 'u_ram');
      expect(proposals.first.amount, const Money(500000));
    });

    test('handles group participants in settlement proposals', () {
      final proposals = SettlementCalculator.minimize({
        'u_ram': const Money(500000),
        'g1': const Money(-500000),
      });
      expect(proposals.length, 1);
      expect(proposals.first.fromUserId, 'g1');
      expect(proposals.first.toUserId, 'u_ram');
      expect(proposals.first.amount, const Money(500000));
    });

    test('three-way settlement chains correctly', () {
      final proposals = SettlementCalculator.minimize({
        'a': const Money(300000),
        'b': const Money(-100000),
        'c': const Money(-200000),
      });
      expect(proposals.length, 2);
      final total = proposals.fold(Money.zero(), (sum, p) => sum + p.amount);
      expect(total, const Money(300000));
    });
  });

  group('ExpenseAuth', () {
    test('creator can edit own expense', () {
      final expense = _expense('e1', 'u_ram', 100000, [], 'c');
      expect(canEditExpenseBy(currentUserId: 'u_ram', expense: expense), isTrue);
    });

    test('non-creator cannot edit expense', () {
      final expense = _expense('e1', 'u_ram', 100000, [], 'c');
      expect(canEditExpenseBy(currentUserId: 'u_sita', expense: expense), isFalse);
    });

    test('payer is always current user', () {
      expect(payerForCurrentUser('u_ram'), 'u_ram');
    });
  });
}

// ---- test helpers ----

Space _space = Space(
  id: 'space',
  name: 'Test Space',
  currency: 'NPR',
  inviteCode: 'TEST',
  createdAt: DateTime(2026, 1, 1),
  mode: SpaceMode.split,
);

List<SpaceMember> _members = [
  SpaceMember(userId: 'u_ram', name: 'Ram', role: MemberRole.owner, joinedAt: DateTime(2026, 1, 1)),
  SpaceMember(userId: 'u_sita', name: 'Sita', role: MemberRole.member, joinedAt: DateTime(2026, 1, 1)),
];

Cycle _cycle = Cycle(
  id: 'c',
  spaceId: 'space',
  name: 'Cycle 1',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 12, 31),
  status: CycleStatus.active,
);

Expense _expense(String id, String paidBy, int amount, List<String> participants, String cycleId) {
  return Expense(
    id: id,
    spaceId: 'space',
    cycleId: cycleId,
    paidByUserId: paidBy,
    createdBy: paidBy,
    amount: Money(amount),
    date: DateTime(2026, 6, 15),
    createdAt: DateTime(2026, 6, 15),
    updatedAt: DateTime(2026, 6, 15),
  );
}

Settlement _settlement(String id, String from, String to, int amount, String cycleId) {
  return Settlement(
    id: id,
    spaceId: 'space',
    cycleId: cycleId,
    fromUserId: from,
    toUserId: to,
    amount: Money(amount),
    currency: 'NPR',
    paymentMethod: 'Cash',
    date: DateTime(2026, 6, 20),
    status: SettlementStatus.paid,
    createdAt: DateTime(2026, 6, 20),
  );
}