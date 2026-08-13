import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/data/firestore_repository.dart';
import 'package:hissa/logic/splits.dart';
import 'package:hissa/models/models.dart';

void main() {
  group('FirestoreRepository', () {
    test('start loads a space into the caches', () async {
      final db = FakeFirebaseFirestore();
      final writer = FirestoreRepository(db);
      await writer.saveUser(
        User(id: 'u1', name: 'A', email: 'a@x.com', createdAt: DateTime(2026, 1, 1)),
      );
      await writer.saveSpace(_space('h1', 'ABCDE'));
      await writer.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );
      await writer.saveCycle(_cycle('c1', 'h1'));
      await writer.saveExpense(
        _expense('e1'),
        SplitCalculator.build(
          expenseId: 'e1',
          amount: const Money(100000),
          participantIds: ['u1', 'u2'],
        ),
      );
      await writer.saveSettlement(
        Settlement(
          id: 's1',
          householdId: 'h1',
          cycleId: 'c1',
          fromUserId: 'u2',
          toUserId: 'u1',
          amount: const Money(50000),
          currency: 'NPR',
          paymentMethod: 'Cash',
          date: DateTime(2026, 1, 15),
          status: SettlementStatus.paid,
          createdAt: DateTime(2026, 1, 15),
        ),
      );

      var notified = 0;
      final repo = FirestoreRepository(db);
      await repo.start(
        uid: 'u1',
        spaceId: 'h1',
        onChanged: () => notified++,
      );

      expect(repo.users.map((u) => u.id), contains('u1'));
      expect(repo.spaces.map((h) => h.id), contains('h1'));
      expect(repo.members.map((m) => m.userId), contains('u1'));
      expect(repo.expenses.map((e) => e.id), contains('e1'));
      expect(repo.cycles.map((c) => c.id), contains('c1'));
      expect(repo.settlements.map((s) => s.id), contains('s1'));
      expect(repo.sharesForExpense('e1'), hasLength(2));
      expect(notified, greaterThan(0));

      repo.stop();
    });

    test('saveExpense persists participant groups and their member shares',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);

      final grouped = _groupedExpense('e1');
      final shares = SplitCalculator.buildGrouped(
        expenseId: 'e1',
        amount: grouped.amount,
        parties: [
          SplitParty.individual('u1'),
          SplitParty(id: 'g1', name: 'B + C', userIds: ['u2', 'u3']),
        ],
      );
      await repo.saveExpense(grouped, shares);

      final reader = FirestoreRepository(db);
      await reader.start(uid: 'u1', spaceId: 'h1', onChanged: () {});
      final saved = reader.expenses.firstWhere((e) => e.id == 'e1');
      expect(saved.participantGroups, hasLength(1));
      expect(saved.participantGroups.first.name, 'B + C');
      expect(saved.participantGroups.first.userIds, ['u2', 'u3']);

      final savedShares = reader.sharesForExpense('e1');
      expect(savedShares, hasLength(3));
      final b = savedShares.firstWhere((s) => s.userId == 'u2');
      final c = savedShares.firstWhere((s) => s.userId == 'u3');
      expect(b.groupId, 'g1');
      expect(c.groupId, 'g1');

      repo.stop();
    });

    test('saveExpense writes shares and replaces them on update', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);

      final expense = _expense('e1');
      final shares = SplitCalculator.build(
        expenseId: 'e1',
        amount: expense.amount,
        participantIds: ['u1', 'u2', 'u3'],
      );
      await repo.saveExpense(expense, shares);

      expect(repo.expenses.map((e) => e.id), contains('e1'));
      expect(repo.sharesForExpense('e1'), hasLength(3));

      final reader = FirestoreRepository(db);
      await reader.start(uid: 'u1', spaceId: 'h1', onChanged: () {});
      expect(reader.expenses.map((e) => e.id), contains('e1'));
      expect(reader.sharesForExpense('e1'), hasLength(3));

      final updatedShares = SplitCalculator.build(
        expenseId: 'e1',
        amount: expense.amount,
        participantIds: ['u1'],
      );
      await repo.saveExpense(expense, updatedShares);
      expect(repo.sharesForExpense('e1'), hasLength(1));

      final snap = await db.collection('expenseShares').get();
      expect(snap.docs, hasLength(1));
    });

    test('saveExpense persists the payer as the authenticated user', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);

      final expense = _expense('e1').copyWith(
        paidByUserId: 'u1',
        createdBy: 'u1',
      );
      await repo.saveExpense(expense, const []);

      final doc =
          await db.collection('expenses').doc('h1_e1').get();
      expect(doc.data()!['paidByUserId'], 'u1');
      expect(doc.data()!['createdBy'], 'u1');
    });

    test('deleteExpense removes the expense and its shares', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      final expense = _expense('e1');
      final shares = SplitCalculator.build(
        expenseId: 'e1',
        amount: expense.amount,
        participantIds: ['u1', 'u2'],
      );
      await repo.saveExpense(expense, shares);
      await repo.deleteExpense('e1');

      expect(repo.expenses, isEmpty);
      expect(repo.sharesForExpense('e1'), isEmpty);
      final snap = await db.collection('expenseShares').get();
      expect(snap.docs, isEmpty);
    });

    test('personal expense persists without shares', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      final personal = Expense(
        id: 'p1',
        householdId: 'h1',
        cycleId: null,
        paidByUserId: 'u1',
        createdBy: 'u1',
        amount: const Money(500000),
        description: 'Groceries',
        date: DateTime(2026, 1, 20),
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
      );
      await repo.saveExpense(personal, const []);

      expect(repo.expenses.single.cycleId, isNull);
      expect(repo.expenses.single.createdBy, 'u1');
      expect(repo.sharesForExpense('p1'), isEmpty);

      final reader = FirestoreRepository(db);
      await reader.start(uid: 'u1', spaceId: 'h1', onChanged: () {});
      expect(reader.expenses.single.cycleId, isNull);
      expect(reader.expenses.single.createdBy, 'u1');
      final snap = await db.collection('expenseShares').get();
      expect(snap.docs, isEmpty);
    });

    test('findSpaceByInviteCode matches case-insensitively', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      final space = _space('h1', 'ABCDE');
      await repo.saveSpace(space);

      expect((await repo.findSpaceByInviteCode('abcde'))?.id, 'h1');
      expect(await repo.findSpaceByInviteCode('ZZZZZ'), isNull);
    });

    test('findSpaceIdForUser returns the membership space', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );

      expect(await repo.findSpaceIdForUser('u1'), 'h1');
      expect(await repo.findSpaceIdForUser('u999'), isNull);
    });

    test('saveMember and removeMember persist and mirror to the cache',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveMember(
        SpaceMember(
          userId: 'u2',
          name: 'B',
          role: MemberRole.member,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );
      expect(repo.members.map((m) => m.userId), contains('u2'));

      await repo.removeMember('u2', 'h1');
      expect(repo.members.map((m) => m.userId), isNot(contains('u2')));
      expect((await db.collection('householdMembers').doc('h1_u2').get()).exists,
          isFalse);
    });

    test('realtime listeners propagate another instance write', () async {
      final db = FakeFirebaseFirestore();
      final writer = FirestoreRepository(db);
      final observer = FirestoreRepository(db);
      await writer.start(uid: 'u1', spaceId: 'h1', onChanged: () {});
      await observer.start(uid: 'u1', spaceId: 'h1', onChanged: () {});

      await writer.saveExpense(_expense('e1'), const []);
      await _waitUntil(() => observer.expenses.any((e) => e.id == 'e1'));

      expect(observer.expenses.single.id, 'e1');

      writer.stop();
      observer.stop();
    });

    test('findSpacesForUser returns every space the user belongs to',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveSpace(_space('h1', 'AAAAA'));
      await repo.saveSpace(_space('h2', 'BBBBB'));
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.member,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h2',
      );

      final spaces = await repo.findSpacesForUser('u1');
      expect(spaces.map((h) => h.id).toSet(), {'h1', 'h2'});
      expect(await repo.findSpacesForUser('u999'), isEmpty);
    });

    test('countMembers counts the space membership docs', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u2',
          name: 'B',
          role: MemberRole.member,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );

      expect(await repo.countMembers('h1'), 2);
      expect(await repo.countMembers('h9'), 0);
    });

    test('space mode is persisted and defaults to SPLIT for legacy docs',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveSpace(
        _space('h1', 'AAAAA').copyWith(mode: SpaceMode.solo),
      );
      expect((await repo.findSpacesForUser('u1')), isEmpty);
      final solo = Space.fromJson(
        (await db.collection('households').doc('h1').get()).data()!,
      );
      expect(solo.mode, SpaceMode.solo);

      await db.collection('households').doc('legacy').set({
        'id': 'legacy',
        'name': 'Old home',
        'currency': 'NPR',
        'inviteCode': 'LEGACY',
        'createdAt': '2026-01-01T00:00:00.000',
      });
      final legacy = Space.fromJson(
        (await db.collection('households').doc('legacy').get()).data()!,
      );
      expect(legacy.mode, SpaceMode.split);
      expect(legacy.createdBy, isNull);
      expect(legacy.updatedAt, isNull);
    });
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Space _space(String id, String inviteCode) => Space(
      id: id,
      name: 'Home',
      currency: 'NPR',
      inviteCode: inviteCode,
      createdAt: DateTime(2026, 1, 1),
    );

Cycle _cycle(String id, String householdId) => Cycle(
      id: id,
      householdId: householdId,
      name: 'January 2026',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      status: CycleStatus.active,
    );

Expense _expense(String id) => Expense(
      id: id,
      householdId: 'h1',
      cycleId: 'c1',
      paidByUserId: 'u1',
      amount: const Money(100000),
      description: 'Test',
      date: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Expense _groupedExpense(String id) => Expense(
      id: id,
      householdId: 'h1',
      cycleId: 'c1',
      paidByUserId: 'u1',
      amount: const Money(100000),
      description: 'Test',
      date: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      participantGroups: const [
        ParticipantGroup(
          id: 'g1',
          expenseId: 'e1',
          name: 'B + C',
          userIds: ['u2', 'u3'],
        ),
      ],
    );
