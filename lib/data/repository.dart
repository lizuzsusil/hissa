import '../models/models.dart';

/// Persistence boundary. The in-memory implementation backs the demo,
/// and can later be swapped for a Firebase Firestore backed repository
/// without touching the UI or domain layers.
abstract class ExpenseRepository {
  List<User> get users;
  List<Household> get households;
  List<HouseholdMember> get members;
  List<Cycle> get cycles;
  List<Expense> get expenses;
  List<ExpenseShare> get shares;
  List<Settlement> get settlements;
  List<Category> get categories;

  void saveUser(User user);
  void saveHousehold(Household household);
  void saveMember(HouseholdMember member);
  void removeMember(String userId, String householdId);
  void saveCycle(Cycle cycle);
  void saveExpense(Expense expense, List<ExpenseShare> shares);
  void deleteExpense(String expenseId);
  void addShare(ExpenseShare share);
  void saveSettlement(Settlement settlement);
  void saveCategory(Category category);

  List<ExpenseShare> sharesForExpense(String expenseId);
  List<ExpenseShare> sharesForCycle(List<Expense> expenses);
}
