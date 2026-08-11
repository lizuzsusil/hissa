import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/ids.dart';
import '../core/money.dart';
import '../data/firestore_repository.dart';
import '../data/in_memory_repository.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../logic/balances.dart';
import '../logic/settlements.dart';
import '../logic/splits.dart';
import '../models/models.dart';

/// Central application state. Owns the repository and exposes a small,
/// imperative API that the UI calls.
///
/// Authentication is handled by Firebase Auth; account state is persisted
/// natively by the SDK and mirrored to a session blob for the household /
/// cycle selections. When signed in, the repository is a [FirestoreRepository]
/// that keeps local caches in sync via realtime listeners.
class AppState extends ChangeNotifier {
  static const _sessionKey = 'Hissa_session_v1';
  static const _introKey = 'Hissa_intro_seen_v1';

  ExpenseRepository _repo = InMemoryRepository();
  String? _currentUserId;
  String? _householdId;
  String? _cycleId;
  String? _onboardingMode;
  bool _introSeen = false;
  bool _loaded = false;

  ExpenseRepository get repo => _repo;
  bool get isLoaded => _loaded;
  String? get onboardingMode => _onboardingMode;
  String? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null;
  bool get hasHousehold => _householdId != null;
  bool get introSeen => _introSeen;

  /// Marks the feature-intro carousel as seen so it only shows on first run.
  Future<void> markIntroSeen() async {
    _introSeen = true;
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_introKey, true);
  }

  // ---- session ----

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    _introSeen = await prefs.getBool(_introKey) ?? false;
    final sessionRaw = await prefs.getString(_sessionKey);

    String? userId;
    String? householdId;
    String? cycleId;
    if (sessionRaw != null) {
      try {
        final json = jsonDecode(sessionRaw) as Map<String, dynamic>;
        userId = json['userId'] as String?;
        householdId = json['householdId'] as String?;
        cycleId = json['cycleId'] as String?;
        _onboardingMode = json['mode'] as String?;
      } catch (_) {
        // Ignore a corrupt session; the user simply starts signed out.
      }
    }

    // Firebase Auth persists the signed-in user across launches, so a cold
    // start can restore a session without a password.
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      final restore = userId != null && userId == authUser.uid;
      _currentUserId = authUser.uid;
      _householdId = restore ? householdId : null;
      _cycleId = restore ? cycleId : null;
      await _attachRepository();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'userId': _currentUserId,
        'householdId': _householdId,
        'cycleId': _cycleId,
        'mode': _onboardingMode,
      }),
    );
  }

  Future<void> _commit() async {
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }
    super.dispose();
  }

  /// Replaces the repository with a fresh Firestore-backed one subscribed to
  /// the current user's profile and household (derived from their
  /// membership, so it stays correct even after joining a new household).
  Future<void> _attachRepository() async {
    final uid = _currentUserId;
    if (uid == null) return;
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }

    final repo = FirestoreRepository(FirebaseFirestore.instance);
    String? householdId;
    try {
      householdId = await repo.findHouseholdIdForUser(uid);
    } catch (_) {
      householdId = null;
    }
    if (householdId == null) _cycleId = null;
    _householdId = householdId;
    _repo = repo;
    await repo.start(uid: uid, householdId: householdId, onChanged: notifyListeners);
  }

  // ---- auth ----

  Future<void> setOnboardingMode(String mode) async {
    _onboardingMode = mode;
    await _persist();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
    } on FirebaseAuthException {
      return false;
    }
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _householdId = null;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
  }

  /// Demo login: seeds the worked demo dataset into Firestore for this
  /// anonymous account and signs in as Ram inside the "Our Home" household.
  Future<void> signInDemo() async {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    final uid = cred.user!.uid;
    await seedDemoFirestore(FirebaseFirestore.instance, uid);
    _currentUserId = uid;
    _householdId = 'h_demo';
    _cycleId = null;
    await _attachRepository();
    await _commit();
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: normalized,
      password: password,
    );
    final uid = cred.user!.uid;
    _currentUserId = uid;
    _householdId = null;
    _cycleId = null;
    await _attachRepository();
    final displayName = name.trim().isEmpty
        ? _capitalize(normalized.split('@').first)
        : name.trim();
    await _repo.saveUser(
      User(id: uid, name: displayName, email: normalized, createdAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> signOut() async {
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }
    _repo = InMemoryRepository();
    _currentUserId = null;
    _householdId = null;
    _cycleId = null;
    try {
      await FirebaseAuth.instance.signOut();
    } on Exception {
      // Local session is cleared regardless.
    }
    await _commit();
  }

  Future<void> updateProfile(String name) async {
    final user = currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repo.saveUser(user.copyWith(name: trimmed));
    final member = members.where((m) => m.userId == user.id).firstOrNull;
    if (member != null && _householdId != null) {
      await _repo.saveMember(member.copyWith(name: trimmed), _householdId);
    }
    await _commit();
  }

  // ---- current selections ----

  User? get currentUser {
    if (_currentUserId == null) return null;
    return _repo.users.where((u) => u.id == _currentUserId).firstOrNull;
  }

  Household? get household {
    if (_householdId == null) return null;
    return _repo.households.where((h) => h.id == _householdId).firstOrNull;
  }

  List<HouseholdMember> get members {
    if (_householdId == null) return const [];
    return _repo.members.toList();
  }

  bool get isOwner {
    final user = currentUser;
    if (user == null) return false;
    return members.any(
      (m) => m.userId == user.id && m.role == MemberRole.owner,
    );
  }

  List<Cycle> get cycles {
    if (_householdId == null) return const [];
    final all =
        _repo.cycles.where((c) => c.householdId == _householdId).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return all;
  }

  Cycle? get activeCycle {
    if (_householdId == null) return null;
    final active = _repo.cycles
        .where(
          (c) =>
              c.householdId == _householdId && c.status == CycleStatus.active,
        )
        .firstOrNull;
    if (active != null) return active;
    return _repo.cycles
        .where((c) => c.householdId == _householdId)
        .toList()
        .lastOrNull;
  }

  Cycle? get selectedCycle {
    if (_cycleId == null) return activeCycle;
    return _repo.cycles.where((c) => c.id == _cycleId).firstOrNull ??
        activeCycle;
  }

  Future<void> selectCycle(String cycleId) async {
    _cycleId = cycleId;
    await _persist();
    notifyListeners();
  }

  List<Category> get categories {
    if (_householdId == null) return const [];
    return _repo.categories
        .where((c) => c.householdId == _householdId)
        .toList();
  }

  // ---- household ----

  Future<bool> createHousehold({
    required String name,
    required String currency,
    required List<String> memberNames,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final householdId = 'h_${genId(8)}';
    final household = Household(
      id: householdId,
      name: name.trim().isEmpty ? 'Our Home' : name.trim(),
      currency: currency,
      inviteCode: genInviteCode(),
      createdAt: DateTime.now(),
    );
    // The owner membership is written before the household so security rules
    // (which gate household writes on membership) accept the create.
    await _repo.saveMember(
      HouseholdMember(
        userId: user.id,
        name: user.name,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
      ),
      householdId,
    );
    await _repo.saveHousehold(household);

    for (final memberName in memberNames) {
      final trimmed = memberName.trim();
      if (trimmed.isEmpty) continue;
      if (_repo.members.any((m) => m.name == trimmed)) continue;
      final newUser = User(
        id: 'u_${genId(8)}',
        name: trimmed,
        email:
            '${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@hissa.app',
        createdAt: DateTime.now(),
      );
      await _repo.saveUser(newUser);
      await _repo.saveMember(
        HouseholdMember(
          userId: newUser.id,
          name: trimmed,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
        householdId,
      );
    }

    await _seedCategories(householdId);
    await _startCycleFor(householdId, DateTime.now());

    _householdId = householdId;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
  }

  Future<bool> joinHousehold(String code) async {
    final user = currentUser;
    if (user == null) return false;
    final normalized = code.trim().toUpperCase();
    final household = await _repo.findHouseholdByInviteCode(normalized);
    if (household == null) return false;

    if (!_repo.members.any((m) => m.userId == user.id)) {
      await _repo.saveMember(
        HouseholdMember(
          userId: user.id,
          name: user.name,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
        household.id,
      );
    }
    _householdId = household.id;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
  }

  Future<void> renameHousehold(String name) async {
    final h = household;
    if (h == null) return;
    await _repo.saveHousehold(
      h.copyWith(name: name.trim().isEmpty ? h.name : name.trim()),
    );
    await _commit();
  }

  Future<void> renameHouseholdCurrency(String code) async {
    final h = household;
    if (h == null) return;
    await _repo.saveHousehold(h.copyWith(currency: code));
    await _commit();
  }

  Future<void> addMember(String name) async {
    final h = household;
    if (h == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_repo.members.any(
      (m) => m.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }
    final newUser = User(
      id: 'u_${genId(8)}',
      name: trimmed,
      email:
          '${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@hissa.app',
      createdAt: DateTime.now(),
    );
    await _repo.saveUser(newUser);
    await _repo.saveMember(
      HouseholdMember(
        userId: newUser.id,
        name: trimmed,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
      ),
      h.id,
    );
    await _commit();
  }

  Future<void> removeMember(String userId) async {
    if (userId == currentUser?.id) return;
    await _repo.removeMember(userId, _householdId ?? '');
    await _commit();
  }

  // ---- categories ----

  Future<void> addCategory(String name, IconData icon, Color color) async {
    final h = household;
    if (h == null) return;
    await _repo.saveCategory(
      Category(
        id: 'cat_${genId(8)}',
        householdId: h.id,
        name: name.trim(),
        iconCodePoint: icon.codePoint,
        colorValue: color.toARGB32(),
        isDefault: false,
      ),
    );
    await _commit();
  }

  Future<void> _seedCategories(String householdId) async {
    for (final preset in kDefaultCategories) {
      await _repo.saveCategory(
        Category.preset(
          id: 'cat_${preset.name.toLowerCase()}',
          householdId: householdId,
          name: preset.name,
          icon: preset.icon,
          color: preset.color,
        ),
      );
    }
  }

  // ---- cycles ----

  Future<void> _startCycleFor(String householdId, DateTime anchor) async {
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 0);
    final existing = _repo.cycles
        .where(
          (c) =>
              c.householdId == householdId &&
              c.startDate.year == start.year &&
              c.startDate.month == start.month,
        )
        .firstOrNull;
    if (existing != null) return;
    await _repo.saveCycle(
      Cycle(
        id: 'c_${genId(8)}',
        householdId: householdId,
        name: '${_monthLabel(start)} ${start.year}',
        startDate: start,
        endDate: end,
        status: CycleStatus.active,
      ),
    );
  }

  Future<void> closeCycle() async {
    final cycle = selectedCycle;
    if (cycle == null) return;
    final balances = computeBalances(cycle.id);
    final hasOutstanding = balances.any((b) => !b.remaining.isZero);
    if (hasOutstanding) return;
    await _repo.saveCycle(
      cycle.copyWith(status: CycleStatus.closed, closedAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> startNewCycle() async {
    final h = household;
    final cycle = selectedCycle;
    if (h == null) return;
    final anchor = DateTime.now();
    if (cycle != null && cycle.status == CycleStatus.active) {
      await _repo.saveCycle(
        cycle.copyWith(status: CycleStatus.closed, closedAt: DateTime.now()),
      );
    }
    await _startCycleFor(h.id, anchor);
    _cycleId = null;
    await _commit();
  }

  // ---- expenses ----

  Future<void> addExpense({
    required String description,
    required Money amount,
    required String paidByUserId,
    required DateTime date,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final h = household;
    final cycle = selectedCycle;
    if (h == null || cycle == null) return;

    final expense = Expense(
      id: 'e_${genId(8)}',
      householdId: h.id,
      cycleId: cycle.id,
      paidByUserId: paidByUserId,
      amount: amount,
      categoryId: categoryId,
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      date: date,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final shares = SplitCalculator.build(
      expenseId: expense.id,
      amount: expense.amount,
      participantIds: participantIds,
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    await _repo.saveExpense(expense, shares);
    await _commit();
  }

  Future<void> updateExpense(
    Expense expense, {
    required String description,
    required Money amount,
    required String paidByUserId,
    required DateTime date,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final updated = expense.copyWith(
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amount: amount,
      paidByUserId: paidByUserId,
      date: date,
      categoryId: categoryId,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
    final shares = SplitCalculator.build(
      expenseId: expense.id,
      amount: updated.amount,
      participantIds: participantIds,
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    await _repo.saveExpense(updated, shares);
    await _commit();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _repo.deleteExpense(expenseId);
    await _commit();
  }

  // ---- settlements ----

  Future<void> addSettlement({
    required String fromUserId,
    required String toUserId,
    required Money amount,
    required String paymentMethod,
    required DateTime date,
    String? note,
  }) async {
    final h = household;
    final cycle = selectedCycle;
    if (h == null || cycle == null) return;
    await _repo.saveSettlement(
      Settlement(
        id: 's_${genId(8)}',
        householdId: h.id,
        cycleId: cycle.id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        currency: h.currency,
        paymentMethod: paymentMethod,
        date: date,
        note: note?.trim().isEmpty ?? true ? null : note!.trim(),
        status: SettlementStatus.paid,
        createdAt: DateTime.now(),
      ),
    );
    await _commit();
  }

  // ---- derived calculations ----

  List<Expense> get expensesInCycle {
    final cycle = selectedCycle;
    if (cycle == null) return const [];
    final list = _repo.expenses.where((e) => e.cycleId == cycle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<ExpenseShare> sharesForExpense(String expenseId) {
    return _repo.sharesForExpense(expenseId);
  }

  List<Settlement> get settlementsInCycle {
    final cycle = selectedCycle;
    if (cycle == null) return const [];
    return _repo.settlements.where((s) => s.cycleId == cycle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<BalanceInfo> computeBalances([String? cycleId]) {
    final h = household;
    final cycle = cycleId == null
        ? selectedCycle
        : _repo.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (h == null || cycle == null) return const [];
    return BalanceCalculator.compute(
      household: h,
      members: members,
      cycle: cycle,
      expenses: _repo.expenses,
      shares: _repo.shares,
      settlements: _repo.settlements,
    );
  }

  Money totalSpent([String? cycleId]) {
    final cycle = cycleId == null
        ? selectedCycle
        : _repo.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (cycle == null) return Money.zero();
    return BalanceCalculator.totalSpent(_repo.expenses, cycle.id);
  }

  List<SettlementProposal> settlementProposals([String? cycleId]) {
    final balances = computeBalances(cycleId);
    final map = <String, Money>{};
    for (final b in balances) {
      map[b.userId] = b.remaining;
    }
    return SettlementCalculator.minimize(map);
  }

  String? memberName(String userId) =>
      members.where((m) => m.userId == userId).firstOrNull?.name;

  Category? categoryFor(String? categoryId) {
    if (categoryId == null) return null;
    return _repo.categories.where((c) => c.id == categoryId).firstOrNull;
  }
}

String _monthLabel(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[d.month - 1];
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}
