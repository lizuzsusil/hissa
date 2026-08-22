import '../core/money.dart';
import '../models/models.dart';
import 'splits.dart';

/// A balance entry for either a Space member (USER) or a Member Group (GROUP).
class BalanceEntry {
  final String id;
  final ExpenseParticipantType type;
  final Money paid;
  final Money share;
  final Money balance;

  /// Hissa income this entity physically received (it holds the
  /// hissa's cash, which reduces its effective contribution).
  final Money incomeReceived;

  /// This entity's split of the hissa income (its benefit).
  final Money incomeShare;

  final Money settledOut;
  final Money settledIn;

  const BalanceEntry({
    required this.id,
    required this.type,
    required this.paid,
    required this.share,
    required this.balance,
    this.incomeReceived = const Money.zero(),
    this.incomeShare = const Money.zero(),
    required this.settledOut,
    required this.settledIn,
  });

  /// Remaining outstanding after recorded settlements and hissa income:
  /// income lowers everyone's share by their split of it, and lowers what
  /// the recipient still effectively contributed (they hold the cash).
  Money get remaining =>
      balance + settledOut - settledIn + incomeShare - incomeReceived;

  Money get totalPaid => paid + settledOut;

  bool get isOwed => remaining.isPositive;
  bool get owes => remaining.isNegative;

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
    required List<HissaIncome> incomes,
  }) {
    final expensesInCycle = expenses
        .where((e) => e.cycleId == cycle.id)
        .toList();
    final sharesInCycle = shares
        .where((s) => expensesInCycle.any((e) => e.id == s.expenseId))
        .toList();
    final settlementsInCycle = settlements
        .where((s) => s.cycleId == cycle.id)
        .toList();
    final incomesInCycle = incomes.where((i) => i.cycleId == cycle.id).toList();

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
    final ungroupedMembers = members
        .where((m) => !groupByUser.containsKey(m.userId))
        .toList();

    final paidBy = <String, int>{};
    final shareBy = <String, int>{};
    final incomeReceivedBy = <String, int>{};
    final incomeShareBy = <String, int>{};
    final settledOut = <String, int>{};
    final settledIn = <String, int>{};

    for (final id in [
      ...ungroupedMembers.map((m) => m.userId),
      ...activeGroups.map((g) => g.id),
    ]) {
      paidBy[id] = 0;
      shareBy[id] = 0;
      incomeReceivedBy[id] = 0;
      incomeShareBy[id] = 0;
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
      settledOut[from] = (settledOut[from] ?? 0) + settlement.amount.paisa;
      settledIn[to] = (settledIn[to] ?? 0) + settlement.amount.paisa;
    }

    for (final income in incomesInCycle) {
      // The recipient holds the household's cash: their effective
      // contribution towards household costs drops by what they received.
      // The receiver may be a member OR a Member Group (a financial
      // participant), so map it through entityFor like everything else.
      final receiverKey = entityFor(income.receivedByUserId);
      incomeReceivedBy[receiverKey] =
          (incomeReceivedBy[receiverKey] ?? 0) + income.amount.paisa;

      // The benefit is distributed across the participants with the SAME
      // split calculator used for expenses — equal, percentage, custom or
      // shares all behave exactly like an expense split. Participant ids may
      // reference Member Groups: those become single group parties whose
      // share is never divided internally, exactly like expense splits.
      final activeGroupIds = {for (final g in activeGroups) g.id};
      final groupNameById = {
        for (final g in activeGroups) g.id: g.name,
      };
      final benefitShares = SplitCalculator.buildGrouped(
        expenseId: income.id,
        amount: income.amount,
        parties: [
          for (final id in income.participantIds)
            activeGroupIds.contains(id)
                ? SplitParty.group(
                    groupId: id,
                    name: groupNameById[id] ?? id,
                    userIds: const [],
                  )
                : SplitParty.individual(id),
        ],
        type: income.splitType,
        percentages: income.percentages,
        customAmounts: income.customAmounts,
        shareUnits: income.shareUnits,
      );
      for (final s in benefitShares) {
        final key = entityFor(s.participantId);
        if (key.isEmpty) continue;
        incomeShareBy[key] = (incomeShareBy[key] ?? 0) + s.amount.paisa;
      }
    }

    final entries = <BalanceEntry>[];

    // Ungrouped member entries
    for (final member in ungroupedMembers) {
      final id = member.userId;
      final paid = paidBy[id] ?? 0;
      final share = shareBy[id] ?? 0;
      entries.add(
        BalanceEntry(
          id: id,
          type: ExpenseParticipantType.user,
          paid: Money(paid),
          share: Money(share),
          balance: Money(paid - share),
          incomeReceived: Money(incomeReceivedBy[id] ?? 0),
          incomeShare: Money(incomeShareBy[id] ?? 0),
          settledOut: Money(settledOut[id] ?? 0),
          settledIn: Money(settledIn[id] ?? 0),
        ),
      );
    }

    // Group entries
    for (final group in activeGroups) {
      final id = group.id;
      final paid = paidBy[id] ?? 0;
      final share = shareBy[id] ?? 0;
      entries.add(
        BalanceEntry(
          id: id,
          type: ExpenseParticipantType.group,
          paid: Money(paid),
          share: Money(share),
          balance: Money(paid - share),
          incomeReceived: Money(incomeReceivedBy[id] ?? 0),
          incomeShare: Money(incomeShareBy[id] ?? 0),
          settledOut: Money(settledOut[id] ?? 0),
          settledIn: Money(settledIn[id] ?? 0),
        ),
      );
    }

    return entries;
  }

  static Money totalSpent(List<Expense> expenses, String cycleId) {
    return expenses
        .where((e) => e.cycleId == cycleId)
        .fold(Money.zero(), (sum, e) => sum + e.amount);
  }

  /// Total hissa income recorded in [cycleId].
  static Money totalIncome(List<HissaIncome> incomes, String cycleId) {
    return incomes
        .where((i) => i.cycleId == cycleId)
        .fold(Money.zero(), (sum, i) => sum + i.amount);
  }
}

/// Legacy per-user balance info (used by existing UI until migrated).
class BalanceInfo {
  final String userId;
  final Money paid;
  final Money share;
  final Money balance;

  /// Hissa income this user received / benefits from (see [BalanceEntry]).
  final Money incomeReceived;
  final Money incomeShare;

  final Money settledOut;
  final Money settledIn;

  const BalanceInfo({
    required this.userId,
    required this.paid,
    required this.share,
    required this.balance,
    this.incomeReceived = const Money.zero(),
    this.incomeShare = const Money.zero(),
    required this.settledOut,
    required this.settledIn,
  });

  Money get remaining =>
      balance + settledOut - settledIn + incomeShare - incomeReceived;

  Money get totalPaid => paid + settledOut;

  bool get isOwed => remaining.isPositive;
  bool get owes => remaining.isNegative;
}
