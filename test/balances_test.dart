import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/logic/balances.dart';
import 'package:hissa/models/models.dart';

void main() {
  test('Member Group is a financial participant in balances', () {
    final space = Space(
      id: 'h1',
      name: 'Home',
      currency: 'NPR',
      inviteCode: 'ABCDE',
      createdAt: DateTime(2026, 1, 1),
      mode: SpaceMode.split,
    );
    final cycle = Cycle(
      id: 'c1',
      spaceId: 'h1',
      name: 'January 2026',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      status: CycleStatus.active,
    );
    final members = [
      SpaceMember(
        userId: 'u1',
        name: 'A',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
      ),
      SpaceMember(
        userId: 'u2',
        name: 'B',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
      ),
    ];
    final group = MemberGroup(
      id: 'g1',
      spaceId: 'h1',
      ownerUserId: 'u2',
      name: "B's Group",
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final expense = Expense(
      id: 'e1',
      spaceId: 'h1',
      cycleId: 'c1',
      paidByUserId: 'u1',
      amount: const Money(90000),
      date: DateTime(2026, 1, 10),
      createdAt: DateTime(2026, 1, 10),
      updatedAt: DateTime(2026, 1, 10),
    );
    final shares = [
      ExpenseShare(
        id: 's1',
        expenseId: 'e1',
        userId: 'u1',
        amount: const Money(45000),
        participantType: ExpenseParticipantType.user,
      ),
      ExpenseShare(
        id: 's2',
        expenseId: 'e1',
        userId: null,
        amount: const Money(45000),
        participantType: ExpenseParticipantType.group,
        memberGroupId: 'g1',
      ),
    ];

    final entries = BalanceCalculator.compute(
      space: space,
      members: members,
      memberGroups: [group],
      cycle: cycle,
      expenses: [expense],
      shares: shares,
      settlements: const [],
      incomes: const [],
    );

    // The group's share is never attributed to its members. Group members are
    // represented by the group itself, so B (the group owner) has no entry.
    expect(entries.any((e) => e.id == 'u2'), isFalse);

    // The group itself carries the share as its own balance.
    final groupEntry =
        entries.singleWhere((e) => e.type == ExpenseParticipantType.group);
    expect(groupEntry.share, const Money(45000));
    expect(groupEntry.balance, const Money(-45000));

    // The sheet reconciles: paid equals total shares.
    final totalPaid =
        entries.fold<int>(0, (sum, e) => sum + e.paid.paisa);
    final totalShare =
        entries.fold<int>(0, (sum, e) => sum + e.share.paisa);
    expect(totalPaid, totalShare);
  });
}
