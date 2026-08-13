enum CycleStatus {
  active,
  readyToSettle,
  settled,
  closed;

  String get label {
    switch (this) {
      case CycleStatus.active:
        return 'Active';
      case CycleStatus.readyToSettle:
        return 'Ready to settle';
      case CycleStatus.settled:
        return 'Settled';
      case CycleStatus.closed:
        return 'Closed';
    }
  }
}

enum SettlementStatus {
  pending,
  partiallyPaid,
  paid,
  cancelled;

  String get label {
    switch (this) {
      case SettlementStatus.pending:
        return 'Pending';
      case SettlementStatus.partiallyPaid:
        return 'Partially paid';
      case SettlementStatus.paid:
        return 'Paid';
      case SettlementStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum SplitType {
  equal,
  percentage,
  custom,
  shares;

  String get label {
    switch (this) {
      case SplitType.equal:
        return 'Equally';
      case SplitType.percentage:
        return 'By percentage';
      case SplitType.custom:
        return 'Custom amounts';
      case SplitType.shares:
        return 'By shares';
    }
  }
}

enum MemberRole {
  owner,
  admin,
  member;

  String get label {
    switch (this) {
      case MemberRole.owner:
        return 'Owner';
      case MemberRole.admin:
        return 'Admin';
      case MemberRole.member:
        return 'Member';
    }
  }
}

/// The mode of a Space (container). Stable internal values are `SPLIT` and
/// `SOLO` (see [SpaceMode.value]); the UI shows friendlier labels
/// ("Split Mode" / "Personal Mode").
enum SpaceMode {
  split('SPLIT', 'Split Mode'),
  solo('SOLO', 'Personal Mode');

  const SpaceMode(this.value, this.label);

  /// Stable internal value used for persistence and comparisons.
  final String value;

  /// User-facing label for the mode.
  final String label;
}
