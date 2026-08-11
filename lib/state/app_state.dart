import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ids.dart';
import '../core/money.dart';
import '../data/codec.dart';
import '../data/in_memory_repository.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../logic/balances.dart';
import '../logic/settlements.dart';
import '../logic/splits.dart';
import '../models/models.dart';

/// Central application state. Owns the repository and exposes a small,
/// imperative API that the UI calls; every mutation notifies listeners and
/// persists to local storage so the demo survives relaunches.
class AppState extends ChangeNotifier {
  static const _prefsKey = 'Hissa_repo_v1';
  static const _sessionKey = 'Hissa_session_v1';

  ExpenseRepository _repo = InMemoryRepository();
  String? _currentUserId;
  String? _householdId;
  String? _cycleId;
  String? _onboardingMode;
  bool _loaded = false;

  ExpenseRepository get repo => _repo;
  bool get isLoaded => _loaded;
  String? get onboardingMode => _onboardingMode;
  String? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null;
  bool get hasHousehold => _householdId != null;

  // ---- session ----

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    final sessionRaw = await prefs.getString(_sessionKey);
    if (sessionRaw != null) {
      try {
        final json = jsonDecode(sessionRaw) as Map<String, dynamic>;
        _currentUserId = json['userId'] as String?;
        _householdId = json['householdId'] as String?;
        _cycleId = json['cycleId'] as String?;
        _onboardingMode = json['mode'] as String?;
      } catch (_) {
        _currentUserId = null;
        _householdId = null;
        _cycleId = null;
      }
    }

    final dataRaw = await prefs.getString(_prefsKey);
    if (dataRaw != null) {
      try {
        _repo = RepositoryCodec.decode(
          jsonDecode(dataRaw) as Map<String, dynamic>,
        );
      } catch (_) {
        _repo = buildSeedRepository();
      }
    } else {
      _repo = buildSeedRepository();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_prefsKey, jsonEncode(RepositoryCodec.encode(_repo)));
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

  // ---- auth ----

  Future<void> setOnboardingMode(String mode) async {
    _onboardingMode = mode;
    await _persist();
  }

  Future<void> signIn({required String email, String? password}) async {
    final normalized = email.trim().toLowerCase();
    var user = _repo.users
        .where((u) => u.email.toLowerCase() == normalized)
        .firstOrNull;
    if (user == null) {
      final name = normalized.split('@').first;
      user = User(
        id: 'u_${genId(8)}',
        name: _capitalize(name),
        email: normalized,
        createdAt: DateTime.now(),
      );
      _repo.saveUser(user);
    }
    _currentUserId = user.id;
    await _commit();
  }

