import '../core/ids.dart';
import '../core/money.dart';
import '../models/models.dart';

/// A single split party: either one Space member (USER) or a Member Group (GROUP).
///
/// The split amount is computed at the party level. A group party produces a
/// SINGLE share — its amount is never divided between the users inside it.
class SplitParty {
  /// Party identifier: the [userId] for USER, or the [memberGroupId] for GROUP.
  final String id;

  /// The type of this participant entity.
  final ExpenseParticipantType type;

  /// Display name for a group (e.g. "User 2's Group"); null for individuals.
  final String? name;

  /// Underlying user ids that make up this party (for display only).
  final List<String> userIds;

  bool get isGroup => type == ExpenseParticipantType.group;

  const SplitParty({
    required this.id,
    required this.type,
    this.name,
    required this.userIds,
  });

  factory SplitParty.individual(String userId) =>
      SplitParty(
        id: userId,
        type: ExpenseParticipantType.user,
        userIds: [userId],
      );

  factory SplitParty.group({
    required String groupId,
    required String name,
    required List<String> userIds,
  }) =>
      SplitParty(
        id: groupId,
        type: ExpenseParticipantType.group,
        name: name,
        userIds: userIds,
      );
}

/// Computes per-user shares for an expense under any supported split strategy.
/// Always guarantees:
///   Sum(shares.amount) == expense.amount
class SplitCalculator {
  static List<ExpenseShare> build({
    required String expenseId,
    required Money amount,
    required List<String> participantIds,
    SplitType type = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) {
    return buildGrouped(
      expenseId: expenseId,
      amount: amount,
      parties: participantIds.map(SplitParty.individual).toList(),
      type: type,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
  }

  /// Splits [amount] across [parties] at the party level. Each party gets
  /// exactly ONE [ExpenseShare] — groups are never internally divided.
  ///
  /// [percentages], [customAmounts] and [shareUnits] are keyed by party id
  /// (the [SplitParty.id], which is a userId for individuals and a group id for
  /// groups). A user may appear in at most one party.
  static List<ExpenseShare> buildGrouped({
    required String expenseId,
    required Money amount,
    required List<SplitParty> parties,
    SplitType type = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) {
    if (parties.isEmpty) return const [];

    final partyIds = parties.map((p) => p.id).toList();
    final partyAmounts = _splitPartyAmounts(
      amount,
      partyIds,
      type,
      percentages,
      customAmounts,
      shareUnits,
    );

    final shares = <ExpenseShare>[];
    for (var i = 0; i < parties.length; i++) {
      final party = parties[i];
      final partyPaisa = partyAmounts[i];
      final isGroup = party.isGroup;

      if (isGroup) {
        // Single share for the group as a financial participant.
        shares.add(ExpenseShare(
          id: genId(),
          expenseId: expenseId,
          userId: null,
          amount: Money(partyPaisa),
          percentage: type == SplitType.percentage ? percentages[party.id] : null,
          shares: type == SplitType.shares ? shareUnits[party.id] : null,
          participantType: ExpenseParticipantType.group,
          memberGroupId: party.id,
          // The snapshot is attached by the caller (AppState) which has access
          // to the current MemberGroup membership.
        ));
      } else {
        // Single share for the individual user.
        shares.add(ExpenseShare(
          id: genId(),
          expenseId: expenseId,
          userId: party.id,
          amount: Money(partyPaisa),
          percentage: type == SplitType.percentage ? percentages[party.id] : null,
          shares: type == SplitType.shares ? shareUnits[party.id] : null,
          participantType: ExpenseParticipantType.user,
        ));
      }
    }
    return shares;
  }

  /// Party-level split amounts (paisa), one per [ids] entry.
  static List<int> _splitPartyAmounts(
    Money amount,
    List<String> ids,
    SplitType type,
    Map<String, double> percentages,
    Map<String, Money> customAmounts,
    Map<String, int> shareUnits,
  ) {
    switch (type) {
      case SplitType.equal:
        return _equalAmounts(amount, ids.length);
      case SplitType.percentage:
        return _percentageAmounts(amount, ids, percentages);
      case SplitType.custom:
        return [
          for (final id in ids) customAmounts[id]?.paisa ?? 0,
        ];
      case SplitType.shares:
        return _sharesAmounts(amount, ids, shareUnits);
    }
  }

  static List<int> _equalAmounts(Money amount, int n) {
    final base = amount.paisa ~/ n;
    var remainder = amount.paisa % n;
    return List.generate(n, (i) {
      final paisa = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      return paisa;
    });
  }

  static List<int> _percentageAmounts(
    Money amount,
    List<String> ids,
    Map<String, double> percentages,
  ) {
    final total = percentages.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return _equalAmounts(amount, ids.length);

    var allocated = 0;
    final results = <int>[];
    for (final id in ids) {
      final pct = (percentages[id] ?? 0) / total;
      final share = (amount.paisa * pct).floor();
      allocated += share;
      results.add(share);
    }

    // Distribute leftover paisa, largest percentage first.
    var remainder = amount.paisa - allocated;
    final order = List.of(ids)
      ..sort((a, b) => (percentages[b] ?? 0).compareTo(percentages[a] ?? 0));
    for (final id in order) {
      if (remainder <= 0) break;
      final idx = ids.indexOf(id);
      results[idx] = results[idx] + 1;
      remainder--;
    }
    return results;
  }

  static List<int> _sharesAmounts(
    Money amount,
    List<String> ids,
    Map<String, int> shareUnits,
  ) {
    final totalUnits =
        ids.fold<int>(0, (sum, id) => sum + (shareUnits[id] ?? 1));
    if (totalUnits <= 0) return _equalAmounts(amount, ids.length);

    var allocated = 0;
    final results = <int>[];
    for (final id in ids) {
      final units = shareUnits[id] ?? 1;
      final share = (amount.paisa * units) ~/ totalUnits;
      allocated += share;
      results.add(share);
    }

    var remainder = amount.paisa - allocated;
    final order = List.of(ids)
      ..sort((a, b) => (shareUnits[b] ?? 1).compareTo(shareUnits[a] ?? 1));
    for (final id in order) {
      if (remainder <= 0) break;
      final idx = ids.indexOf(id);
      results[idx] = results[idx] + 1;
      remainder--;
    }
    return results;
  }

  /// Sum of shares for an expense (used for validation in tests).
  static Money totalShares(List<ExpenseShare> shares) {
    return shares.fold(Money.zero(), (sum, s) => sum + s.amount);
  }
}
