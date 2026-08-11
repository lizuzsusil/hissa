import '../models/models.dart';
import 'in_memory_repository.dart';
import 'repository.dart';

/// Serializes the whole repository to / from JSON so the demo data can be
/// persisted locally between launches (mirrors a Firebase document model).
class RepositoryCodec {
  static Map<String, dynamic> encode(ExpenseRepository repo) {
    return {
      'version': 1,
      'users': repo.users.map((u) => u.toJson()).toList(),
      'households': repo.households.map((h) => h.toJson()).toList(),
      'members': repo.members.map((m) => m.toJson()).toList(),
      'cycles': repo.cycles.map((c) => c.toJson()).toList(),
      'expenses': repo.expenses.map((e) => e.toJson()).toList(),
      'shares': repo.shares.map((s) => s.toJson()).toList(),
      'settlements': repo.settlements.map((s) => s.toJson()).toList(),
      'categories': repo.categories.map((c) => c.toJson()).toList(),
    };
  }

  static InMemoryRepository decode(Map<String, dynamic> json) {
    final repo = InMemoryRepository();
    for (final item in (json['users'] as List? ?? [])) {
      repo.saveUser(User.fromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['households'] as List? ?? [])) {
      repo.saveHousehold(Household.fromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['members'] as List? ?? [])) {
      repo.saveMember(HouseholdMember.fromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['cycles'] as List? ?? [])) {
      repo.saveCycle(Cycle.fromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['expenses'] as List? ?? [])) {
      final e = Expense.fromJson(item as Map<String, dynamic>);
      repo.saveExpense(e, const []);
    }
    for (final item in (json['shares'] as List? ?? [])) {
      final s = ExpenseShare.fromJson(item as Map<String, dynamic>);
      repo.sharesForExpense(s.expenseId);
      repo.addShare(s);
    }
    for (final item in (json['settlements'] as List? ?? [])) {
      repo.saveSettlement(Settlement.fromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['categories'] as List? ?? [])) {
      repo.saveCategory(Category.fromJson(item as Map<String, dynamic>));
    }
    return repo;
  }
}
