import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/money.dart';
import 'package:flutter_application_1/data/seed.dart';
import 'package:flutter_application_1/logic/balances.dart';
import 'package:flutter_application_1/logic/settlements.dart';
import 'package:flutter_application_1/logic/splits.dart';
import 'package:flutter_application_1/models/models.dart';

void main() {
  group('SplitCalculator', () {
    test('equal split distributes the full amount and handles rounding', () {
      final shares = SplitCalculator.build(
        expenseId: 'e',
        amount: const Money(280000),
        participantIds: ['a', 'b', 'c'],
      );
      expect(SplitCalculator.totalShares(shares), const Money(280000));
      expect(shares.map((s) => s.amount.paisa).toSet().length, 2,
          reason: 'one participant absorbs the leftover paisa');
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
  });

  group('BalanceCalculator', () {
    test('balance is paid minus share', () {
      final balances = BalanceCalculator.compute(
        household: _household,
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
        household: _household,
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
        settlements: [
          _settlement('s1', 'u_sita', 'u_ram', 500000, 'c'),
        ],
      );
      final ram = balances.firstWhere((b) => b.userId == 'u_ram');
      final sita = balances.firstWhere((b) => b.userId == 'u_sita');
      expect(ram.remaining, Money.zero());
      expect(sita.remaining, Money.zero());
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

  group('Seed data', () {
    test('seeded repository balances match the spec example', () {
      final repo = buildSeedRepository();
      final household = repo.households.first;
      final cycle = repo.cycles.firstWhere((c) => c.status == CycleStatus.active);
      final balances = BalanceCalculator.compute(
        household: household,
        members: repo.members,
        cycle: cycle,
        expenses: repo.expenses,
        shares: repo.shares,
        settlements: repo.settlements,
      );
      final total = balances.fold<int>(0, (sum, b) => sum + b.balance.paisa);
      expect(total, 0, reason: 'balances always sum to zero');

      final proposals = SettlementCalculator.minimize({
        for (final b in balances) b.userId: b.balance,
      });
      expect(proposals, isNotEmpty);
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
      joinedAt: DateTime(2026, 1, 1)),
  HouseholdMember(
      userId: 'u_sita',
      name: 'Sita',
      role: MemberRole.member,
      joinedAt: DateTime(2026, 1, 1)),
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
