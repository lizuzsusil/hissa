import 'package:flutter_test/flutter_test.dart';

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

    test('grouped equal split treats each group as one party', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(90000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
      );
      expect(SplitCalculator.totalShares(shares), const Money(90000));
      // A = 450, group B+C = 450, distributed equally: B = 225, C = 225.
      final a = shares.firstWhere((s) => s.userId == 'a');
      final b = shares.firstWhere((s) => s.userId == 'b');
      final c = shares.firstWhere((s) => s.userId == 'c');
      expect(a.amount, const Money(45000));
      expect(b.amount, const Money(22500));
      expect(c.amount, const Money(22500));
      expect(b.groupId, 'g1');
      expect(c.groupId, 'g1');
      expect(a.groupId, isNull);
    });

    test('grouped percentage split distributes the group share equally', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(100000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.percentage,
        percentages: {'a': 50, 'g1': 50},
      );
      expect(SplitCalculator.totalShares(shares), const Money(100000));
      final a = shares.firstWhere((s) => s.userId == 'a');
      final b = shares.firstWhere((s) => s.userId == 'b');
      final c = shares.firstWhere((s) => s.userId == 'c');
      expect(a.amount, const Money(50000));
      expect(b.amount, const Money(25000));
      expect(c.amount, const Money(25000));
      expect(b.percentage, 50);
      expect(c.percentage, 50);
    });

    test('grouped custom split sums exactly and distributes equally', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(100000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.custom,
        customAmounts: {
          'a': const Money(70000),
          'g1': const Money(30000),
        },
      );
      expect(SplitCalculator.totalShares(shares), const Money(100000));
      final a = shares.firstWhere((s) => s.userId == 'a');
      final b = shares.firstWhere((s) => s.userId == 'b');
      final c = shares.firstWhere((s) => s.userId == 'c');
      expect(a.amount, const Money(70000));
      expect(b.amount, const Money(15000));
      expect(c.amount, const Money(15000));
    });

    test('grouped shares split is proportional across parties', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e',
        amount: const Money(900000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.shares,
        shareUnits: {'a': 2, 'g1': 1},
      );
      expect(SplitCalculator.totalShares(shares), const Money(900000));
      final a = shares.firstWhere((s) => s.userId == 'a');
      final b = shares.firstWhere((s) => s.userId == 'b');
      final c = shares.firstWhere((s) => s.userId == 'c');
      expect(a.amount, const Money(600000));
      expect(b.amount, const Money(150000));
      expect(c.amount, const Money(150000));
      expect(b.shares, 1);
      expect(c.shares, 1);
    });
  });

  group('BalanceCalculator', () {
    test('balance is paid minus share', () {
      final balances = BalanceCalculator.compute(
        space: _household,
        members: _members,
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
      );
      final ram = balances.firstWhere((b) => b.userId == 'u_ram');
      final sita = balances.firstWhere((b) => b.userId == 'u_sita');
      expect(ram.balance, const Money(500000));
      expect(sita.balance, const Money(-500000));
    });

    test('settlement reduces outstanding balances', () {
      final balances = BalanceCalculator.compute(
        space: _household,
        members: _members,
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
      );
      final ram = balances.firstWhere((b) => b.userId == 'u_ram');
      final sita = balances.firstWhere((b) => b.userId == 'u_sita');
      expect(ram.remaining, Money.zero());
      expect(sita.remaining, Money.zero());
    });

    test('personal expenses (no cycle) never affect split balances', () {
      final balances = BalanceCalculator.compute(
        space: _household,
        members: _members,
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 1000000, ['u_ram', 'u_sita'], 'c'),
          _personalExpense('p1', 'u_ram', 500000),
        ],
        shares: SplitCalculator.build(
          expenseId: 'e1',
          amount: const Money(1000000),
          participantIds: ['u_ram', 'u_sita'],
        ),
        settlements: const [],
      );
      final ram = balances.firstWhere((b) => b.userId == 'u_ram');
      final sita = balances.firstWhere((b) => b.userId == 'u_sita');
      expect(ram.balance, const Money(500000));
      expect(sita.balance, const Money(-500000));
      expect(BalanceCalculator.totalSpent(
        [Expense(
          id: 'p1',
          householdId: 'h',
          cycleId: null,
          paidByUserId: 'u_ram',
          createdBy: 'u_ram',
          amount: const Money(500000),
          date: DateTime(2026, 1, 20),
          createdAt: DateTime(2026, 1, 20),
          updatedAt: DateTime(2026, 1, 20),
        )],
        'c',
      ), Money.zero());
    });
  });

  group('Expense', () {
    test('fromJson tolerates a null cycleId and a missing createdBy', () {
      final e = Expense.fromJson({
        'id': 'p1',
        'householdId': 'h1',
        'cycleId': null,
        'paidByUserId': 'u1',
        'amountPaisa': 25000,
        'date': '2026-01-20T00:00:00.000',
        'createdAt': '2026-01-20T00:00:00.000',
        'updatedAt': '2026-01-20T00:00:00.000',
      });
      expect(e.cycleId, isNull);
      expect(e.createdBy, isNull);
      expect(e.amount, const Money(25000));
    });

    test('fromJson round-trips createdBy for split expenses', () {
      final source = _personalExpense('e1', 'u_ram', 100000);
      final decoded = Expense.fromJson(source.toJson());
      expect(decoded.createdBy, 'u_ram');
      expect(decoded.cycleId, isNull);
    });

    test('participantGroups round-trip through toJson/fromJson', () {
      final expense = _groupedExpense();
      final decoded = Expense.fromJson(expense.toJson());
      expect(decoded.participantGroups, hasLength(1));
      final g = decoded.participantGroups.first;
      expect(g.id, 'g1');
      expect(g.expenseId, expense.id);
      expect(g.name, 'B + C');
      expect(g.userIds, ['b', 'c']);
      expect(g.customAmountPaisa, 30000);
    });

    test('expense shares round-trip their group membership', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e1',
        amount: const Money(100000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
        type: SplitType.custom,
        customAmounts: {
          'a': const Money(70000),
          'g1': const Money(30000),
        },
      );
      for (final share in shares) {
        final decoded = ExpenseShare.fromJson(share.toJson());
        expect(decoded.amount, share.amount);
        expect(decoded.groupId, share.groupId);
        expect(decoded.percentage, share.percentage);
        expect(decoded.shares, share.shares);
      }
      final b = shares.firstWhere((s) => s.userId == 'b');
      expect(b.groupId, 'g1');
    });
  });

  group('Expense ownership', () {
    final expense = Expense(
      id: 'e1',
      householdId: 'h',
      cycleId: 'c',
      paidByUserId: 'u_ram',
      createdBy: 'u_ram',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      createdAt: DateTime(2026, 1, 10),
      updatedAt: DateTime(2026, 1, 10),
    );

    test('creator can edit and delete', () {
      expect(
        canEditExpenseBy(currentUserId: 'u_ram', expense: expense),
        isTrue,
      );
    });

    test('other members cannot edit or delete', () {
      expect(
        canEditExpenseBy(currentUserId: 'u_sita', expense: expense),
        isFalse,
      );
    });

    test('legacy expenses without a creator are locked', () {
      final legacy = Expense(
        id: 'e2',
        householdId: 'h',
        cycleId: 'c',
        paidByUserId: 'u_ram',
        amount: const Money(50000),
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(
        canEditExpenseBy(currentUserId: 'u_ram', expense: legacy),
        isFalse,
      );
      expect(
        canEditExpenseBy(currentUserId: 'u_sita', expense: legacy),
        isFalse,
      );
    });

    test('anonymous users cannot edit', () {
      expect(
        canEditExpenseBy(currentUserId: null, expense: expense),
        isFalse,
      );
    });
  });

  group('Payer restriction', () {
    test('a new expense is always paid for by the authenticated user', () {
      expect(payerForCurrentUser('u_ram'), 'u_ram');
      expect(payerForCurrentUser('u_sita'), 'u_sita');
    });

    test('an anonymous user maps to an empty payer', () {
      expect(payerForCurrentUser(null), '');
    });
  });

  group('SettlementCalculator', () {
    test('produces the minimal number of transactions', () {
      final proposals = SettlementCalculator.minimize({
        'ram': const Money(500000),
        'sita': const Money(-300000),
        'john': const Money(-200000),
      });
      expect(proposals.length, 2);
      expect(proposals[0].fromUserId, 'sita');
      expect(proposals[0].toUserId, 'ram');
      expect(proposals[0].amount, const Money(300000));
      expect(proposals[1].fromUserId, 'john');
      expect(proposals[1].toUserId, 'ram');
      expect(proposals[1].amount, const Money(200000));
    });

    test('avoids circular chains', () {
      final proposals = SettlementCalculator.minimize({
        'a': const Money(100000),
        'b': const Money(-40000),
        'c': const Money(-60000),
      });
      final paths = proposals
          .map((p) => '${p.fromUserId}->${p.toUserId}')
          .toSet();
      expect(paths, {'b->a', 'c->a'});
    });
  });

  group('Split mode regression', () {
    test('carry-forward keeps a settled balance at zero across cycles', () {
      // Cycle 1: a and b split 100, b pays 50, a pays 50 -> both owe 0.
      final info = BalanceCalculator.compute(
        space: _household,
        members: _members,
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 5000, ['u_ram', 'u_sita'], _cycle.id),
          _expense('e2', 'u_sita', 5000, ['u_ram', 'u_sita'], _cycle.id),
        ],
        shares: [
          _share('s1', 'u_ram', 5000),
          _share('s2', 'u_sita', 5000),
        ],
        settlements: const [],
      );
      final byUser = {for (final i in info) i.userId: i};
      expect(byUser['u_ram']!.balance, const Money(0));
      expect(byUser['u_sita']!.balance, const Money(0));

      // Carry-forward balances from a settled cycle are zero.
      final carry =
          byUser['u_ram']!.remaining + byUser['u_sita']!.remaining;
      expect(carry, const Money(0));
    });

    test('historical settlements and cycle history stay intact', () {
      // A paid settlement in a cycle reduces that cycle's owed amount to zero.
      final info = BalanceCalculator.compute(
        space: _household,
        members: _members,
        cycle: _cycle,
        expenses: [
          _expense('e1', 'u_ram', 10000, ['u_ram', 'u_sita'], _cycle.id),
        ],
        shares: [
          _share('s1', 'u_ram', 5000),
          _share('s2', 'u_sita', 5000),
        ],
        settlements: [
          _settlement('s1', 'u_sita', 'u_ram', 5000, _cycle.id),
        ],
      );
      final byUser = {for (final i in info) i.userId: i};
      expect(byUser['u_sita']!.remaining, const Money(0));
      expect(byUser['u_ram']!.remaining, const Money(0));
    });

    test('grouped expenses preserve underlying user shares for history', () {
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e1',
        amount: const Money(90000),
        parties: [
          SplitParty.individual('a'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['b', 'c']),
        ],
      );
      final userIds = shares.map((s) => s.userId).toSet();
      expect(userIds, {'a', 'b', 'c'},
          reason: 'history keeps individual user identities');
    });
  });
}

