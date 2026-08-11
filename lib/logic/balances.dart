import '../core/money.dart';
import '../models/models.dart';

/// Per-member ledger summary for a cycle.
class BalanceInfo {
  final String userId;
  final Money paid;
  final Money share;
  final Money balance;
  final Money settledOut; // money given to others
  final Money settledIn; // money received from others

  const BalanceInfo({
    required this.userId,
    required this.paid,
    required this.share,
    required this.balance,
    required this.settledOut,
    required this.settledIn,
  });

  /// Remaining outstanding after recorded settlements.
  Money get remaining => balance + settledOut - settledIn;

  Money get totalPaid => paid + settledOut;

  bool get isOwed => balance.isPositive;
  bool get owes => balance.isNegative;
}

class BalanceCalculator {
  /// Computes [BalanceInfo] for every member of [household] within [cycle].
  static List<BalanceInfo> compute({
    required Household household,
    required List<HouseholdMember> members,
    required Cycle cycle,
    required List<Expense> expenses,
    required List<ExpenseShare> shares,
    required List<Settlement> settlements,
  }) {
    final expensesInCycle =
        expenses.where((e) => e.cycleId == cycle.id).toList();
    final sharesInCycle =
        shares.where((s) => expensesInCycle.any((e) => e.id == s.expenseId)).toList();
    final settlementsInCycle =
        settlements.where((s) => s.cycleId == cycle.id).toList();

    final paidBy = <String, int>{};
    final shareBy = <String, int>{};
    final settledOut = <String, int>{};
    final settledIn = <String, int>{};

    for (final member in members) {
      paidBy[member.userId] = 0;
      shareBy[member.userId] = 0;
      settledOut[member.userId] = 0;
      settledIn[member.userId] = 0;
    }

    for (final expense in expensesInCycle) {
      paidBy[expense.paidByUserId] =
          (paidBy[expense.paidByUserId] ?? 0) + expense.amount.paisa;
    }

    for (final share in sharesInCycle) {
      shareBy[share.userId] = (shareBy[share.userId] ?? 0) + share.amount.paisa;
    }

    for (final settlement in settlementsInCycle) {
      if (settlement.status == SettlementStatus.cancelled) continue;
      settledOut[settlement.fromUserId] =
          (settledOut[settlement.fromUserId] ?? 0) + settlement.amount.paisa;
      settledIn[settlement.toUserId] =
          (settledIn[settlement.toUserId] ?? 0) + settlement.amount.paisa;
    }

    return members.map((member) {
      final paid = paidBy[member.userId] ?? 0;
      final share = shareBy[member.userId] ?? 0;
      return BalanceInfo(
        userId: member.userId,
        paid: Money(paid),
        share: Money(share),
        balance: Money(paid - share),
        settledOut: Money(settledOut[member.userId] ?? 0),
        settledIn: Money(settledIn[member.userId] ?? 0),
      );
    }).toList();
  }

  static Money totalSpent(List<Expense> expenses, String cycleId) {
    return expenses
        .where((e) => e.cycleId == cycleId)
        .fold(Money.zero(), (sum, e) => sum + e.amount);
  }
}