  Future<void> signUp({
    required String name,
    required String email,
    String? password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final user = User(
      id: 'u_${genId(8)}',
      name: name.trim().isEmpty
          ? _capitalize(normalized.split('@').first)
          : name.trim(),
      email: normalized,
      createdAt: DateTime.now(),
    );
    _repo.saveUser(user);
    _currentUserId = user.id;
    await _commit();
  }

  Future<void> signOut() async {
    _currentUserId = null;
    _householdId = null;
    _cycleId = null;
    await _commit();
  }

  Future<void> updateProfile(String name) async {
    final user = currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _repo.saveUser(user.copyWith(name: trimmed));
    final member = members.where((m) => m.userId == user.id).firstOrNull;
    if (member != null) {
      _repo.saveMember(member.copyWith(name: trimmed));
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
    final all = _repo.members.toList();
    return all;
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

  void selectCycle(String cycleId) async {
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
    _repo.saveHousehold(household);

    _repo.saveMember(
      HouseholdMember(
        userId: user.id,
        name: user.name,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
      ),
    );

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
      _repo.saveUser(newUser);
      _repo.saveMember(
        HouseholdMember(
          userId: newUser.id,
          name: trimmed,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
      );
    }

    _seedCategories(householdId);
    _startCycleFor(householdId, DateTime.now());

    _householdId = householdId;
    _cycleId = null;
    await _commit();
    return true;
  }

  Future<bool> joinHousehold(String code) async {
    final user = currentUser;
    if (user == null) return false;
    final normalized = code.trim().toUpperCase();
    final household = _repo.households
        .where((h) => h.inviteCode.toUpperCase() == normalized)
        .firstOrNull;
    if (household == null) return false;

    if (!_repo.members.any((m) => m.userId == user.id)) {
      _repo.saveMember(
        HouseholdMember(
          userId: user.id,
          name: user.name,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
      );
    }
    _householdId = household.id;
    _cycleId = null;
    await _commit();
    return true;
  }

  void renameHousehold(String name) {
    final h = household;
    if (h == null) return;
    _repo.saveHousehold(
      h.copyWith(name: name.trim().isEmpty ? h.name : name.trim()),
    );
    _commit();
  }

  void renameHouseholdCurrency(String code) {
    final h = household;
    if (h == null) return;
    _repo.saveHousehold(h.copyWith(currency: code));
    _commit();
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
    _repo.saveUser(newUser);
    _repo.saveMember(
      HouseholdMember(
        userId: newUser.id,
        name: trimmed,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
      ),
    );
    await _commit();
  }

  Future<void> removeMember(String userId) async {
    if (userId == currentUser?.id) return;
    _repo.removeMember(userId, _householdId ?? '');
    await _commit();
  }

  // ---- categories ----

  void addCategory(String name, IconData icon, Color color) {
    final h = household;
    if (h == null) return;
    _repo.saveCategory(
      Category(
        id: 'cat_${genId(8)}',
        householdId: h.id,
        name: name.trim(),
        iconCodePoint: icon.codePoint,
        colorValue: color.toARGB32(),
        isDefault: false,
      ),
    );
    _commit();
  }

  void _seedCategories(String householdId) {
    const presets = [
      ('Groceries', Icons.shopping_basket_outlined, 0xFF16A34A),
      ('Rent', Icons.home_outlined, 0xFF6366F1),
      ('Electricity', Icons.bolt_outlined, 0xFFF59E0B),
      ('Water', Icons.water_drop_outlined, 0xFF0EA5E9),
      ('Internet', Icons.wifi_outlined, 0xFF8B5CF6),
      ('Food', Icons.restaurant_outlined, 0xFFF97316),
      ('Transportation', Icons.directions_bus_outlined, 0xFFEC4899),
      ('Medical', Icons.medical_services_outlined, 0xFFEF4444),
      ('Household', Icons.chair_outlined, 0xFF14B8A6),
      ('Maintenance', Icons.handyman_outlined, 0xFF78716C),
      ('Education', Icons.school_outlined, 0xFF06B6D4),
      ('Entertainment', Icons.movie_outlined, 0xFFA855F7),
      ('Shopping', Icons.shopping_bag_outlined, 0xFF3B82F6),
      ('Other', Icons.more_horiz, 0xFF64748B),
    ];
    for (final (name, icon, color) in presets) {
      _repo.saveCategory(
        Category(
          id: 'cat_${genId(8)}',
          householdId: householdId,
          name: name,
          iconCodePoint: icon.codePoint,
          colorValue: color,
          isDefault: true,
        ),
      );
    }
  }

  // ---- cycles ----

  void _startCycleFor(String householdId, DateTime anchor) {
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
    _repo.saveCycle(
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
    _repo.saveCycle(
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
      _repo.saveCycle(
        cycle.copyWith(status: CycleStatus.closed, closedAt: DateTime.now()),
      );
    }
    _startCycleFor(h.id, anchor);
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
    _repo.saveExpense(expense, shares);
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
    _repo.saveExpense(updated, shares);
    await _commit();
  }

  Future<void> deleteExpense(String expenseId) async {
    _repo.deleteExpense(expenseId);
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
    _repo.saveSettlement(
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
