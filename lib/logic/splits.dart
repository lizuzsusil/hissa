import '../core/ids.dart';
import '../core/money.dart';
import '../models/models.dart';

/// A single split party: either one Space member or a group of members that
/// share a single share of an expense (Phase 6).
///
/// The split amount is computed at the party level; a group's share is then
/// distributed equally between its members.
class SplitParty {
  /// Party identifier: the [userId] for an individual, or the group id.
  final String id;

  /// Display name for a group (e.g. "B + C"); null for individuals.
  final String? name;

  /// Underlying user ids that make up this party.
  final List<String> userIds;

  bool get isGroup => userIds.length > 1;

  const SplitParty({required this.id, this.name, required this.userIds});

  factory SplitParty.individual(String userId) =>
      SplitParty(id: userId, userIds: [userId]);
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

  /// Splits [amount] across [parties] at the party level, then distributes each
  /// group party's share equally between its members.
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
      final members = party.userIds;
      final base = partyPaisa ~/ members.length;
      var remainder = partyPaisa % members.length;
      final percentage =
          type == SplitType.percentage ? percentages[party.id] : null;
      final shareUnits_ =
          type == SplitType.shares ? shareUnits[party.id] : null;
      for (final uid in members) {
        final paisa = base + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
        shares.add(ExpenseShare(
          id: genId(),
          expenseId: expenseId,
          userId: uid,
          amount: Money(paisa),
          percentage: percentage,
          shares: shareUnits_,
          groupId: party.isGroup ? party.id : null,
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
