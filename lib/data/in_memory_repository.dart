import '../models/models.dart';
import 'repository.dart';

/// Simple in-memory repository used for the demo build. All data is held
/// in lists so the UI can be rebuilt eagerly after each mutation.
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
  void saveUser(User user) {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
    } else {
      _users.add(user);
    }
  }

  @override
  void saveHousehold(Household household) {
    final idx = _households.indexWhere((h) => h.id == household.id);
    if (idx >= 0) {
      _households[idx] = household;
    } else {
      _households.add(household);
    }
  }

  @override
  void saveMember(HouseholdMember member) {
    final idx = _members.indexWhere((m) => m.userId == member.userId);
    if (idx >= 0) {
      _members[idx] = member;
    } else {
      _members.add(member);
    }
  }

  @override
  void removeMember(String userId, String householdId) {
    _members.removeWhere((m) =>
        m.userId == userId);
  }

  @override
  void saveCycle(Cycle cycle) {
    final idx = _cycles.indexWhere((c) => c.id == cycle.id);
    if (idx >= 0) {
      _cycles[idx] = cycle;
    } else {
      _cycles.add(cycle);
    }
  }

  @override
  void saveExpense(Expense expense, List<ExpenseShare> shares) {
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
  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    _shares.removeWhere((s) => s.expenseId == expenseId);
  }

  @override
  void addShare(ExpenseShare share) {
    _shares.removeWhere((s) => s.id == share.id);
    _shares.add(share);
  }

  @override
  void saveSettlement(Settlement settlement) {
    final idx = _settlements.indexWhere((s) => s.id == settlement.id);
    if (idx >= 0) {
      _settlements[idx] = settlement;
    } else {
      _settlements.add(settlement);
    }
  }

  @override
  void saveCategory(Category category) {
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
}
