import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/logic/expense_auth.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';

/// Phase 8 security tests exercised through the AppState API layer (the
/// closest client-side equivalent of a direct API call). The Firestore rules
/// remain the authoritative backend enforcement; these tests mirror that
/// contract so regressions surface in the client too.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeSplitState({String currentUser = 'u_ram'}) async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABC12',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_ram',
        name: 'Ram',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_sita',
        name: 'Sita',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveCycle(
      Cycle(
        id: 'c1',
        householdId: 'h1',
        name: 'January 2026',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: currentUser, spaceId: 'h1');
    return state;
  }

  test('creator can edit their own expense', () async {
    final state = await makeSplitState();
    await state.addExpense(
      description: 'Groceries',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram', 'u_sita'],
    );
    final expense = state.expensesInCycle.single;
    expect(expense.createdBy, 'u_ram');
    expect(state.canEditExpense(expense), isTrue);
  });

  test('a non-creator cannot edit or delete another user expense',
      () async {
    final state = await makeSplitState(currentUser: 'u_sita');
    // Ram's expense: pre-seeded with Ram as the creator.
    await state.repo.saveExpense(
      Expense(
        id: 'e1',
        householdId: 'h1',
        cycleId: 'c1',
        paidByUserId: 'u_ram',
        createdBy: 'u_ram',
        amount: const Money(100000),
        description: 'Ram dinner',
        date: DateTime(2026, 1, 10),
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
      ),
      const [],
    );
    expect(state.canEditExpense(state.expensesInCycle.single), isFalse);

    await state.updateExpense(
      state.expensesInCycle.single,
      description: 'Hijacked',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram', 'u_sita'],
    );
    // The update was rejected: description is unchanged.
    expect(state.expensesInCycle.single.description, 'Ram dinner');

    await state.deleteExpense('e1');
    expect(state.expensesInCycle, isNotEmpty,
        reason: 'a non-creator cannot delete another user expense');
  });

  test('attempting to submit another user as the payer is rejected', () async {
    final state = await makeSplitState();
    // The AppState API never accepts a payer payload: the payer is always
    // derived from the authenticated user (Phase 5).
    await state.addExpense(
      description: 'Groceries',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram', 'u_sita'],
    );
    expect(state.expensesInCycle.single.paidByUserId, 'u_ram');
  });

  test('a participant outside the Space is rejected on create', () async {
    final state = await makeSplitState();
    await state.addExpense(
      description: 'Sneaky',
      amount: const Money(50000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram', 'u_sita', 'u_outsider'],
    );
    expect(state.expensesInCycle, isEmpty,
        reason: 'a client must not include a non-member participant');
  });

  test('a participant group containing a non-member is rejected on create',
      () async {
    final state = await makeSplitState();
    await state.addExpense(
      description: 'Grouped',
      amount: const Money(60000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram'],
      groups: [
        ParticipantGroup(
          id: 'g1',
          expenseId: 'pending',
          name: 'Intruders',
          userIds: ['u_sita', 'u_outsider'],
        ),
      ],
    );
    expect(state.expensesInCycle, isEmpty,
        reason: 'a group must not contain users outside the Space');
  });

  test('a participant group manipulation on update is rejected', () async {
    final state = await makeSplitState();
    await state.addExpense(
      description: 'Original',
      amount: const Money(60000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram', 'u_sita'],
    );
    final expense = state.expensesInCycle.single;
    await state.updateExpense(
      expense,
      description: 'Tampered',
      amount: const Money(60000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_ram'],
      groups: [
        ParticipantGroup(
          id: 'g1',
          expenseId: expense.id,
          name: 'Intruders',
          userIds: ['u_sita', 'u_outsider'],
        ),
      ],
    );
    expect(state.expensesInCycle.single.description, 'Original',
        reason: 'group manipulation must be rejected on update too');
  });

  test('legacy expenses without a creator are locked for everyone', () async {
    final state = await makeSplitState();
    await state.repo.saveExpense(
      Expense(
        id: 'e_legacy',
        householdId: 'h1',
        cycleId: 'c1',
        paidByUserId: 'u_ram',
        createdBy: null, // pre-ownership record
        amount: const Money(70000),
        description: 'Legacy expense',
        date: DateTime(2026, 1, 5),
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
      ),
      const [],
    );
    final legacy = state.expensesInCycle.single;
    expect(state.canEditExpense(legacy), isFalse,
        reason: 'ambiguous legacy expenses stay read-only');
    expect(canEditExpenseBy(currentUserId: 'u_ram', expense: legacy), isFalse);
  });

  test('payer always equals the authenticated user via the auth helper',
      () async {
    expect(payerForCurrentUser('u_ram'), 'u_ram');
    expect(payerForCurrentUser(null), '');
  });

  test('concurrent expense creations persist all expenses', () async {
    final state = await makeSplitState();
    await Future.wait([
      for (var i = 0; i < 5; i++)
        state.addExpense(
          description: 'Expense $i',
          amount: Money(10000 + i * 1000),
          date: DateTime(2026, 1, 10),
          participantIds: ['u_ram', 'u_sita'],
        ),
    ]);
    expect(state.expensesInCycle, hasLength(5));
  });
}