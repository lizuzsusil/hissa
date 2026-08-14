import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'repository.dart';

/// Firebase Firestore backed repository.
///
/// Reads are synchronous over locally-cached lists, kept fresh by realtime
/// listeners, so the UI can rebuild eagerly. Mutations update the local cache
/// immediately and then await the Firestore write.
///
/// Document id conventions:
///   users/{userId}                      -> global (uid or pseudo-user id)
///   spaces/{spaceId}                    -> global
///   spaceMembers/{spaceId}_{userId}
///   categories|cycles|expenses|expenseShares|settlements/{spaceId}_{id}
///
/// Space-scoped collections store a `spaceId` field so Firestore security
/// rules can enforce membership and queries stay scoped.
class FirestoreRepository implements ExpenseRepository {
  final FirebaseFirestore _db;
  final List<User> _users = [];
  final List<Space> _spaces = [];
  final List<SpaceMember> _members = [];
  final List<Cycle> _cycles = [];
  final List<Expense> _expenses = [];
  final List<ExpenseShare> _shares = [];
  final List<Settlement> _settlements = [];
  final List<Category> _categories = [];
  final List<MemberGroup> _memberGroups = [];
  final List<MemberGroupMember> _memberGroupMembers = [];
  final List<GroupRequest> _groupRequests = [];

  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, StreamSubscription<dynamic>> _userDocSubs = {};
  String? _ownUid;
  String? _currentSpaceId;
  void Function()? _onChanged;

  FirestoreRepository(this._db);

  void _notify() => _onChanged?.call();

  // ---- lifecycle ----

  /// Tears down any existing listeners, loads the current snapshot for
  /// [spaceId] (if any) and subscribes to realtime updates.
  Future<void> start({
    required String uid,
    String? spaceId,
    required void Function() onChanged,
  }) async {
    stop();
    _ownUid = uid;
    _currentSpaceId = spaceId;
    _onChanged = onChanged;

    try {
      final ownSnap = await _db.collection('users').doc(uid).get();
      if (ownSnap.exists) {
        _users.removeWhere((u) => u.id == uid);
        _users.add(User.fromJson(ownSnap.data()!));
      }
    } catch (_) {}

    _subs.add(
      _db.collection('users').doc(uid).snapshots().listen(
        (snap) {
          _users.removeWhere((u) => u.id == uid);
          if (snap.exists) _users.add(User.fromJson(snap.data()!));
          _notify();
        },
        onError: (_) {},
      ),
    );

    if (spaceId != null) {
      await _loadSpaceScope(spaceId);
      _subscribeSpace(spaceId);
    }
    _notify();
  }

  Future<void> _loadSpaceScope(String spaceId) async {
    try {
      // Kick off every independent read up-front so the space-scoped queries
      // run in parallel instead of serially (switching Spaces is much faster).
      final spaceF = _db.collection('spaces').doc(spaceId).get();
      final membersF = _db
          .collection('spaceMembers')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final categoriesF = _db
          .collection('categories')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final cyclesF = _db
          .collection('cycles')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final expensesF = _db
          .collection('expenses')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final sharesF = _db
          .collection('expenseShares')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final settlementsF = _db
          .collection('settlements')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final memberGroupsF = _db
          .collection('memberGroups')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final groupMembersF = _db
          .collection('memberGroupMembers')
          .where('spaceId', isEqualTo: spaceId)
          .get();
      final groupRequestsF = _db
          .collection('groupRequests')
          .where('spaceId', isEqualTo: spaceId)
          .get();

      final spaceSnap = await spaceF;
      _spaces.clear();
      if (spaceSnap.exists) {
        _spaces.add(Space.fromJson(spaceSnap.data()!));
      }

      final membersSnap = await membersF;
      _members
        ..clear()
        ..addAll(
          membersSnap.docs.map((d) => SpaceMember.fromJson(d.data())),
        );
      await _loadMemberUserDocs(
        membersSnap.docs.map((d) => d.data()['userId'] as String),
      );

      final categories = await categoriesF;
      _categories
        ..clear()
        ..addAll(categories.docs.map((d) => Category.fromJson(d.data())));

      final cycles = await cyclesF;
      _cycles
        ..clear()
        ..addAll(cycles.docs.map((d) => Cycle.fromJson(d.data())));

      final expenses = await expensesF;
      _expenses
        ..clear()
        ..addAll(expenses.docs.map((d) => Expense.fromJson(d.data())));

      final shares = await sharesF;
      _shares
        ..clear()
        ..addAll(shares.docs.map((d) => ExpenseShare.fromJson(d.data())));

      final settlements = await settlementsF;
      _settlements
        ..clear()
        ..addAll(settlements.docs.map((d) => Settlement.fromJson(d.data())));

      final memberGroups = await memberGroupsF;
      _memberGroups
        ..clear()
        ..addAll(memberGroups.docs.map((d) => MemberGroup.fromJson(d.data())));

      final groupMembers = await groupMembersF;
      _memberGroupMembers
        ..clear()
        ..addAll(
          groupMembers.docs.map((d) => MemberGroupMember.fromJson(d.data())),
        );

      // Populate memberIds for each MemberGroup from the loaded groupMembers
      final memberIdsByGroup = <String, List<String>>{};
      for (final m in _memberGroupMembers) {
        memberIdsByGroup
            .putIfAbsent(m.groupId, () => [])
            .add(m.userId);
      }
      for (final g in _memberGroups) {
        final ids = memberIdsByGroup[g.id] ?? [];
        final idx = _memberGroups.indexOf(g);
        if (idx >= 0) {
          _memberGroups[idx] = g.copyWith(memberIds: ids);
        }
      }

      final groupRequests = await groupRequestsF;
      _groupRequests
        ..clear()
        ..addAll(groupRequests.docs.map((d) => GroupRequest.fromJson(d.data())));
    } catch (_) {
      // Permission denied or missing data: degrade to an empty cache rather
      // than failing the whole attach flow.
    }
    _notify();
  }

