import 'package:flutter/material.dart';

import '../core/money.dart';
import 'enums.dart';

export 'enums.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;

  /// The Space this user chose to open automatically on launch, when they
  /// belong to more than one. Stored per-user in the database so the choice
  /// follows the account across devices and logins.
  final String? defaultSpaceId;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.defaultSpaceId,
    required this.createdAt,
  });

  /// Sentinel so an explicit null clears [defaultSpaceId] instead of keeping
  /// the previous value.
  static const _unset = Object();

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    Object? defaultSpaceId = _unset,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultSpaceId: identical(defaultSpaceId, _unset)
          ? this.defaultSpaceId
          : defaultSpaceId as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'defaultSpaceId': defaultSpaceId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        defaultSpaceId: json['defaultSpaceId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// The container for expenses and members in Hissa. Persisted in the
/// `spaces/{id}` Firestore collection.
class Space {
  final String id;
  String name;
  String currency;
  final String inviteCode;
  final String? createdBy;

/// The mode of this Space.
  SpaceMode mode;

  /// How the spending cycle is scheduled for Split Spaces. Legacy Spaces
  /// without an explicit value default to [CycleType.monthly].
  CycleType cycleType;

  final DateTime createdAt;

  /// Last update timestamp. Nullable because legacy records predate this
  /// field.
  DateTime? updatedAt;

  Space({
    required this.id,
    required this.name,
    required this.currency,
    required this.inviteCode,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.mode = SpaceMode.split,
    this.cycleType = CycleType.monthly,
  });

  Space copyWith({
    String? name,
    String? currency,
    SpaceMode? mode,
    CycleType? cycleType,
    String? createdBy,
  }) {
    return Space(
      id: id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      inviteCode: inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      mode: mode ?? this.mode,
      cycleType: cycleType ?? this.cycleType,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'inviteCode': inviteCode,
        'createdBy': createdBy,
        'mode': mode.value,
        'cycleType': cycleType.value,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Space.fromJson(Map<String, dynamic> json) => Space(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        inviteCode: json['inviteCode'] as String,
        createdBy: json['createdBy'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
        mode: _parseMode(json['mode']),
        cycleType: _parseCycleType(json['cycleType']),
      );

  static SpaceMode _parseMode(Object? value) {
    if (value is String) {
      for (final m in SpaceMode.values) {
        if (m.value == value) return m;
      }
    }
    return SpaceMode.split;
  }

  static CycleType _parseCycleType(Object? value) {
    if (value is String) {
      for (final t in CycleType.values) {
        if (t.value == value) return t;
      }
    }
    return CycleType.monthly;
  }
}

/// A member of a [Space]. Persisted in the `spaceMembers/{spaceId}_{userId}`
/// collection; a `spaceId` field scopes the membership.
class SpaceMember {
  final String userId;
  String name;
  final MemberRole role;
  final DateTime joinedAt;
  final String? avatarUrl;

  /// The Space this membership belongs to. Populated from the persisted
  /// `spaceId` field when loaded from Firestore.
  final String? spaceId;
  final MembershipStatus status;

  /// Set when this member was added through an email invite (rather than
  /// directly joining). The backend emails [invitedEmail] to notify them.
  final String? invitedEmail;

  /// The Space member who sent the email invite.
  final String? invitedByUserId;

  SpaceMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
    this.spaceId,
    this.status = MembershipStatus.active,
    this.invitedEmail,
    this.invitedByUserId,
  });

  /// Composite membership id, matching the Firestore doc convention
  /// `${spaceId}_${userId}` (or just [userId] when [spaceId] is unknown).
  String get id => spaceId == null ? userId : '${spaceId}_$userId';

  SpaceMember copyWith({
    String? name,
    MemberRole? role,
    MembershipStatus? status,
    String? avatarUrl,
    String? invitedEmail,
    String? invitedByUserId,
  }) {
    return SpaceMember(
      userId: userId,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      spaceId: spaceId,
      status: status ?? this.status,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      invitedByUserId: invitedByUserId ?? this.invitedByUserId,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
        'avatarUrl': avatarUrl,
        'spaceId': spaceId,
        'status': status.name,
        'invitedEmail': invitedEmail,
        'invitedByUserId': invitedByUserId,
      };

  factory SpaceMember.fromJson(Map<String, dynamic> json) => SpaceMember(
        userId: json['userId'] as String,
        name: json['name'] as String,
        role: MemberRole.values.byName(json['role'] as String),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        avatarUrl: json['avatarUrl'] as String?,
        spaceId: json['spaceId'] as String?,
        status: _parseStatus(json['status']),
        invitedEmail: json['invitedEmail'] as String?,
        invitedByUserId: json['invitedByUserId'] as String?,
      );

  static MembershipStatus _parseStatus(Object? value) {
    if (value is String) {
      for (final s in MembershipStatus.values) {
        if (s.name == value) return s;
      }
    }
    return MembershipStatus.active;
  }
}

class Category {
  final String id;
  final String spaceId;
  final String name;
  final int? iconCodePoint;
  final int? colorValue;
  final bool isDefault;

  Category({
    required this.id,
    required this.spaceId,
    required this.name,
    this.iconCodePoint,
    this.colorValue,
    required this.isDefault,
  });

  factory Category.preset({
    required String id,
    required String spaceId,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    return Category(
      id: id,
      spaceId: spaceId,
      name: name,
      iconCodePoint: icon.codePoint,
      colorValue: color.toARGB32(),
      isDefault: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'isDefault': isDefault,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        name: json['name'] as String,
        iconCodePoint: json['iconCodePoint'] as int?,
        colorValue: json['colorValue'] as int?,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

class Cycle {
  final String id;
  final String spaceId;
  String name;
  final DateTime startDate;
  DateTime endDate;
  CycleStatus status;
  DateTime? closedAt;

  Cycle({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.closedAt,
  });

  Cycle copyWith({
    String? name,
    DateTime? endDate,
    CycleStatus? status,
    DateTime? closedAt,
  }) {
    return Cycle(
      id: id,
      spaceId: spaceId,
      name: name ?? this.name,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': status.name,
        'closedAt': closedAt?.toIso8601String(),
      };

  factory Cycle.fromJson(Map<String, dynamic> json) => Cycle(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        name: json['name'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        status: CycleStatus.values.byName(json['status'] as String),
        closedAt: json['closedAt'] == null
            ? null
            : DateTime.parse(json['closedAt'] as String),
      );
}

class Expense {
  final String id;
  final String spaceId;
  final String? cycleId;
  final String paidByUserId;
  final String? createdBy;
  final Money amount;
  final String? categoryId;
  final String? description;
  final DateTime date;
  final String? note;
  final String? receiptUrl;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Participant groups scoped to this expense (Phase 6). A group makes
  /// several Space members act as a single split party; the underlying user
  /// identities are always preserved in [ExpenseShare] rows.
  final List<ParticipantGroup> participantGroups;

  Expense({
    required this.id,
    required this.spaceId,
    required this.cycleId,
    required this.paidByUserId,
    this.createdBy,
    required this.amount,
    this.categoryId,
    this.description,
    required this.date,
    this.note,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    this.participantGroups = const [],
  });

  Expense copyWith({
    String? paidByUserId,
    String? createdBy,
    Money? amount,
    String? categoryId,
    String? description,
    DateTime? date,
    String? note,
    String? receiptUrl,
    List<ParticipantGroup>? participantGroups,
  }) {
    return Expense(
      id: id,
      spaceId: spaceId,
      cycleId: cycleId,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      createdBy: createdBy ?? this.createdBy,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      date: date ?? this.date,
      note: note ?? this.note,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      participantGroups: participantGroups ?? this.participantGroups,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'cycleId': cycleId,
        'paidByUserId': paidByUserId,
        'createdBy': createdBy,
        'amountPaisa': amount.paisa,
        'categoryId': categoryId,
        'description': description,
        'date': date.toIso8601String(),
        'note': note,
        'receiptUrl': receiptUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'participantGroups': participantGroups.map((g) => g.toJson()).toList(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        cycleId: json['cycleId'] as String?,
        paidByUserId: json['paidByUserId'] as String,
        createdBy: json['createdBy'] as String?,
        amount: Money(json['amountPaisa'] as int),
        categoryId: json['categoryId'] as String?,
        description: json['description'] as String?,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        receiptUrl: json['receiptUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        participantGroups: (json['participantGroups'] as List? ?? const [])
            .map((g) => ParticipantGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

/// A group of Space members that acts as a single split party for one
/// expense (Phase 6). Groups are scoped to an expense and never alter Space
/// membership. The underlying user identities live in [ExpenseShare] rows, so
/// the group stays auditable historically.
class ParticipantGroup {
  final String id;
  final String expenseId;
  final String name;
  final List<String> userIds;

  /// Party-level split configuration for this group, used to restore the form
  /// when editing. The group's share is always distributed equally between its
  /// members (MVP rule), so only the party-level value needs to be stored.
  final double? percentage;
  final int? shares;
  final int? customAmountPaisa;

  const ParticipantGroup({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.userIds,
    this.percentage,
    this.shares,
    this.customAmountPaisa,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'name': name,
        'userIds': userIds,
        'percentage': percentage,
        'shares': shares,
        'customAmountPaisa': customAmountPaisa,
      };

  factory ParticipantGroup.fromJson(Map<String, dynamic> json) =>
      ParticipantGroup(
        id: json['id'] as String,
        expenseId: json['expenseId'] as String,
        name: json['name'] as String,
        userIds: (json['userIds'] as List).cast<String>(),
        percentage: (json['percentage'] as num?)?.toDouble(),
        shares: json['shares'] as int?,
        customAmountPaisa: json['customAmountPaisa'] as int?,
      );
}

class ExpenseShare {
  final String id;
  final String expenseId;

  /// The participant this share belongs to. Nullable for backwards compatibility
  /// with old expenses that always had a userId.
  final String? userId;

  final Money amount;
  final double? percentage;
  final int? shares;

  /// The entity type of this participant. USER = individual member, GROUP = Member Group.
  /// Null defaults to USER for backward compatibility with pre-Phase-2 expenses.
  final ExpenseParticipantType? participantType;

  /// For GROUP participants: the persistent MemberGroup id.
  final String? memberGroupId;

  /// For GROUP participants: snapshot of the group's membership at expense creation.
  /// Keeps historical expenses auditable regardless of later group changes.
  final GroupSnapshot? groupSnapshot;

  /// Legacy Phase-6 field: the expense-scoped participant group id. Used to
  /// interpret pre-Phase-2 grouped expenses where shares were divided among members.
  final String? expenseGroupId;

  ExpenseShare({
    required this.id,
    required this.expenseId,
    this.userId,
    required this.amount,
    this.percentage,
    this.shares,
    this.participantType,
    this.memberGroupId,
    this.groupSnapshot,
    this.expenseGroupId,
  });

  /// Convenience: true when this share represents a persistent Member Group.
  bool get isGroup => participantType == ExpenseParticipantType.group;

  /// The display id for this share's participant: userId for USER, memberGroupId for GROUP.
  String get participantId => memberGroupId ?? userId ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'userId': userId,
        'amountPaisa': amount.paisa,
        'percentage': percentage,
        'shares': shares,
        'participantType': participantType?.value,
        'memberGroupId': memberGroupId,
        'groupSnapshot': groupSnapshot?.toJson(),
        'expenseGroupId': expenseGroupId,
      };

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    final participantType = ExpenseParticipantType.parse(json['participantType']);
    // Backward compat: if participantType missing but expenseGroupId present, it's
    // a legacy Phase-6 grouped expense (shares divided among members).
    final legacyGroupId = json['expenseGroupId'] as String?;
    return ExpenseShare(
      id: json['id'] as String,
      expenseId: json['expenseId'] as String,
      // Legacy expenses always have userId; new group participants have null userId.
      userId: json['userId'] as String?,
      amount: Money(json['amountPaisa'] as int),
      percentage: (json['percentage'] as num?)?.toDouble(),
      shares: json['shares'] as int?,
      participantType: participantType,
      memberGroupId: json['memberGroupId'] as String?,
      groupSnapshot: json['groupSnapshot'] != null
          ? GroupSnapshot.fromJson(json['groupSnapshot'] as Map<String, dynamic>)
          : null,
      expenseGroupId: legacyGroupId,
    );
  }
}

class Settlement {
  final String id;
  final String spaceId;
  final String cycleId;
  final String fromUserId;
  final String toUserId;
  final Money amount;
  final String currency;
  final String paymentMethod;
  final DateTime date;
  final String? note;
  final SettlementStatus status;
  final DateTime createdAt;

  Settlement({
    required this.id,
    required this.spaceId,
    required this.cycleId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.date,
    this.note,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'cycleId': cycleId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amountPaisa': amount.paisa,
        'currency': currency,
        'paymentMethod': paymentMethod,
        'date': date.toIso8601String(),
        'note': note,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        cycleId: json['cycleId'] as String,
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amount: Money(json['amountPaisa'] as int),
        currency: json['currency'] as String,
        paymentMethod: json['paymentMethod'] as String,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        status: SettlementStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A persistent Member Group inside a Split Space (Phase 1).
///
/// A Member Group is a reusable relationship where one Space member (the
/// owner) manages one or more other Space members. The group itself is treated
/// as a single financial participant when splitting an expense: its share is
/// never divided between the users inside it.
///
/// Persisted in the `memberGroups/{id}` Firestore collection. The owner is the
/// group's creator and the only member allowed to modify it.
class MemberGroup {
  final String id;
  final String spaceId;
  final String ownerUserId;

  /// Display name, e.g. "{Owner}'s Group". Derived from the owner at creation
  /// but stored so historical expenses stay readable if the owner leaves.
  final String name;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The member user IDs in this group (excluding the owner).
  /// Populated after loading from Firestore by joining with memberGroupMembers.
  final List<String> memberIds;

  const MemberGroup({
    required this.id,
    required this.spaceId,
    required this.ownerUserId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.memberIds = const [],
  });

  MemberGroup copyWith({
    String? name,
    bool? isActive,
    DateTime? updatedAt,
    List<String>? memberIds,
  }) {
    return MemberGroup(
      id: id,
      spaceId: spaceId,
      ownerUserId: ownerUserId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      memberIds: memberIds ?? this.memberIds,
    );
  }

  /// All user IDs represented by this group (owner + members).
  List<String> get allUserIds => [ownerUserId, ...memberIds];

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'ownerUserId': ownerUserId,
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemberGroup.fromJson(Map<String, dynamic> json) => MemberGroup(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        ownerUserId: json['ownerUserId'] as String,
        name: json['name'] as String,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        memberIds: (json['memberIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// A member of a [MemberGroup] (Phase 1). The owner is implied by
/// [MemberGroup.ownerUserId] and never stored as a row.
///
/// Persisted in the `memberGroupMembers/{id}` Firestore collection with the
/// composite id `${groupId}_${userId}`.
class MemberGroupMember {
  final String groupId;
  final String userId;

  /// The Space this group membership belongs to. Persisted so Firestore
  /// security rules and space-scoped queries can resolve it.
  final String? spaceId;

  final DateTime createdAt;

  const MemberGroupMember({
    required this.groupId,
    required this.userId,
    this.spaceId,
    required this.createdAt,
  });

  /// Composite membership id, matching the Firestore doc convention
  /// `${groupId}_${userId}`.
  String get id => '${groupId}_$userId';

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'userId': userId,
        'spaceId': spaceId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MemberGroupMember.fromJson(Map<String, dynamic> json) =>
      MemberGroupMember(
        groupId: json['groupId'] as String,
        userId: json['userId'] as String,
        spaceId: json['spaceId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A non-owner's request for the Space owner to create a Member Group
/// involving specific Space members (Rule 4 / Rule 5). The requester becomes
/// the group's owner when the request is approved.
///
/// Persisted in the `groupRequests/{id}` Firestore collection.
class GroupRequest {
  final String id;
  final String spaceId;
  final String requesterUserId;
  final List<String> memberUserIds;

  /// The users the requester wants in their group. The requester is the owner
  /// and is never listed here; these are the other members to group.
  final GroupRequestStatus status;
  final DateTime createdAt;

  const GroupRequest({
    required this.id,
    required this.spaceId,
    required this.requesterUserId,
    required this.memberUserIds,
    this.status = GroupRequestStatus.pending,
    required this.createdAt,
  });

  GroupRequest copyWith({GroupRequestStatus? status}) {
    return GroupRequest(
      id: id,
      spaceId: spaceId,
      requesterUserId: requesterUserId,
      memberUserIds: memberUserIds,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'requesterUserId': requesterUserId,
        'memberUserIds': memberUserIds,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GroupRequest.fromJson(Map<String, dynamic> json) => GroupRequest(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        requesterUserId: json['requesterUserId'] as String,
        memberUserIds:
            (json['memberUserIds'] as List).cast<String>().toList(),
        status: GroupRequestStatus.values.byName(
          json['status'] as String? ?? GroupRequestStatus.pending.name,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A user's request to join a Space with an invite code. Mirrors the Member
/// Group request lifecycle: joining is never immediate — the Space owner must
/// approve (or reject) the request, and the requester stays in a pending state
/// until a decision is made.
///
/// Persisted in the `spaceJoinRequests/{spaceId}_{id}` Firestore collection.
class SpaceJoinRequest {
  final String id;
  final String spaceId;
  final String requesterUserId;

  /// The requester's display name at submission time, used by the owner to
  /// decide and by the backend email copy.
  final String requesterName;
  final SpaceJoinRequestStatus status;
  final DateTime createdAt;

  const SpaceJoinRequest({
    required this.id,
    required this.spaceId,
    required this.requesterUserId,
    required this.requesterName,
    this.status = SpaceJoinRequestStatus.pending,
    required this.createdAt,
  });

  SpaceJoinRequest copyWith({SpaceJoinRequestStatus? status}) {
    return SpaceJoinRequest(
      id: id,
      spaceId: spaceId,
      requesterUserId: requesterUserId,
      requesterName: requesterName,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'requesterUserId': requesterUserId,
        'requesterName': requesterName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SpaceJoinRequest.fromJson(Map<String, dynamic> json) =>
      SpaceJoinRequest(
        id: json['id'] as String,
        spaceId: json['spaceId'] as String,
        requesterUserId: json['requesterUserId'] as String,
        requesterName: json['requesterName'] as String? ?? 'A member',
        status: SpaceJoinRequestStatus.values.byName(
          json['status'] as String? ?? SpaceJoinRequestStatus.pending.name,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Immutable snapshot of a Member Group's membership at the time an expense
/// used it as a participant (Phase 2). Keeps historical expenses auditable and
/// independent from the group's current configuration.
class GroupSnapshot {
  final String groupId;
  final String ownerUserId;
  final List<String> memberUserIds;

  const GroupSnapshot({
    required this.groupId,
    required this.ownerUserId,
    required this.memberUserIds,
  });

  /// All users represented by the group (owner + members).
  List<String> get allUserIds => [ownerUserId, ...memberUserIds];

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'ownerUserId': ownerUserId,
        'memberUserIds': memberUserIds,
      };

  factory GroupSnapshot.fromJson(Map<String, dynamic> json) => GroupSnapshot(
        groupId: json['groupId'] as String,
        ownerUserId: json['ownerUserId'] as String,
        memberUserIds: (json['memberUserIds'] as List).cast<String>(),
      );
}

/// A notification that a user has received, scoped to their [userId] and
/// optionally tied to a [spaceId]. Created by the actor's client via the
/// notification inbox after a domain event (expense, settlement, join
/// request, group request, etc.).
///
/// The [id] is deterministic: `{userId}_{eventKey}` for dedupe. The [type]
/// determines the deep-link target and localized message body.
class AppNotification {
  final String id;
  final String userId; // recipient
  final String? spaceId;
  final NotificationType type;
  final String eventKey; // domain doc id (expenseId, settlementId, requestId, etc.)
  final String actorUserId;
  final String actorName;
  final DateTime createdAt;
  final Map<String, dynamic> extra; // spaceId, expenseId, settlementId, requestId...

  AppNotification({
    required this.id,
    required this.userId,
    this.spaceId,
    required this.type,
    required this.eventKey,
    required this.actorUserId,
    required this.actorName,
    required this.createdAt,
    this.extra = const {},
  });

  String get displayActor => actorName.isNotEmpty ? actorName : 'A member';

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'spaceId': spaceId,
        'type': type.name,
        'eventKey': eventKey,
        'actorUserId': actorUserId,
        'actorName': actorName,
        'createdAt': createdAt.toIso8601String(),
        'extra': extra,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        userId: json['userId'] as String,
        spaceId: json['spaceId'] as String?,
        type: NotificationType.values.byName(json['type'] as String),
        eventKey: json['eventKey'] as String,
        actorUserId: json['actorUserId'] as String,
        actorName: json['actorName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        extra: json['extra'] as Map<String, dynamic>,
      );
}
