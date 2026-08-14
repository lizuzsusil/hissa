import '../models/models.dart';
import 'repository.dart';

/// Simple in-memory repository. It is used as the placeholder while signed
/// out and in unit tests. All data is held in lists so the UI can be rebuilt
/// eagerly after each mutation. The async methods complete immediately:
/// bodies run synchronously so callers that do not await (seed builders,
/// tests) still observe the mutation right away.
class InMemoryRepository implements ExpenseRepository {
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
  Future<void> saveUser(User user) async {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
    } else {
      _users.add(user);
    }
  }

  @override
  Future<void> saveSpace(Space space) async {
    final idx = _spaces.indexWhere((s) => s.id == space.id);
    if (idx >= 0) {
      _spaces[idx] = space;
    } else {
      _spaces.add(space);
    }
  }

  @override
  Future<void> saveMember(SpaceMember member, [String? spaceId]) async {
    final idx = _members.indexWhere((m) => m.userId == member.userId);
    if (idx >= 0) {
      _members[idx] = member;
    } else {
      _members.add(member);
    }
  }

  @override
  Future<void> removeMember(String userId, String spaceId) async {
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
  Future<void> saveMemberGroup(MemberGroup group) async {
    final idx = _memberGroups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _memberGroups[idx] = group;
    } else {
      _memberGroups.add(group);
    }
  }

  @override
  Future<void> addGroupMember(String groupId, String userId) async {
    _memberGroupMembers.removeWhere((m) => m.groupId == groupId && m.userId == userId);
    _memberGroupMembers.add(
      MemberGroupMember(groupId: groupId, userId: userId, createdAt: DateTime.now()),
    );
  }

  @override
  Future<void> removeGroupMember(String groupId, String userId) async {
    _memberGroupMembers.removeWhere((m) => m.groupId == groupId && m.userId == userId);
  }

  @override
  Future<void> deleteMemberGroup(String groupId) async {
    _memberGroups.removeWhere((g) => g.id == groupId);
    _memberGroupMembers.removeWhere((m) => m.groupId == groupId);
  }

  @override
  Future<void> saveGroupRequest(GroupRequest request) async {
    _groupRequests.removeWhere((r) => r.id == request.id);
    _groupRequests.add(request);
  }

  @override
  Future<void> updateGroupRequestStatus(
    String requestId,
    GroupRequestStatus status,
  ) async {
    final i = _groupRequests.indexWhere((r) => r.id == requestId);
    if (i >= 0) {
      _groupRequests[i] = _groupRequests[i].copyWith(status: status);
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
  Future<Space?> findSpaceByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    for (final s in _spaces) {
      if (s.inviteCode.toUpperCase() == normalized) return s;
    }
    return null;
  }

  @override
  Future<String?> findSpaceIdForUser(String userId) async {
    for (final s in _spaces) {
      final joined = _members.any((m) => m.userId == userId);
      if (joined) return s.id;
    }
    return null;
  }

  @override
  Future<List<Space>> findSpacesForUser(String userId) async {
    final result = <Space>[];
    for (final s in _spaces) {
      final joined = _members.any((m) => m.userId == userId);
      if (joined) result.add(s);
    }
    return result;
  }

  @override
  Future<int> countMembers(String spaceId) async {
    return _members.length;
  }
}
