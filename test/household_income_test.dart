import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Hissa income: a shared contribution that lowers the hissa's net
/// expense. The recipient merely holds the cash — the benefit distributes
/// across the members using the existing split rules, so balances, proposals
/// and settlements all flow through the existing pipeline unchanged.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Four-member split space (A owner, B, C, D) with an active cycle.
  Future<AppState> makeState() async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABCD12',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final members = {
      'u_a': ('A', MemberRole.owner),
      'u_b': ('B', MemberRole.member),
      'u_c': ('C', MemberRole.member),
      'u_d': ('D', MemberRole.member),
    };
    for (final entry in members.entries) {
      await repo.saveMember(
        SpaceMember(
          userId: entry.key,
          name: entry.value.$1,
          role: entry.value.$2,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );
    }
    await repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: 'January 2026',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: 'u_a', spaceId: 'h1');
    return state;
  }

  /// The exact scenario from the spec: A pays Rs 2000, B pays Rs 5000,
  /// C and D pay nothing, and B receives Rs 2000 as hissa income with an
  /// equal 25% split.
  Future<AppState> makeSpecScenario(AppState state) async {
    const everyone = ['u_a', 'u_b', 'u_c', 'u_d'];
    state.debugSetSession(userId: 'u_a', spaceId: 'h1');
    await state.addExpense(
      description: 'Groceries',
      amount: const Money(200000),
      date: DateTime(2026, 1, 5),
      participantIds: everyone,
    );
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.addExpense(
      description: 'Rent',
      amount: const Money(500000),
      date: DateTime(2026, 1, 6),
      participantIds: everyone,
    );
    final ok = await state.addHissaIncome(
      description: 'Room rent',
      amount: const Money(200000),
      date: DateTime(2026, 1, 7),
      receivedByUserId: 'u_b',
      participantIds: everyone,
    );
    expect(ok, isTrue);
    return state;
  }

  test(
    'income benefit splits per member; recipient does not keep it all',
    () async {
      final state = await makeState();
      await makeSpecScenario(state);

      final balances = {for (final b in state.computeBalances()) b.userId: b};

      // Everyone benefits Rs 500 from the income (25% of 2000), including the
      // recipient B.
      expect(balances['u_a']!.incomeShare.paisa, 50000);
      expect(balances['u_b']!.incomeShare.paisa, 50000);
      expect(balances['u_c']!.incomeShare.paisa, 50000);
      expect(balances['u_d']!.incomeShare.paisa, 50000);
      // Only B holds the cash.
      expect(balances['u_b']!.incomeReceived.paisa, 200000);

      // Net expense 7000 - 2000 = 5000 -> each member owes 1250 of it.
      // A: paid 2000 - 1250 = +750.
      expect(balances['u_a']!.remaining.paisa, 75000);
      // B: paid 5000, received back 2000 of hissa cash -> effectively
      // funded 3000; 3000 - 1250 = +1750 (NOT +3750).
      expect(balances['u_b']!.remaining.paisa, 175000);
      // C and D owe their full 1250 share.
      expect(balances['u_c']!.remaining.paisa, -125000);
      expect(balances['u_d']!.remaining.paisa, -125000);

      // Mathematically balanced: the balances cancel out exactly.
      final sum = balances.values.fold<int>(
        0,
        (acc, b) => acc + b.remaining.paisa,
      );
      expect(sum, 0);
    },
  );

  test('settlements reflect hissa income automatically', () async {
    final state = await makeState();
    await makeSpecScenario(state);

    final proposals = state.settlementProposals();
    expect(proposals, isNotEmpty);
    // C and D together owe 2500; the proposals must move exactly that much.
    final proposedTotal = proposals.fold<int>(
      0,
      (sum, p) => sum + p.amount.paisa,
    );
    expect(proposedTotal, 250000);
  });

  test('editing an income recalculates balances', () async {
    final state = await makeState();
    await makeSpecScenario(state);
    final income = state.hissaIncomesInCycle.single;

    final updated = await state.updateHissaIncome(
      income,
      description: 'Room rent',
      amount: const Money(400000),
      date: income.date,
      receivedByUserId: income.receivedByUserId,
      participantIds: income.participantIds,
    );
    expect(updated, isTrue);

    final balances = {for (final b in state.computeBalances()) b.userId: b};
    // Net expense now 7000 - 4000 = 3000 -> each owes 750.
    expect(balances['u_a']!.remaining.paisa, 125000); // 2000 - 750
    expect(balances['u_c']!.remaining.paisa, -75000);
  });

  test('deleting an income restores the pre-income balances', () async {
    final state = await makeState();
    await makeSpecScenario(state);
    final income = state.hissaIncomesInCycle.single;

    await state.deleteHissaIncome(income.id);
    expect(state.hissaIncomesInCycle, isEmpty);

    final balances = {for (final b in state.computeBalances()) b.userId: b};
    // Without income the gross 7000 splits at 1750 per member.
    expect(balances['u_a']!.remaining.paisa, 25000); // 2000 - 1750
    expect(balances['u_b']!.remaining.paisa, 325000); // 5000 - 1750
    expect(balances['u_c']!.remaining.paisa, -175000);
    expect(
      balances.values.fold<int>(0, (acc, b) => acc + b.remaining.paisa),
      0,
    );
  });

  test('multiple incomes received by different members accumulate', () async {
    final state = await makeState();
    state.debugSetSession(userId: 'u_a', spaceId: 'h1');
    await state.addExpense(
      description: 'Rent',
      amount: const Money(400000),
      date: DateTime(2026, 1, 2),
      participantIds: ['u_a', 'u_b'],
    );
    await state.addHissaIncome(
      description: 'Refund A',
      amount: const Money(100000),
      date: DateTime(2026, 1, 3),
      receivedByUserId: 'u_a',
      participantIds: ['u_a', 'u_b'],
    );
    await state.addHissaIncome(
      description: 'Cashback B',
      amount: const Money(60000),
      date: DateTime(2026, 1, 4),
      receivedByUserId: 'u_b',
      participantIds: ['u_a', 'u_b'],
    );

    expect(state.totalHissaIncome().paisa, 160000);
    final balances = {for (final b in state.computeBalances()) b.userId: b};
    // Net 4000 - 1600 = 2400 -> each member's fair share is 1200.
    // A: funded 4000, holds 1000 of hissa cash -> over-funded by 1800.
    expect(balances['u_a']!.remaining.paisa, 180000);
    // B: funded nothing, holds 600 of hissa cash -> owes 1200 + 600.
    expect(balances['u_b']!.remaining.paisa, -180000);
    expect(
      balances.values.fold<int>(0, (acc, b) => acc + b.remaining.paisa),
      0,
    );
  });

  test('percentage splits distribute the benefit by ratio', () async {
    final state = await makeState();
    state.debugSetSession(userId: 'u_a', spaceId: 'h1');
    await state.addExpense(
      description: 'Rent',
      amount: const Money(100000),
      date: DateTime(2026, 1, 2),
      participantIds: ['u_a', 'u_b'],
    );
    await state.addHissaIncome(
      description: 'Subsidy',
      amount: const Money(80000),
      date: DateTime(2026, 1, 3),
      receivedByUserId: 'u_b',
      participantIds: ['u_a', 'u_b'],
      splitType: SplitType.percentage,
      percentages: {'u_a': 75, 'u_b': 25},
    );

    final balances = {for (final b in state.computeBalances()) b.userId: b};
    expect(balances['u_a']!.incomeShare.paisa, 60000); // 75%
    expect(balances['u_b']!.incomeShare.paisa, 20000); // 25%
    // Expense share is equal (500 each); the income split is independent.
    // A: balance +500, benefit +600 -> owed 1100.
    expect(balances['u_a']!.remaining.paisa, 110000);
    // B: balance -500, benefit +200, holds the cash (-800) -> owes 1100.
    expect(balances['u_b']!.remaining.paisa, -110000);
    // Still balanced.
    expect(
      balances.values.fold<int>(0, (acc, b) => acc + b.remaining.paisa),
      0,
    );
  });

  test('outstanding dues gate includes hissa income', () async {
    final state = await makeState();
    await makeSpecScenario(state);

    // C owes money (their share of the net expense), so they cannot leave.
    final duesC = await state.outstandingDuesFor('h1', 'u_c');
    expect(duesC.paisa, -125000);
    final duesB = await state.outstandingDuesFor('h1', 'u_b');
    expect(duesB.paisa, 175000);
  });

  test('hissa income is rejected in personal spaces', () async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'p1',
        name: 'Mine',
        currency: 'NPR',
        inviteCode: 'PERS01',
        mode: SpaceMode.personal,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_me',
        name: 'Me',
        email: 'me@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_me',
        name: 'Me',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'p1',
      ),
      'p1',
    );
    state.debugSetSession(userId: 'u_me', spaceId: 'p1');

    final ok = await state.addHissaIncome(
      description: 'Freelance',
      amount: const Money(50000),
      date: DateTime(2026, 1, 3),
      receivedByUserId: 'u_me',
      participantIds: ['u_me'],
    );
    expect(ok, isFalse);
    expect(repo.hissaIncomes, isEmpty);
  });
}
