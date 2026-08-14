import '../data/repository.dart';
import '../models/models.dart';

/// Outcome of a legacy-data migration pass.
class MigrationReport {
  const MigrationReport({
    this.spacesAssignedMode = 0,
    this.legacyExpensesFound = 0,
    this.creatorsBackfilled = 0,
    this.ambiguousExpenses = 0,
  });

  /// Legacy Space records that had no explicit [SpaceMode] and were assigned
  /// [SpaceMode.split].
  final int spacesAssignedMode;

  /// Expenses whose `createdBy` is absent (created before ownership was
  /// introduced).
  final int legacyExpensesFound;

  /// Legacy expenses whose creator was reliably backfilled.
  final int creatorsBackfilled;

  /// Legacy expenses whose creator could not be reliably determined; these
  /// stay read-only historical records.
  final int ambiguousExpenses;

  bool get hasWork =>
      spacesAssignedMode > 0 ||
      creatorsBackfilled > 0 ||
      legacyExpensesFound > 0;
}

/// Phase 7 — Backward Compatibility & Migration.
///
/// Existing Split Mode data may predate the `createdBy` ownership field and
/// the [SpaceMode]. This migrator:
///
///  1. Assigns an explicit [SpaceMode.split] to legacy Space records so the
///     `mode` field is never absent.
///  2. Backfills `createdBy` on legacy expenses *only* where a reliable
///     creator can be derived from the existing data.
///  3. Marks the remaining legacy expenses as ambiguous; they stay read-only
///     historical records (ownership is never invented).
///
/// The Firestore schema (`spaces/{id}`) is the single source of truth; the
/// migrator only touches records that predate the explicit [SpaceMode].
class SpaceMigrator {
  /// True when [space] predates the explicit [SpaceMode] field. New records
  /// always carry a `mode`; legacy records default to split on read, but are
  /// not yet persisted with one.
  bool isLegacySpace(Space space) => space.updatedAt == null;

  /// True when [expense] was created before ownership was introduced.
  bool isLegacyExpense(Expense expense) => expense.createdBy == null;

  /// Derives a reliable creator for a legacy [expense] from the existing
  /// schema, or returns null when ownership cannot be determined.
  ///
  /// The pre-Phase-4 schema had no creator/author field, and `paidByUserId`
  /// is deliberately *not* treated as a creator because the old product
  /// allowed any member to be marked as payer ("Paid By"). Treating the payer
  /// as the creator would invent ownership, so nothing is backfilled here.
  /// Subclasses may override this to plug in a field if one is ever added.
  String? reliableCreatorFor(Expense expense, List<ExpenseShare> shares) =>
      null;

  /// Migrates legacy records reachable from [repo].
  ///
  /// Only Firestore-worthy legacy records are rewritten: spaces missing an
  /// explicit mode. Legacy expenses are classified but never modified, so a
  /// re-run is always safe (the pass is idempotent).
  ///
  /// [spaces] lets callers pass the already-fetched Space list to avoid a
  /// second `findSpacesForUser` round-trip during Space switching.
  Future<MigrationReport> run(
    ExpenseRepository repo, {
    required String userId,
    List<Space>? spaces,
  }) async {
    var assigned = 0;
    try {
      final list = spaces ?? await repo.findSpacesForUser(userId);
      for (final space in list) {
        if (!isLegacySpace(space)) continue;
        await repo.saveSpace(space.copyWith(mode: SpaceMode.split));
        assigned++;
      }
    } on Exception {
      // A migration must never take the app down; reads already default to
      // split mode, so a failed write is non-fatal.
    }

    final legacy = repo.expenses.where(isLegacyExpense).toList();
    var backfilled = 0;
    var ambiguous = 0;
    for (final expense in legacy) {
      final creator =
          reliableCreatorFor(expense, repo.sharesForExpense(expense.id));
      if (creator != null) {
        backfilled++;
      } else {
        ambiguous++;
      }
    }

    return MigrationReport(
      spacesAssignedMode: assigned,
      legacyExpensesFound: legacy.length,
      creatorsBackfilled: backfilled,
      ambiguousExpenses: ambiguous,
    );
  }
}
