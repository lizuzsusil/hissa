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

/// How the spending cycle of a Split Space is scheduled.
///
/// [CycleType.monthly] spaces always track the running calendar month: the
/// cycle starts on the 1st and closes at the end of the month. [CycleType
/// .custom] spaces keep a single open-ended cycle that the owner closes and
/// reopens manually, so it may span any length of time.
enum CycleType {
  monthly('MONTHLY', 'Monthly'),
  custom('CUSTOM', 'Custom');

  const CycleType(this.value, this.label);

  /// Stable internal value used for persistence.
  final String value;

  /// User-facing label for the cycle type.
  final String label;
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

/// The membership status of a [SpaceMember]. Legacy memberships default to
/// [MembershipStatus.active].
enum MembershipStatus {
  active,
  invited,
  removed;

  String get label {
    switch (this) {
      case MembershipStatus.active:
        return 'Active';
      case MembershipStatus.invited:
        return 'Invited';
      case MembershipStatus.removed:
        return 'Removed';
    }
  }
}

/// The mode of a Space (container). Stable internal values are `SPLIT` and
/// `PERSONAL` (see [SpaceMode.value]); the UI shows friendlier labels
/// ("Split Mode" / "Personal Mode").
enum SpaceMode {
  split('SPLIT', 'Split Mode'),
  personal('PERSONAL', 'Personal Mode');

  const SpaceMode(this.value, this.label);

  /// Stable internal value used for persistence and comparisons.
  final String value;

  /// User-facing label for the mode.
  final String label;
}

/// The entity a single expense participant (and its share) refers to. A
/// participant is either an individual Space member ([ExpenseParticipantType
/// .user]) or a persistent Member Group ([ExpenseParticipantType.group]).
///
/// A Member Group always counts as exactly one financial participant: its
/// share is never divided between the users inside it.
enum ExpenseParticipantType {
  user('USER'),
  group('GROUP');

  const ExpenseParticipantType(this.value);

  /// Stable internal value used for persistence.
  final String value;

  static ExpenseParticipantType parse(Object? value) {
    if (value is String) {
      for (final t in values) {
        if (t.value == value) return t;
      }
    }
    return ExpenseParticipantType.user;
  }
}

/// The lifecycle of a non-owner's Member Group creation request. A non-owner
/// requests a group involving specific Space members; the Space owner may then
/// approve it (which creates the group) or reject it.
enum GroupRequestStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case GroupRequestStatus.pending:
        return 'Pending';
      case GroupRequestStatus.approved:
        return 'Approved';
      case GroupRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

/// The lifecycle of a Space join request submitted with an invite code.
/// Joining is never immediate: the Space owner approves or rejects the request
/// and the requester stays in a pending state until then.
enum SpaceJoinRequestStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case SpaceJoinRequestStatus.pending:
        return 'Pending';
      case SpaceJoinRequestStatus.approved:
        return 'Approved';
      case SpaceJoinRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

enum NotificationType {
  expenseAdded,
  expenseUpdated,
  settlementRecorded,
  spaceInvited,
  spaceJoinRequested,
  spaceJoinApproved,
  spaceJoinRejected,
  groupRequested,
  groupApproved,
  groupRejected;

  String get l10nKey {
    switch (this) {
      case NotificationType.expenseAdded:
        return 'notificationExpenseAdded';
      case NotificationType.expenseUpdated:
        return 'notificationExpenseUpdated';
      case NotificationType.settlementRecorded:
        return 'notificationSettlementRecorded';
      case NotificationType.spaceInvited:
        return 'notificationSpaceInvited';
      case NotificationType.spaceJoinRequested:
        return 'notificationSpaceJoinRequested';
      case NotificationType.spaceJoinApproved:
        return 'notificationSpaceJoinApproved';
      case NotificationType.spaceJoinRejected:
        return 'notificationSpaceJoinRejected';
      case NotificationType.groupRequested:
        return 'notificationGroupRequested';
      case NotificationType.groupApproved:
        return 'notificationGroupApproved';
      case NotificationType.groupRejected:
        return 'notificationGroupRejected';
    }
  }
}