  Future<void> _loadMemberUserDocs(Iterable<String> userIds) async {
    // Fetch each member profile concurrently; the user-doc reads are
    // independent of one another.
    final futures = <Future<void>>[];
    for (final id in userIds) {
      if (id == _ownUid) continue;
      futures.add(() async {
        try {
          final snap = await _db.collection('users').doc(id).get();
          _users.removeWhere((u) => u.id == id);
          if (snap.exists) _users.add(User.fromJson(snap.data()!));
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
  }

  void _subscribeSpace(String spaceId) {
    _subs.add(
      _db.collection('spaces').doc(spaceId).snapshots().listen(
        (snap) {
          if (snap.exists) {
            final s = Space.fromJson(snap.data()!);
            _upsert(_spaces, s, (x) => x.id);
          }
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('spaceMembers')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _members
            ..clear()
            ..addAll(
              snap.docs.map((d) => SpaceMember.fromJson(d.data())),
            );
          _syncMemberUserDocs(snap.docs.map((d) => d.data()['userId'] as String));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('categories')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _categories
            ..clear()
            ..addAll(snap.docs.map((d) => Category.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('cycles')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _cycles
            ..clear()
            ..addAll(snap.docs.map((d) => Cycle.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('expenses')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _expenses
            ..clear()
            ..addAll(snap.docs.map((d) => Expense.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('expenseShares')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _shares
            ..clear()
            ..addAll(snap.docs.map((d) => ExpenseShare.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('settlements')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _settlements
            ..clear()
            ..addAll(snap.docs.map((d) => Settlement.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('memberGroups')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _memberGroups
            ..clear()
            ..addAll(snap.docs.map((d) => MemberGroup.fromJson(d.data())));
          // Repopulate memberIds from current group members
          final memberIdsByGroup = <String, List<String>>{};
          for (final m in _memberGroupMembers) {
            memberIdsByGroup
                .putIfAbsent(m.groupId, () => [])
                .add(m.userId);
          }
          for (var i = 0; i < _memberGroups.length; i++) {
            final g = _memberGroups[i];
            final ids = memberIdsByGroup[g.id] ?? [];
            _memberGroups[i] = g.copyWith(memberIds: ids);
          }
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('memberGroupMembers')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _memberGroupMembers
            ..clear()
            ..addAll(
              snap.docs.map((d) => MemberGroupMember.fromJson(d.data())),
            );
          _notify();
        },
        onError: (_) {},
      ),
    );

    _subs.add(
      _db
          .collection('groupRequests')
          .where('spaceId', isEqualTo: spaceId)
          .snapshots()
          .listen(
        (snap) {
          _groupRequests
            ..clear()
            ..addAll(snap.docs.map((d) => GroupRequest.fromJson(d.data())));
          _notify();
        },
        onError: (_) {},
      ),
    );
  }

  void _syncMemberUserDocs(Iterable<String> userIds) {
    final wanted = userIds.toSet();
    _userDocSubs.removeWhere((id, sub) {
      if (wanted.contains(id)) return false;
      sub.cancel();
      _users.removeWhere((u) => u.id == id && u.id != _ownUid);
      return true;
    });
    for (final id in wanted) {
      if (id == _ownUid || _userDocSubs.containsKey(id)) continue;
      final sub = _db.collection('users').doc(id).snapshots().listen(
        (s) {
          _users.removeWhere((u) => u.id == id);
          if (s.exists) _users.add(User.fromJson(s.data()!));
          _notify();
        },
        onError: (_) {},
      );
      _userDocSubs[id] = sub;
    }
  }

  /// Cancels all active listeners and resets the caches.
  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    for (final s in _userDocSubs.values) {
      s.cancel();
    }
    _userDocSubs.clear();
    _onChanged = null;
    _users.clear();
    _spaces.clear();
    _members.clear();
    _cycles.clear();
    _expenses.clear();
    _shares.clear();
    _settlements.clear();
    _categories.clear();
    _memberGroups.clear();
    _memberGroupMembers.clear();
    _groupRequests.clear();
  }

  // ---- reads ----

  @override
  List<User> get users => List.unmodifiable(_users);

  @override
  List<Space> get spaces => List.unmodifiable(_spaces);

  @override
  List<SpaceMember> get members => List.unmodifiable(_members);

  @override
  List<Cycle> get cycles => List.unmodifiable(_cycles);

  @override
  List<Expense> get expenses => List.unmodifiable(_expenses);

  @override
  List<ExpenseShare> get shares => List.unmodifiable(_shares);

  @override
  List<Settlement> get settlements => List.unmodifiable(_settlements);

  @override
  List<Category> get categories => List.unmodifiable(_categories);

  @override
  List<MemberGroup> get memberGroups => List.unmodifiable(_memberGroups);

  @override
  List<MemberGroupMember> get memberGroupMembers =>
      List.unmodifiable(_memberGroupMembers);

  @override
  List<GroupRequest> get groupRequests => List.unmodifiable(_groupRequests);

  @override
  List<ExpenseShare> sharesForExpense(String expenseId) {
    return _shares.where((s) => s.expenseId == expenseId).toList();
  }

  @override
  List<ExpenseShare> sharesForCycle(List<Expense> expenses) {
    final ids = expenses.map((e) => e.id).toSet();
    return _shares.where((s) => ids.contains(s.expenseId)).toList();
  }

  // ---- writes ----

  @override
  Future<void> saveUser(User user) async {
    _upsert(_users, user, (u) => u.id);
    await _db.collection('users').doc(user.id).set(user.toJson());
  }

  @override
  Future<void> saveSpace(Space space) async {
    _upsert(_spaces, space, (s) => s.id);
    await _db.collection('spaces').doc(space.id).set(space.toJson());
  }

  @override
  Future<void> saveMember(SpaceMember member, [String? spaceId]) async {
    final sid = spaceId ?? _currentSpaceId;
    if (sid == null) {
      throw StateError('Cannot save a member without a space');
    }
    _upsert(_members, member, (m) => m.userId);
    await _db.collection('spaceMembers').doc('${sid}_${member.userId}').set({
      ...member.toJson(),
      'spaceId': sid,
    });
  }

  @override
  Future<void> removeMember(String userId, String spaceId) async {
    _members.removeWhere((m) => m.userId == userId);
    await _db
        .collection('spaceMembers')
        .doc('${spaceId}_$userId')
        .delete();
  }

  @override
  Future<void> saveCycle(Cycle cycle) async {
    _upsert(_cycles, cycle, (c) => c.id);
    await _db
        .collection('cycles')
        .doc('${cycle.spaceId}_${cycle.id}')
        .set(cycle.toJson());
  }

  @override
  Future<void> saveExpense(Expense expense, List<ExpenseShare> shares) async {
    final sid = expense.spaceId;
    _upsert(_expenses, expense, (e) => e.id);
    _shares.removeWhere((s) => s.expenseId == expense.id);
    _shares.addAll(shares);

    final batch = _db.batch();
    batch.set(
      _db.collection('expenses').doc('${sid}_${expense.id}'),
      expense.toJson(),
    );
    final existing = await _db
        .collection('expenseShares')
        .where('spaceId', isEqualTo: sid)
        .where('expenseId', isEqualTo: expense.id)
        .get();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    for (final s in shares) {
      batch.set(
        _db.collection('expenseShares').doc('${sid}_${s.id}'),
        {...s.toJson(), 'spaceId': sid},
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    final sid = _expenses
            .where((e) => e.id == expenseId)
            .firstOrNull
            ?.spaceId ??
        _currentSpaceId;
    _expenses.removeWhere((e) => e.id == expenseId);
    _shares.removeWhere((s) => s.expenseId == expenseId);
    if (sid == null) return;
    await _db.collection('expenses').doc('${sid}_$expenseId').delete();
    final shares = await _db
        .collection('expenseShares')
        .where('spaceId', isEqualTo: sid)
        .where('expenseId', isEqualTo: expenseId)
        .get();
    for (final d in shares.docs) {
      await d.reference.delete();
    }
  }

  @override
  Future<void> addShare(ExpenseShare share) async {
    _upsert(_shares, share, (s) => s.id);
    final sid = _expenses
        .where((e) => e.id == share.expenseId)
        .firstOrNull
        ?.spaceId;
    if (sid == null) return;
    await _db.collection('expenseShares').doc('${sid}_${share.id}').set({
      ...share.toJson(),
      'spaceId': sid,
    });
  }

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    _upsert(_settlements, settlement, (s) => s.id);
    await _db
        .collection('settlements')
        .doc('${settlement.spaceId}_${settlement.id}')
        .set(settlement.toJson());
  }

  @override
  Future<void> saveCategory(Category category) async {
    _upsert(_categories, category, (c) => c.id);
    await _db
        .collection('categories')
        .doc('${category.spaceId}_${category.id}')
        .set(category.toJson());
  }

  @override
  Future<void> saveMemberGroup(MemberGroup group) async {
    _upsert(_memberGroups, group, (g) => g.id);
    await _db
        .collection('memberGroups')
        .doc(group.id)
        .set(group.toJson());
  }

  @override
  Future<void> addGroupMember(String groupId, String userId) async {
    // Resolve the group's Space so the member row can be space-scoped, matching
    // how the security rules and space-scoped queries expect the data.
    final sid = _memberGroups
            .where((g) => g.id == groupId)
            .firstOrNull
            ?.spaceId ??
        _currentSpaceId;
    final member = MemberGroupMember(
      groupId: groupId,
      userId: userId,
      spaceId: sid,
      createdAt: DateTime.now(),
    );
    _upsert(_memberGroupMembers, member, (m) => m.id);
    await _db
        .collection('memberGroups')
        .doc(groupId)
        .update({'updatedAt': DateTime.now().toIso8601String()});
    await _db
        .collection('memberGroupMembers')
        .doc(member.id)
        .set(member.toJson());
  }

  @override
  Future<void> removeGroupMember(String groupId, String userId) async {
    _memberGroupMembers.removeWhere((m) => m.groupId == groupId && m.userId == userId);
    await _db
        .collection('memberGroups')
        .doc(groupId)
        .update({'updatedAt': DateTime.now().toIso8601String()});
    await _db
        .collection('memberGroupMembers')
        .doc('${groupId}_$userId')
        .delete();
  }

  @override
  Future<void> deleteMemberGroup(String groupId) async {
    _memberGroups.removeWhere((g) => g.id == groupId);
    _memberGroupMembers.removeWhere((m) => m.groupId == groupId);
    await _db.collection('memberGroups').doc(groupId).delete();
    final members = await _db
        .collection('memberGroupMembers')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (final d in members.docs) {
      await d.reference.delete();
    }
  }

  @override
  Future<void> saveGroupRequest(GroupRequest request) async {
    _upsert(_groupRequests, request, (r) => r.id);
    await _db
        .collection('groupRequests')
        .doc('${request.spaceId}_${request.id}')
        .set(request.toJson());
  }

  @override
  Future<void> updateGroupRequestStatus(
    String requestId,
    GroupRequestStatus status,
  ) async {
    final existing = _groupRequests.where((r) => r.id == requestId).firstOrNull;
    if (existing == null) return;
    final updated = existing.copyWith(status: status);
    _upsert(_groupRequests, updated, (r) => r.id);
    await _db
        .collection('groupRequests')
        .doc('${existing.spaceId}_$requestId')
        .update({'status': status.name});
  }

  // ---- queries ----

  @override
  Future<Space?> findSpaceByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final snap = await _db
        .collection('spaces')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Space.fromJson(snap.docs.first.data());
  }

  @override
  Future<String?> findSpaceIdForUser(String userId) async {
    final snap = await _db
        .collection('spaceMembers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['spaceId'] as String?;
  }

  @override
  Future<List<Space>> findSpacesForUser(String userId) async {
    final membershipSnap = await _db
        .collection('spaceMembers')
        .where('userId', isEqualTo: userId)
        .get();
    final ids = membershipSnap.docs
        .map((d) => d.data()['spaceId'] as String?)
        .whereType<String>()
        .toSet();
    final result = <Space>[];
    final futures = <Future<void>>[];
    for (final id in ids) {
      futures.add(() async {
        try {
          final doc = await _db.collection('spaces').doc(id).get();
          if (doc.exists) result.add(Space.fromJson(doc.data()!));
        } catch (_) {
          // Ignore spaces that cannot be read.
        }
      }());
    }
    await Future.wait(futures);
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Future<int> countMembers(String spaceId) async {
    final snap = await _db
        .collection('spaceMembers')
        .where('spaceId', isEqualTo: spaceId)
        .get();
    return snap.docs.length;
  }

  // ---- helpers ----

  static void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final idx = list.indexWhere((x) => idOf(x) == idOf(item));
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
  }
}
