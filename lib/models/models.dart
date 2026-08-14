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
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
  });

  User copyWith({String? name, String? email, String? phone, String? avatarUrl}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
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
  });

  Space copyWith({
    String? name,
    String? currency,
    SpaceMode? mode,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'inviteCode': inviteCode,
        'createdBy': createdBy,
        'mode': mode.value,
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
      );

  static SpaceMode _parseMode(Object? value) {
    if (value is String) {
      for (final m in SpaceMode.values) {
        if (m.value == value) return m;
      }
    }
    return SpaceMode.split;
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

  SpaceMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
    this.spaceId,
    this.status = MembershipStatus.active,
  });

  /// Composite membership id, matching the Firestore doc convention
  /// `${spaceId}_${userId}` (or just [userId] when [spaceId] is unknown).
  String get id => spaceId == null ? userId : '${spaceId}_$userId';

  SpaceMember copyWith({
    String? name,
    MemberRole? role,
    MembershipStatus? status,
  }) {
    return SpaceMember(
      userId: userId,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt,
      avatarUrl: avatarUrl,
      spaceId: spaceId,
      status: status ?? this.status,
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
      };

  factory SpaceMember.fromJson(Map<String, dynamic> json) => SpaceMember(
        userId: json['userId'] as String,
        name: json['name'] as String,
        role: MemberRole.values.byName(json['role'] as String),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        avatarUrl: json['avatarUrl'] as String?,
        spaceId: json['spaceId'] as String?,
        status: _parseStatus(json['status']),
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
  final String userId;
  final Money amount;
  final double? percentage;
  final int? shares;

  /// The participant group this share belongs to (Phase 6), or null when the
  /// user participates on their own. Group member shares always preserve the
  /// underlying user identity via [userId].
  final String? groupId;

  ExpenseShare({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amount,
    this.percentage,
    this.shares,
    this.groupId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'userId': userId,
        'amountPaisa': amount.paisa,
        'percentage': percentage,
        'shares': shares,
        'groupId': groupId,
      };

  factory ExpenseShare.fromJson(Map<String, dynamic> json) => ExpenseShare(
        id: json['id'] as String,
        expenseId: json['expenseId'] as String,
        userId: json['userId'] as String,
        amount: Money(json['amountPaisa'] as int),
        percentage: (json['percentage'] as num?)?.toDouble(),
        shares: json['shares'] as int?,
        groupId: json['groupId'] as String?,
      );
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