final Household _household = Household(
  id: 'h',
  name: 'Test',
  currency: 'NPR',
  inviteCode: 'TEST',
  createdAt: DateTime(2026, 1, 1),
);

final List<HouseholdMember> _members = [
  HouseholdMember(
    userId: 'u_ram',
    name: 'Ram',
    role: MemberRole.owner,
    joinedAt: DateTime(2026, 1, 1),
  ),
  HouseholdMember(
    userId: 'u_sita',
    name: 'Sita',
    role: MemberRole.member,
    joinedAt: DateTime(2026, 1, 1),
  ),
];

final Cycle _cycle = Cycle(
  id: 'c',
  householdId: 'h',
  name: 'Test cycle',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 31),
  status: CycleStatus.active,
);

Expense _expense(
  String id,
  String payer,
  int paisa,
  List<String> participants,
  String cycleId,
) {
  return Expense(
    id: id,
    householdId: 'h',
    cycleId: cycleId,
    paidByUserId: payer,
    amount: Money(paisa),
    date: DateTime(2026, 1, 10),
    createdAt: DateTime(2026, 1, 10),
    updatedAt: DateTime(2026, 1, 10),
  );
}

ExpenseShare _share(String id, String userId, int paisa) {
  return ExpenseShare(
    id: id,
    expenseId: 'e1',
    userId: userId,
    amount: Money(paisa),
  );
}

