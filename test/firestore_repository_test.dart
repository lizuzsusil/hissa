import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/data/firestore_repository.dart';
import 'package:hissa/data/seed.dart';
import 'package:hissa/logic/splits.dart';
import 'package:hissa/models/models.dart';

void main() {
  group('FirestoreRepository', () {
    test('start loads a seeded household into the caches', () async {
      final db = FakeFirebaseFirestore();
      await seedDemoFirestore(db, 'demo_uid');

      var notified = 0;
      final repo = FirestoreRepository(db);
      await repo.start(
        uid: 'demo_uid',
        householdId: 'h_demo',
        onChanged: () => notified++,
      );

      expect(repo.users.map((u) => u.id), contains('demo_uid'));
      expect(repo.households.map((h) => h.id), contains('h_demo'));
      expect(repo.members.map((m) => m.userId), contains('u_sita'));
      expect(repo.expenses.map((e) => e.id), contains('e_aug1'));
      expect(repo.cycles.map((c) => c.id), contains('c_aug'));
      expect(repo.settlements.map((s) => s.id), contains('s_jul1'));
      expect(repo.sharesForExpense('e_aug1'), hasLength(3));
      expect(notified, greaterThan(0));

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
      await reader.start(uid: 'u1', householdId: 'h1', onChanged: () {});
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

    test('findHouseholdByInviteCode matches case-insensitively', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      final household = _household('h1', 'ABCDE');
      await repo.saveHousehold(household);

      expect((await repo.findHouseholdByInviteCode('abcde'))?.id, 'h1');
      expect(await repo.findHouseholdByInviteCode('ZZZZZ'), isNull);
    });

    test('findHouseholdIdForUser returns the membership household', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveMember(
        HouseholdMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        'h1',
      );

      expect(await repo.findHouseholdIdForUser('u1'), 'h1');
      expect(await repo.findHouseholdIdForUser('u999'), isNull);
    });

    test('saveMember and removeMember persist and mirror to the cache',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreRepository(db);
      await repo.saveMember(
        HouseholdMember(
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
      await writer.start(uid: 'u1', householdId: 'h1', onChanged: () {});
      await observer.start(uid: 'u1', householdId: 'h1', onChanged: () {});

      await writer.saveExpense(_expense('e1'), const []);
      await _waitUntil(() => observer.expenses.any((e) => e.id == 'e1'));

      expect(observer.expenses.single.id, 'e1');

      writer.stop();
      observer.stop();
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

Household _household(String id, String inviteCode) => Household(
      id: id,
      name: 'Home',
      currency: 'NPR',
      inviteCode: inviteCode,
      createdAt: DateTime(2026, 1, 1),
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
