import '../core/money.dart';
import '../models/models.dart';

/// A balance entry for either a Space member (USER) or a Member Group (GROUP).
class BalanceEntry {
  final String id;
  final ExpenseParticipantType type;
  final Money paid;
  final Money share;
  final Money balance;
  final Money settledOut;
  final Money settledIn;

  const BalanceEntry({
    required this.id,
    required this.type,
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

  bool get isGroup => type == ExpenseParticipantType.group;
}

class BalanceCalculator {
  /// Computes balance entries for every participant of [space] within
  /// [cycle]. A Member Group is a single financial participant: the paid
  /// amounts, shares and settlements of its members are rolled into the
  /// group's entry, and the members themselves never appear individually.
  static List<BalanceEntry> compute({
    required Space space,
    required List<SpaceMember> members,
    required List<MemberGroup> memberGroups,
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

    // Active groups and the entity each member's activity rolls into.
    final activeGroups = memberGroups.where((g) => g.isActive).toList();
    final groupByUser = <String, String>{};
    for (final g in activeGroups) {
      for (final uid in g.allUserIds) {
        groupByUser[uid] = g.id;
      }
    }
    String entityFor(String id) => groupByUser[id] ?? id;

    // Only ungrouped members surface individually; grouped members are
    // represented by their group.
    final ungroupedMembers =
        members.where((m) => !groupByUser.containsKey(m.userId)).toList();

    final paidBy = <String, int>{};
    final shareBy = <String, int>{};
    final settledOut = <String, int>{};
    final settledIn = <String, int>{};

    for (final id in [...ungroupedMembers.map((m) => m.userId), ...activeGroups.map((g) => g.id)]) {
      paidBy[id] = 0;
      shareBy[id] = 0;
      settledOut[id] = 0;
      settledIn[id] = 0;
    }

    for (final expense in expensesInCycle) {
      final key = entityFor(expense.paidByUserId);
      paidBy[key] = (paidBy[key] ?? 0) + expense.amount.paisa;
    }

    for (final share in sharesInCycle) {
      // For USER: share.userId is the key. For GROUP: share.memberGroupId is the key.
      final key = entityFor(share.participantId);
      if (key.isNotEmpty) {
        shareBy[key] = (shareBy[key] ?? 0) + share.amount.paisa;
      }
    }

    for (final settlement in settlementsInCycle) {
      // Only creditor-approved settlements reduce balances. A pending
      // request must never change what is owed, and a rejected one stays
      // fully unsettled.
      if (!settlement.status.isSettled) continue;
      final from = entityFor(settlement.fromUserId);
      final to = entityFor(settlement.toUserId);
      settledOut[from] =
          (settledOut[from] ?? 0) + settlement.amount.paisa;
      settledIn[to] =
          (settledIn[to] ?? 0) + settlement.amount.paisa;
    }

    final entries = <BalanceEntry>[];

    // Ungrouped member entries
    for (final member in ungroupedMembers) {
      final id = member.userId;
      final paid = paidBy[id] ?? 0;
      final share = shareBy[id] ?? 0;
      entries.add(BalanceEntry(
        id: id,
        type: ExpenseParticipantType.user,
        paid: Money(paid),
        share: Money(share),
        balance: Money(paid - share),
        settledOut: Money(settledOut[id] ?? 0),
        settledIn: Money(settledIn[id] ?? 0),
      ));
    }

    // Group entries
    for (final group in activeGroups) {
      final id = group.id;
      final paid = paidBy[id] ?? 0;
      final share = shareBy[id] ?? 0;
      entries.add(BalanceEntry(
        id: id,
        type: ExpenseParticipantType.group,
        paid: Money(paid),
        share: Money(share),
        balance: Money(paid - share),
        settledOut: Money(settledOut[id] ?? 0),
        settledIn: Money(settledIn[id] ?? 0),
      ));
    }

    return entries;
  }

  static Money totalSpent(List<Expense> expenses, String cycleId) {
    return expenses
        .where((e) => e.cycleId == cycleId)
        .fold(Money.zero(), (sum, e) => sum + e.amount);
  }
}

/// Legacy per-user balance info (used by existing UI until migrated).
class BalanceInfo {
  final String userId;
  final Money paid;
  final Money share;
  final Money balance;
  final Money settledOut;
  final Money settledIn;

  const BalanceInfo({
    required this.userId,
    required this.paid,
    required this.share,
    required this.balance,
    required this.settledOut,
    required this.settledIn,
  });

  Money get remaining => balance + settledOut - settledIn;

  Money get totalPaid => paid + settledOut;

  bool get isOwed => balance.isPositive;
  bool get owes => balance.isNegative;
}
