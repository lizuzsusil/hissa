import '../core/ids.dart';
import '../core/money.dart';
import '../models/models.dart';

/// Computes per-participant shares for an expense under any supported
/// split strategy. Always guarantees:
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
    if (participantIds.isEmpty) return const [];

    switch (type) {
      case SplitType.equal:
        return _equalSplit(expenseId, amount, participantIds);
      case SplitType.percentage:
        return _percentageSplit(expenseId, amount, participantIds, percentages);
      case SplitType.custom:
        return _customSplit(expenseId, participantIds, customAmounts);
      case SplitType.shares:
        return _sharesSplit(expenseId, amount, participantIds, shareUnits);
    }
  }

  static List<ExpenseShare> _equalSplit(
    String expenseId,
    Money amount,
    List<String> ids,
  ) {
    final base = amount.paisa ~/ ids.length;
    var remainder = amount.paisa % ids.length;
    return ids.map((id) {
      final share = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      return ExpenseShare(
        id: genId(),
        expenseId: expenseId,
        userId: id,
        amount: Money(share),
      );
    }).toList();
  }

  static List<ExpenseShare> _percentageSplit(
    String expenseId,
    Money amount,
    List<String> ids,
    Map<String, double> percentages,
  ) {
    final total = percentages.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return _equalSplit(expenseId, amount, ids);
    }

    var allocated = 0;
    final results = <({String id, int paisa})>[];
    for (final id in ids) {
      final pct = (percentages[id] ?? 0) / total;
      final share = (amount.paisa * pct).floor();
      allocated += share;
      results.add((id: id, paisa: share));
    }

    // Distribute leftover paisa, largest percentage first.
    var remainder = amount.paisa - allocated;
    final order = List.of(ids)
      ..sort((a, b) => (percentages[b] ?? 0).compareTo(percentages[a] ?? 0));
    for (final id in order) {
      if (remainder <= 0) break;
      final idx = results.indexWhere((r) => r.id == id);
      results[idx] = (id: id, paisa: results[idx].paisa + 1);
      remainder--;
    }

    return results
        .map((r) => ExpenseShare(
              id: genId(),
              expenseId: expenseId,
              userId: r.id,
              amount: Money(r.paisa),
              percentage: percentages[r.id],
            ))
        .toList();
  }

  static List<ExpenseShare> _customSplit(
    String expenseId,
    List<String> ids,
    Map<String, Money> customAmounts,
  ) {
    return ids.map((id) {
      return ExpenseShare(
        id: genId(),
        expenseId: expenseId,
        userId: id,
        amount: customAmounts[id] ?? Money.zero(),
      );
    }).toList();
  }

  static List<ExpenseShare> _sharesSplit(
    String expenseId,
    Money amount,
    List<String> ids,
    Map<String, int> shareUnits,
  ) {
    final totalUnits =
        ids.fold<int>(0, (sum, id) => sum + (shareUnits[id] ?? 1));
    if (totalUnits <= 0) return _equalSplit(expenseId, amount, ids);

    var allocated = 0;
    final results = <({String id, int paisa})>[];
    for (final id in ids) {
      final units = shareUnits[id] ?? 1;
      final share = (amount.paisa * units) ~/ totalUnits;
      allocated += share;
      results.add((id: id, paisa: share));
    }

    var remainder = amount.paisa - allocated;
    final order = List.of(ids)
      ..sort((a, b) => (shareUnits[b] ?? 1).compareTo(shareUnits[a] ?? 1));
    for (final id in order) {
      if (remainder <= 0) break;
      final idx = results.indexWhere((r) => r.id == id);
      results[idx] = (id: id, paisa: results[idx].paisa + 1);
      remainder--;
    }

    return results
        .map((r) => ExpenseShare(
              id: genId(),
              expenseId: expenseId,
              userId: r.id,
              amount: Money(r.paisa),
              shares: shareUnits[r.id],
            ))
        .toList();
  }

  /// Sum of shares for an expense (used for validation in tests).
  static Money totalShares(List<ExpenseShare> shares) {
    return shares.fold(Money.zero(), (sum, s) => sum + s.amount);
  }
}
