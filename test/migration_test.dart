import 'package:flutter_test/flutter_test.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/data/in_memory_repository.dart';
import 'package:hissa/logic/migration.dart';
import 'package:hissa/models/models.dart';

/// Phase 7 — Backward Compatibility & Migration tests.
void main() {
  group('SpaceMigrator', () {
    test('assigns an explicit split mode to legacy Space records', () async {
      final repo = InMemoryRepository();
      // Legacy record: predates the `mode` and `updatedAt` fields.
      final legacy = Space(
        id: 'h1',
        name: 'Legacy Home',
        currency: 'NPR',
        inviteCode: 'ABC12',
        createdAt: DateTime(2025, 6, 1),
      );
      final modern = Space(
        id: 'h2',
        name: 'Modern Home',
        currency: 'NPR',
        inviteCode: 'XYZ99',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        mode: SpaceMode.solo,
      );
      await repo.saveSpace(legacy);
      await repo.saveSpace(modern);
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h2',
        ),
        'h2',
      );

      final report = await SpaceMigrator().run(repo, userId: 'u1');

      expect(report.spacesAssignedMode, 1,
          reason: 'only the legacy record is touched');
      final migrated = repo.spaces.firstWhere((s) => s.id == 'h1');
      expect(migrated.mode, SpaceMode.split);
      expect(migrated.updatedAt, isNotNull);
      // The modern solo space keeps its mode.
      expect(repo.spaces.firstWhere((s) => s.id == 'h2').mode, SpaceMode.solo);
    });

    test('a second run is idempotent', () async {
      final repo = InMemoryRepository();
      await repo.saveSpace(
        Space(
          id: 'h1',
          name: 'Legacy Home',
          currency: 'NPR',
          inviteCode: 'ABC12',
          createdAt: DateTime(2025, 6, 1),
        ),
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );

      final migrator = SpaceMigrator();
      await migrator.run(repo, userId: 'u1');
      final second = await migrator.run(repo, userId: 'u1');

      expect(second.spacesAssignedMode, 0);
    });

    test('legacy expenses are classified, never rewritten', () async {
      final repo = InMemoryRepository();
      await repo.saveSpace(
        Space(
          id: 'h1',
          name: 'Legacy Home',
          currency: 'NPR',
          inviteCode: 'ABC12',
          createdAt: DateTime(2025, 6, 1),
        ),
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'A',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );
      final legacy = Expense(
        id: 'e1',
        householdId: 'h1',
        cycleId: 'c1',
        paidByUserId: 'u1',
        createdBy: null,
        amount: const Money(50000),
        description: 'Legacy',
        date: DateTime(2025, 7, 1),
        createdAt: DateTime(2025, 7, 1),
        updatedAt: DateTime(2025, 7, 1),
      );
      await repo.saveExpense(legacy, const []);

      final report = await SpaceMigrator().run(repo, userId: 'u1');

      expect(report.legacyExpensesFound, 1);
      expect(report.creatorsBackfilled, 0,
          reason: 'ownership is never invented');
      expect(report.ambiguousExpenses, 1);
      // The legacy expense is untouched.
      expect(repo.expenses.single.createdBy, isNull);
    });

    test('classification helpers distinguish legacy records', () {
      final migrator = SpaceMigrator();
      final legacySpace = Space(
        id: 'h1',
        name: 'L',
        currency: 'NPR',
        inviteCode: 'ABC12',
        createdAt: DateTime(2025, 6, 1),
      );
      final modernSpace = legacySpace.copyWith(mode: SpaceMode.solo);
      expect(migrator.isLegacySpace(legacySpace), isTrue);
      expect(migrator.isLegacySpace(modernSpace), isFalse);

      final legacyExpense = Expense(
        id: 'e1',
        householdId: 'h1',
        cycleId: 'c1',
        paidByUserId: 'u1',
        createdBy: null,
        amount: const Money(50000),
        description: 'L',
        date: DateTime(2025, 7, 1),
        createdAt: DateTime(2025, 7, 1),
        updatedAt: DateTime(2025, 7, 1),
      );
      final ownedExpense = Expense(
        id: 'e2',
        householdId: 'h1',
        cycleId: 'c1',
        paidByUserId: 'u1',
        createdBy: 'u1',
        amount: const Money(50000),
        description: 'O',
        date: DateTime(2025, 7, 1),
        createdAt: DateTime(2025, 7, 1),
        updatedAt: DateTime(2025, 7, 1),
      );
      expect(migrator.isLegacyExpense(legacyExpense), isTrue);
      expect(migrator.isLegacyExpense(ownedExpense), isFalse);
    });

    test('a migration failure never blocks the app', () async {
      final repo = _FailingRepo();
      final report = await SpaceMigrator().run(repo, userId: 'u1');
      expect(report.spacesAssignedMode, 0);
    });
  });
}

/// Repository whose space lookup throws, proving migration is best-effort.
class _FailingRepo extends InMemoryRepository {
  @override
  Future<List<Space>> findSpacesForUser(String userId) async {
    throw Exception('boom');
  }
}