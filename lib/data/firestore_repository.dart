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
///   households/{spaceId}                -> global (legacy collection name)
///   householdMembers/{spaceId}_{userId}
///   categories|cycles|expenses|expenseShares|settlements/{spaceId}_{id}
///
/// Space-scoped collections store a `householdId` field so Firestore
/// security rules can enforce membership and queries stay scoped. The legacy
/// collection and field names are intentionally preserved so pre-existing
/// Split Mode records remain readable without a migration.
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
      final spaceSnap =
          await _db.collection('households').doc(spaceId).get();
      _spaces.clear();
      if (spaceSnap.exists) {
        _spaces.add(Space.fromJson(spaceSnap.data()!));
      }

      final membersSnap = await _db
          .collection('householdMembers')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _members
        ..clear()
        ..addAll(
          membersSnap.docs.map((d) => SpaceMember.fromJson(d.data())),
        );
      await _loadMemberUserDocs(
        membersSnap.docs.map((d) => d.data()['userId'] as String),
      );

      final categories = await _db
          .collection('categories')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _categories
        ..clear()
        ..addAll(categories.docs.map((d) => Category.fromJson(d.data())));

      final cycles = await _db
          .collection('cycles')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _cycles
        ..clear()
        ..addAll(cycles.docs.map((d) => Cycle.fromJson(d.data())));

      final expenses = await _db
          .collection('expenses')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _expenses
        ..clear()
        ..addAll(expenses.docs.map((d) => Expense.fromJson(d.data())));

      final shares = await _db
          .collection('expenseShares')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _shares
        ..clear()
        ..addAll(shares.docs.map((d) => ExpenseShare.fromJson(d.data())));

      final settlements = await _db
          .collection('settlements')
          .where('householdId', isEqualTo: spaceId)
          .get();
      _settlements
        ..clear()
        ..addAll(settlements.docs.map((d) => Settlement.fromJson(d.data())));
    } catch (_) {
      // Permission denied or missing data: degrade to an empty cache rather
      // than failing the whole attach flow.
    }
    _notify();
  }

  Future<void> _loadMemberUserDocs(Iterable<String> userIds) async {
    for (final id in userIds) {
      if (id == _ownUid) continue;
      try {
        final snap = await _db.collection('users').doc(id).get();
        _users.removeWhere((u) => u.id == id);
        if (snap.exists) _users.add(User.fromJson(snap.data()!));
      } catch (_) {}
    }
  }

  void _subscribeSpace(String spaceId) {
    _subs.add(
      _db.collection('households').doc(spaceId).snapshots().listen(
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
          .collection('householdMembers')
          .where('householdId', isEqualTo: spaceId)
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
          .where('householdId', isEqualTo: spaceId)
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
          .where('householdId', isEqualTo: spaceId)
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
          .where('householdId', isEqualTo: spaceId)
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
          .where('householdId', isEqualTo: spaceId)
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
          .where('householdId', isEqualTo: spaceId)
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
    await _db.collection('households').doc(space.id).set(space.toJson());
  }

  @override
  Future<void> saveMember(SpaceMember member, [String? spaceId]) async {
    final sid = spaceId ?? _currentSpaceId;
    if (sid == null) {
      throw StateError('Cannot save a member without a space');
    }
    _upsert(_members, member, (m) => m.userId);
    await _db.collection('householdMembers').doc('${sid}_${member.userId}').set({
      ...member.toJson(),
      'householdId': sid,
    });
  }

  @override
  Future<void> removeMember(String userId, String spaceId) async {
    _members.removeWhere((m) => m.userId == userId);
    await _db
        .collection('householdMembers')
        .doc('${spaceId}_$userId')
        .delete();
  }

  @override
  Future<void> saveCycle(Cycle cycle) async {
    _upsert(_cycles, cycle, (c) => c.id);
    await _db
        .collection('cycles')
        .doc('${cycle.householdId}_${cycle.id}')
        .set(cycle.toJson());
  }

  @override
  Future<void> saveExpense(Expense expense, List<ExpenseShare> shares) async {
    final hid = expense.householdId;
    _upsert(_expenses, expense, (e) => e.id);
    _shares.removeWhere((s) => s.expenseId == expense.id);
    _shares.addAll(shares);

    final batch = _db.batch();
    batch.set(
      _db.collection('expenses').doc('${hid}_${expense.id}'),
      expense.toJson(),
    );
    final existing = await _db
        .collection('expenseShares')
        .where('householdId', isEqualTo: hid)
        .where('expenseId', isEqualTo: expense.id)
        .get();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    for (final s in shares) {
      batch.set(
        _db.collection('expenseShares').doc('${hid}_${s.id}'),
        {...s.toJson(), 'householdId': hid},
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    final sid = _expenses
            .where((e) => e.id == expenseId)
            .firstOrNull
            ?.householdId ??
        _currentSpaceId;
    _expenses.removeWhere((e) => e.id == expenseId);
    _shares.removeWhere((s) => s.expenseId == expenseId);
    if (sid == null) return;
    await _db.collection('expenses').doc('${sid}_$expenseId').delete();
    final shares = await _db
        .collection('expenseShares')
        .where('householdId', isEqualTo: sid)
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
        ?.householdId;
    if (sid == null) return;
    await _db.collection('expenseShares').doc('${sid}_${share.id}').set({
      ...share.toJson(),
      'householdId': sid,
    });
  }

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    _upsert(_settlements, settlement, (s) => s.id);
    await _db
        .collection('settlements')
        .doc('${settlement.householdId}_${settlement.id}')
        .set(settlement.toJson());
  }

  @override
  Future<void> saveCategory(Category category) async {
    _upsert(_categories, category, (c) => c.id);
    await _db
        .collection('categories')
        .doc('${category.householdId}_${category.id}')
        .set(category.toJson());
  }

  // ---- queries ----

  @override
  Future<Space?> findSpaceByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final snap = await _db
        .collection('households')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Space.fromJson(snap.docs.first.data());
  }

  @override
  Future<String?> findSpaceIdForUser(String userId) async {
    final snap = await _db
        .collection('householdMembers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['householdId'] as String?;
  }

  @override
  Future<List<Space>> findSpacesForUser(String userId) async {
    final membershipSnap = await _db
        .collection('householdMembers')
        .where('userId', isEqualTo: userId)
        .get();
    final ids = membershipSnap.docs
        .map((d) => d.data()['householdId'] as String?)
        .whereType<String>()
        .toSet();
    final result = <Space>[];
    for (final id in ids) {
      try {
        final doc = await _db.collection('households').doc(id).get();
        if (doc.exists) result.add(Space.fromJson(doc.data()!));
      } catch (_) {
        // Ignore spaces that cannot be read.
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Future<int> countMembers(String spaceId) async {
    final snap = await _db
        .collection('householdMembers')
        .where('householdId', isEqualTo: spaceId)
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
