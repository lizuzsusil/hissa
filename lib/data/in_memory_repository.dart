import '../models/models.dart';
import 'repository.dart';

/// Simple in-memory repository used for the demo build and unit tests. All
/// data is held in lists so the UI can be rebuilt eagerly after each
/// mutation. The async methods complete immediately: bodies run synchronously
/// so callers that do not await (seed builders, tests) still observe the
/// mutation right away.
class InMemoryRepository implements ExpenseRepository {
  final List<User> _users = [];
  final List<Household> _households = [];
  final List<HouseholdMember> _members = [];
  final List<Cycle> _cycles = [];
  final List<Expense> _expenses = [];
  final List<ExpenseShare> _shares = [];
  final List<Settlement> _settlements = [];
  final List<Category> _categories = [];

  @override
  List<User> get users => List.unmodifiable(_users);

  @override
  List<Household> get households => List.unmodifiable(_households);

  @override
  List<HouseholdMember> get members => List.unmodifiable(_members);

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
  Future<void> saveUser(User user) async {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
    } else {
      _users.add(user);
    }
  }

  @override
  Future<void> saveHousehold(Household household) async {
    final idx = _households.indexWhere((h) => h.id == household.id);
    if (idx >= 0) {
      _households[idx] = household;
    } else {
      _households.add(household);
    }
  }

  @override
  Future<void> saveMember(HouseholdMember member, [String? householdId]) async {
    final idx = _members.indexWhere((m) => m.userId == member.userId);
    if (idx >= 0) {
      _members[idx] = member;
    } else {
      _members.add(member);
    }
  }

  @override
  Future<void> removeMember(String userId, String householdId) async {
    _members.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<void> saveCycle(Cycle cycle) async {
    final idx = _cycles.indexWhere((c) => c.id == cycle.id);
    if (idx >= 0) {
      _cycles[idx] = cycle;
    } else {
      _cycles.add(cycle);
    }
  }

  @override
  Future<void> saveExpense(Expense expense, List<ExpenseShare> shares) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx >= 0) {
      _expenses[idx] = expense;
    } else {
      _expenses.add(expense);
    }
    _shares.removeWhere((s) => s.expenseId == expense.id);
    _shares.addAll(shares);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    _expenses.removeWhere((e) => e.id == expenseId);
    _shares.removeWhere((s) => s.expenseId == expenseId);
  }

  @override
  Future<void> addShare(ExpenseShare share) async {
    _shares.removeWhere((s) => s.id == share.id);
    _shares.add(share);
  }

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    final idx = _settlements.indexWhere((s) => s.id == settlement.id);
    if (idx >= 0) {
      _settlements[idx] = settlement;
    } else {
      _settlements.add(settlement);
    }
  }

  @override
  Future<void> saveCategory(Category category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      _categories[idx] = category;
    } else {
      _categories.add(category);
    }
  }

  @override
  List<ExpenseShare> sharesForExpense(String expenseId) {
    return _shares.where((s) => s.expenseId == expenseId).toList();
  }

  @override
  List<ExpenseShare> sharesForCycle(List<Expense> expenses) {
    final ids = expenses.map((e) => e.id).toSet();
    return _shares.where((s) => ids.contains(s.expenseId)).toList();
  }

  @override
  Future<Household?> findHouseholdByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    for (final h in _households) {
      if (h.inviteCode.toUpperCase() == normalized) return h;
    }
    return null;
  }

  @override
  Future<String?> findHouseholdIdForUser(String userId) async {
    for (final h in _households) {
      final joined = _members.any((m) => m.userId == userId);
      if (joined) return h.id;
    }
    return null;
  }
}
