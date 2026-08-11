import '../core/money.dart';

/// A suggested money transfer between two members.
class SettlementProposal {
  final String fromUserId;
  final String toUserId;
  final Money amount;

  const SettlementProposal({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

/// Produces the minimal set of transactions to settle outstanding
/// balances. A greedy matching of the largest debtor to the largest
/// creditor guarantees at most n-1 transactions and avoids cycles such
/// as "A → B → C → A".
class SettlementCalculator {
  /// [remainingByUser] maps a user id to their *remaining* outstanding
  /// amount (negative = owes, positive = should receive).
  static List<SettlementProposal> minimize(Map<String, Money> remainingByUser) {
    final debtors = <({String id, int paisa})>[];
    final creditors = <({String id, int paisa})>[];

    remainingByUser.forEach((id, money) {
      if (money.paisa < 0) {
        debtors.add((id: id, paisa: -money.paisa));
      } else if (money.paisa > 0) {
        creditors.add((id: id, paisa: money.paisa));
      }
    });

    debtors.sort((a, b) => b.paisa.compareTo(a.paisa));
    creditors.sort((a, b) => b.paisa.compareTo(a.paisa));

    final proposals = <SettlementProposal>[];
    var d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = debtor.paisa < creditor.paisa
          ? debtor.paisa
          : creditor.paisa;

      if (amount > 0) {
        proposals.add(SettlementProposal(
          fromUserId: debtor.id,
          toUserId: creditor.id,
          amount: Money(amount),
        ));
      }

      if (debtor.paisa < creditor.paisa) {
        creditors[c] = (id: creditor.id, paisa: creditor.paisa - amount);
        d++;
      } else if (debtor.paisa > creditor.paisa) {
        debtors[d] = (id: debtor.id, paisa: debtor.paisa - amount);
        c++;
      } else {
        // Exactly equal: both sides clear.
        d++;
        c++;
      }
    }

    return proposals;
  }
}
