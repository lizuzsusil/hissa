import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';

/// Phase 8 — Personal Mode tests: expense CRUD works without settlement or
/// balance calculations leaking into a personal space.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makePersonalState() async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Me',
        currency: 'NPR',
        inviteCode: 'ABC12',
        mode: SpaceMode.personal,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u1',
        name: 'Ram',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    state.debugSetSession(userId: 'u1', spaceId: 'h1');
    return state;
  }

  test('personal mode is detected', () async {
    final state = await makePersonalState();
    expect(state.isPersonalMode, isTrue);
  });

  test('create, edit and delete a personal expense', () async {
    final state = await makePersonalState();

    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(5000),
      date: DateTime(2026, 1, 12),
    );
    expect(state.personalExpenses, hasLength(1));
    expect(state.personalTotalSpent(DateTime(2026, 1)), const Money(5000));

    await state.updatePersonalExpense(
      state.personalExpenses.single,
      description: 'Latte',
      amount: const Money(6000),
      date: DateTime(2026, 1, 12),
    );
    expect(state.personalExpenses.single.description, 'Latte');
    expect(state.personalTotalSpent(DateTime(2026, 1)), const Money(6000));

    await state.deleteExpense(state.personalExpenses.single.id);
    expect(state.personalExpenses, isEmpty);
  });

  test('personal expenses have no participant shares', () async {
    final state = await makePersonalState();
    await state.addPersonalExpense(
      description: 'Snack',
      amount: const Money(3000),
      date: DateTime(2026, 1, 13),
    );
    final expense = state.personalExpenses.single;
    expect(
      state.sharesForExpense(expense.id),
      isEmpty,
      reason: 'personal mode must not mint participant shares',
    );
  });

  test('settlement logic is not exposed in personal mode', () async {
    final state = await makePersonalState();
    // A personal space has no cycles, so cycle-based calculations are empty.
    expect(state.cycles, isEmpty);
    expect(state.expensesInCycle, isEmpty);
    expect(state.settlementProposals(), isEmpty);
    expect(state.computeBalances(), isEmpty);
  });

  test(
    'a settlement cannot be recorded in a personal space (no cycle)',
    () async {
      final state = await makePersonalState();
      await state.addSettlement(
        fromUserId: 'u1',
        toUserId: 'u1',
        amount: const Money(1000),
        paymentMethod: 'Cash',
        date: DateTime(2026, 1, 15),
      );
      expect(state.repo.settlements, isEmpty);
    },
  );

  group('estimated expenses', () {
    test('add a planned amount for a month', () async {
      final state = await makePersonalState();
      await state.addEstimatedExpense(
        description: 'Rent',
        amount: const Money(1500000),
        month: DateTime(2026, 1),
      );
      expect(state.estimatedExpenses, hasLength(1));
      final estimate = state.estimatedExpenses.single;
      expect(estimate.description, 'Rent');
      expect(estimate.amount, const Money(1500000));
      expect(estimate.month, DateTime(2026, 1));
      expect(
        state.estimatedExpensesForMonth(DateTime(2026, 1)),
        hasLength(1),
      );
      expect(
        state.estimatedTotalForMonth(DateTime(2026, 1)),
        const Money(1500000),
      );
    });

    test('estimates never count as actual spending', () async {
      final state = await makePersonalState();
      await state.addEstimatedExpense(
        description: 'Planned vacation',
        amount: const Money(9000000),
        month: DateTime(2026, 1),
      );
      expect(state.personalExpenses, isEmpty);
      expect(
        state.personalTotalSpent(DateTime(2026, 1)),
        const Money(0),
        reason: 'planned amounts must not leak into actual spending totals',
      );
    });

    test('estimates are scoped to their month', () async {
      final state = await makePersonalState();
      await state.addEstimatedExpense(
        description: 'January rent',
        amount: const Money(1500000),
        month: DateTime(2026, 1),
      );
      await state.addEstimatedExpense(
        description: 'February rent',
        amount: const Money(1600000),
        month: DateTime(2026, 2),
      );
      expect(
        state.estimatedTotalForMonth(DateTime(2026, 1)),
        const Money(1500000),
      );
      expect(
        state.estimatedTotalForMonth(DateTime(2026, 2)),
        const Money(1600000),
      );
      expect(state.estimatedExpensesForMonth(DateTime(2026, 3)), isEmpty);
    });

    test('edit an estimate keeps it separate from actual expenses', () async {
      final state = await makePersonalState();
      await state.addEstimatedExpense(
        description: 'Rent',
        amount: const Money(1500000),
        month: DateTime(2026, 1),
      );
      await state.updateEstimatedExpense(
        state.estimatedExpenses.single,
        description: 'Rent + utilities',
        amount: const Money(1750000),
        month: DateTime(2026, 1),
      );
      final estimate = state.estimatedExpenses.single;
      expect(estimate.description, 'Rent + utilities');
      expect(estimate.amount, const Money(1750000));
      expect(
        state.estimatedTotalForMonth(DateTime(2026, 1)),
        const Money(1750000),
      );
      expect(state.personalExpenses, isEmpty);
    });

    test('delete an estimate removes only the planned amount', () async {
      final state = await makePersonalState();
      await state.addEstimatedExpense(
        description: 'Gadget',
        amount: const Money(800000),
        month: DateTime(2026, 1),
      );
      await state.addPersonalExpense(
        description: 'Coffee',
        amount: const Money(5000),
        date: DateTime(2026, 1, 12),
      );
      await state.deleteEstimatedExpense(state.estimatedExpenses.single.id);
      expect(state.estimatedExpenses, isEmpty);
      expect(state.personalExpenses, hasLength(1));
      expect(
        state.personalTotalSpent(DateTime(2026, 1)),
        const Money(5000),
      );
    });
  });
}