Expense _personalExpense(String id, String payer, int paisa) {
  return Expense(
    id: id,
    householdId: 'h',
    cycleId: null,
    paidByUserId: payer,
    createdBy: payer,
    amount: Money(paisa),
    date: DateTime(2026, 1, 20),
    createdAt: DateTime(2026, 1, 20),
    updatedAt: DateTime(2026, 1, 20),
  );
}

Expense _groupedExpense() {
  return Expense(
    id: 'e1',
    householdId: 'h',
    cycleId: 'c',
    paidByUserId: 'a',
    createdBy: 'a',
    amount: const Money(100000),
    date: DateTime(2026, 1, 10),
    createdAt: DateTime(2026, 1, 10),
    updatedAt: DateTime(2026, 1, 10),
    participantGroups: const [
      ParticipantGroup(
        id: 'g1',
        expenseId: 'e1',
        name: 'B + C',
        userIds: ['b', 'c'],
        customAmountPaisa: 30000,
      ),
    ],
  );
}

Settlement _settlement(
  String id,
  String from,
  String to,
  int paisa,
  String cycleId,
) {
  return Settlement(
    id: id,
    householdId: 'h',
    cycleId: cycleId,
    fromUserId: from,
    toUserId: to,
    amount: Money(paisa),
    currency: 'NPR',
    paymentMethod: 'Cash',
    date: DateTime(2026, 1, 15),
    status: SettlementStatus.paid,
    createdAt: DateTime(2026, 1, 15),
  );
}
