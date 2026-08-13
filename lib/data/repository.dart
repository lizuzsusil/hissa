import '../models/models.dart';

/// Persistence boundary. [InMemoryRepository] backs the signed-out placeholder
/// state and unit tests; [FirestoreRepository] persists to Firebase. Read
/// access is synchronous over locally-cached lists so the UI can rebuild
/// eagerly; mutations are async and await the underlying write.
abstract class ExpenseRepository {
  List<User> get users;
  List<Household> get households;
  List<HouseholdMember> get members;
  List<Cycle> get cycles;
  List<Expense> get expenses;
  List<ExpenseShare> get shares;
  List<Settlement> get settlements;
  List<Category> get categories;

  Future<void> saveUser(User user);
  Future<void> saveHousehold(Household household);
  Future<void> saveMember(HouseholdMember member, [String? householdId]);
  Future<void> removeMember(String userId, String householdId);
  Future<void> saveCycle(Cycle cycle);
  Future<void> saveExpense(Expense expense, List<ExpenseShare> shares);
  Future<void> deleteExpense(String expenseId);
  Future<void> addShare(ExpenseShare share);
  Future<void> saveSettlement(Settlement settlement);
  Future<void> saveCategory(Category category);

  List<ExpenseShare> sharesForExpense(String expenseId);
  List<ExpenseShare> sharesForCycle(List<Expense> expenses);

  Future<Household?> findHouseholdByInviteCode(String code);
  Future<String?> findHouseholdIdForUser(String userId);

  /// All households the user belongs to, used by the Spaces dashboard.
  Future<List<Household>> findHouseholdsForUser(String userId);

  /// Number of members in a household, used for the Spaces dashboard card.
  Future<int> countMembers(String householdId);
}
