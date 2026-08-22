import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';

/// Split-Mode settlement approval flow: only the debtor may initiate a
/// settlement, only the creditor may approve or reject it, and balances move
/// only once a request is approved.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Two-member split space with the session on the owner.
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
    await repo.saveMember(
      SpaceMember(
        userId: 'u_owner',
        name: 'Owner',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_b',
        name: 'B',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
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
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    return state;
  }

  /// Owner pays 1000 split equally with B -> B owes 500 to the owner.
  Future<void> addDinner(AppState state) async {
    await state.addExpense(
      description: 'Dinner',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_owner', 'u_b'],
    );
  }

  test('only the debtor can initiate a settlement request', () async {
    final state = await makeState();
    await addDinner(state);

    // B owes 500; the owner (creditor) cannot request their own money.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    var ok = await state.requestSettlement(
      toUserId: 'u_b',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(ok, isFalse);
    expect(state.repo.settlements, isEmpty);

    // The debtor (B) initiates the settlement of what they owe.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    ok = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(ok, isTrue);
    expect(state.repo.settlements.single.status,
        SettlementStatus.pendingApproval);
    expect(state.repo.settlements.single.fromUserId, 'u_b');
    expect(state.repo.settlements.single.toUserId, 'u_owner');
  });

  test('a pending request does not change outstanding balances', () async {
    final state = await makeState();
    await addDinner(state);
    // From here on B acts: they are the debtor.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');

    final ok = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(ok, isTrue);

    // Still unsettled: the proposal remains and B still shows a debt.
    expect(state.pendingSettlementRequests, hasLength(1));
    expect(state.settlementProposals(), isNotEmpty);
    final b = state.computeBalances().singleWhere((e) => e.userId == 'u_b');
    expect(b.remaining.paisa, -50000);
  });

  test('only the creditor can approve a request', () async {
    final state = await makeState();
    await addDinner(state);
    // From here on B acts: they are the debtor.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );

    // The debtor cannot approve their own request.
    final approvedByDebtor =
        await state.approveSettlement(state.repo.settlements.single.id);
    expect(approvedByDebtor, isFalse);
    expect(
      state.repo.settlements.single.status,
      SettlementStatus.pendingApproval,
    );
    // ...nor can they reject it.
    final rejectedByDebtor =
        await state.rejectSettlement(state.repo.settlements.single.id);
    expect(rejectedByDebtor, isFalse);
    expect(
      state.repo.settlements.single.status,
      SettlementStatus.pendingApproval,
    );

    // The creditor approves and the record becomes settled.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final approved = await state.approveSettlement(
      state.repo.settlements.single.id,
    );
    expect(approved, isTrue);
    expect(
      state.repo.settlements.single.status,
      SettlementStatus.approved,
    );
    expect(state.repo.settlements.single.respondedAt, isNotNull);

    // A decision is final: re-approving or rejecting afterwards is refused.
    expect(
      await state.rejectSettlement(state.repo.settlements.single.id),
      isFalse,
    );
  });

  test('approval settles the amount and clears the balance', () async {
    final state = await makeState();
    await addDinner(state);
    // From here on B acts: they are the debtor.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.approveSettlement(state.repo.settlements.single.id);

    // Fully settled: no proposals left and both sides are even.
    expect(state.resolvedSettlements.single.status,
        SettlementStatus.approved);
    expect(state.settlementProposals(), isEmpty);
    for (final b in state.computeBalances()) {
      expect(b.remaining.isZero, isTrue);
    }
  });

  test('a rejected request stays unsettled and the debtor can re-request',
      () async {
    final state = await makeState();
    await addDinner(state);
    // From here on B acts: they are the debtor.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final rejected = await state.rejectSettlement(
      state.repo.settlements.single.id,
    );
    expect(rejected, isTrue);
    expect(state.repo.settlements.single.status, SettlementStatus.rejected);

    // Nothing was settled: the debt remains fully outstanding.
    expect(state.settlementProposals(), isNotEmpty);
    final b = state.computeBalances().singleWhere((e) => e.userId == 'u_b');
    expect(b.remaining.paisa, -50000);

    // The debtor submits a new request which the creditor approves.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final again = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'eSewa',
      date: DateTime(2026, 1, 14),
    );
    expect(again, isTrue);
    expect(state.pendingSettlementRequests, hasLength(1));

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.approveSettlement(state.pendingSettlementRequests.single.id);
    expect(state.settlementProposals(), isEmpty);
  });

  test('a request cannot exceed what is still outstanding', () async {
    final state = await makeState();
    await addDinner(state);
    // From here on B acts: they are the debtor.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');

    // B owes 500 but tries to settle 600.
    var ok = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(60000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(ok, isFalse);
    expect(state.repo.settlements, isEmpty);

    // Partial settlements are allowed while anything remains unsettled.
    ok = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(20000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(ok, isTrue);

    // Pending amounts count against the cap: only 300 more is requestable.
    expect(
      state.outstandingBetween('u_b', 'u_owner').paisa,
      30000,
    );
    ok = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(40000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 13),
    );
    expect(ok, isFalse);
  });

  test('legacy paid settlements still reduce balances', () async {
    final state = await makeState();
    await addDinner(state);
    await state.repo.saveSettlement(
      Settlement(
        id: 's_legacy',
        spaceId: 'h1',
        cycleId: 'c1',
        fromUserId: 'u_b',
        toUserId: 'u_owner',
        amount: const Money(50000),
        currency: 'NPR',
        paymentMethod: 'Cash',
        date: DateTime(2026, 1, 12),
        status: SettlementStatus.paid,
        createdAt: DateTime(2026, 1, 12),
      ),
    );

    expect(state.settlementProposals(), isEmpty);
    for (final b in state.computeBalances()) {
      expect(b.remaining.isZero, isTrue);
    }
  });
}
