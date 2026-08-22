import '../core/money.dart';
import '../models/models.dart';
import '../logic/splits.dart';
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
  final List<HissaIncome> _hissaIncomes = [];
  final List<EstimatedExpense> _estimatedExpenses = [];
  final List<Category> _categories = [];
  final List<MemberGroup> _memberGroups = [];
  final List<MemberGroupMember> _memberGroupMembers = [];
  final List<GroupRequest> _groupRequests = [];
  final List<SpaceJoinRequest> _spaceJoinRequests = [];
  final List<AppNotification> _notifications = [];

  @override
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

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
  List<HissaIncome> get hissaIncomes => List.unmodifiable(_hissaIncomes);

  @override
  List<EstimatedExpense> get estimatedExpenses =>
      List.unmodifiable(_estimatedExpenses);

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
  List<SpaceJoinRequest> get spaceJoinRequests =>
      List.unmodifiable(_spaceJoinRequests);

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
    _members.removeWhere((m) => m.userId == userId && m.spaceId == spaceId);
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
  Future<void> saveHissaIncome(HissaIncome income) async {
    final idx = _hissaIncomes.indexWhere((i) => i.id == income.id);
    if (idx >= 0) {
      _hissaIncomes[idx] = income;
    } else {
      _hissaIncomes.add(income);
    }
  }

  @override
  Future<void> deleteHissaIncome(String incomeId) async {
    _hissaIncomes.removeWhere((i) => i.id == incomeId);
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
  Future<void> saveEstimatedExpense(EstimatedExpense estimate) async {
    final idx = _estimatedExpenses.indexWhere((e) => e.id == estimate.id);
    if (idx >= 0) {
      _estimatedExpenses[idx] = estimate;
    } else {
      _estimatedExpenses.add(estimate);
    }
  }

  @override
  Future<void> deleteEstimatedExpense(String estimateId) async {
    _estimatedExpenses.removeWhere((e) => e.id == estimateId);
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
    _memberGroupMembers.removeWhere(
      (m) => m.groupId == groupId && m.userId == userId,
    );
    _memberGroupMembers.add(
      MemberGroupMember(
        groupId: groupId,
        userId: userId,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> removeGroupMember(String groupId, String userId) async {
    _memberGroupMembers.removeWhere(
      (m) => m.groupId == groupId && m.userId == userId,
    );
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
  Future<void> saveSpaceJoinRequest(SpaceJoinRequest request) async {
    _spaceJoinRequests.removeWhere((r) => r.id == request.id);
    _spaceJoinRequests.add(request);
  }

  @override
  Future<void> updateSpaceJoinRequestStatus(
    String requestId,
    SpaceJoinRequestStatus status,
  ) async {
    final i = _spaceJoinRequests.indexWhere((r) => r.id == requestId);
    if (i >= 0) {
      _spaceJoinRequests[i] = _spaceJoinRequests[i].copyWith(status: status);
    }
  }

  @override
  Future<void> saveNotification(AppNotification notification) async {
    final idx = _notifications.indexWhere((n) => n.id == notification.id);
    if (idx >= 0) {
      _notifications[idx] = notification;
    } else {
      _notifications.add(notification);
    }
  }

  @override
  Future<SpaceJoinRequest?> findPendingSpaceJoinRequest(
    String spaceId,
    String userId,
  ) async {
    for (final r in _spaceJoinRequests) {
      if (r.spaceId == spaceId &&
          r.requesterUserId == userId &&
          r.status == SpaceJoinRequestStatus.pending) {
        return r;
      }
    }
    return null;
  }

  @override
  Future<List<SpaceJoinRequest>> fetchMyPendingSpaceJoinRequests(
    String userId,
  ) async {
    return _spaceJoinRequests
        .where(
          (r) =>
              r.requesterUserId == userId &&
              r.status == SpaceJoinRequestStatus.pending,
        )
        .toList();
  }

  @override
  Future<Space?> fetchSpaceById(String spaceId) async {
    for (final s in _spaces) {
      if (s.id == spaceId) return s;
    }
    return null;
  }

  @override
  Future<List<SpaceMember>> fetchSpaceMembers(String spaceId) async {
    return _members.where((m) => m.spaceId == spaceId).toList();
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

  @override
  Future<Money> fetchOutstandingDues(String spaceId, String userId) async {
    var total = 0;
    for (final cycle in _cycles) {
      if (cycle.spaceId != spaceId || cycle.status == CycleStatus.closed) {
        continue;
      }
      final expenses = _expenses
          .where((e) => e.spaceId == spaceId && e.cycleId == cycle.id)
          .toList();
      final expenseIds = expenses.map((e) => e.id).toSet();
      final paid = expenses
          .where((e) => e.paidByUserId == userId)
          .fold<int>(0, (a, e) => a + e.amount.paisa);
      final share = _shares
          .where((s) => expenseIds.contains(s.expenseId) && s.userId == userId)
          .fold<int>(0, (a, s) => a + s.amount.paisa);
      final settledOut = _settlements
          .where(
            (s) =>
                s.spaceId == spaceId &&
                s.cycleId == cycle.id &&
                // Only approved settlements count as paid; a pending request
                // never changes the outstanding dues.
                s.status.isSettled &&
                s.fromUserId == userId,
          )
          .fold<int>(0, (a, e) => a + e.amount.paisa);
      final settledIn = _settlements
          .where(
            (s) =>
                s.spaceId == spaceId &&
                s.cycleId == cycle.id &&
                s.status.isSettled &&
                s.toUserId == userId,
          )
          .fold<int>(0, (a, e) => a + e.amount.paisa);

      // Hissa income lowers the dues: everyone benefits by their split
      // of it, and whoever received the cash holds it for the hissa.
      var incomeShare = 0;
      var incomeReceived = 0;
      for (final income in _hissaIncomes) {
        if (income.spaceId != spaceId || income.cycleId != cycle.id) continue;
        if (income.receivedByUserId == userId) {
          incomeReceived += income.amount.paisa;
        }
        final benefitShares = SplitCalculator.build(
          expenseId: income.id,
          amount: income.amount,
          participantIds: income.participantIds,
          type: income.splitType,
          percentages: income.percentages,
          customAmounts: income.customAmounts,
          shareUnits: income.shareUnits,
        );
        incomeShare += benefitShares
            .where((s) => s.participantId == userId)
            .fold<int>(0, (a, s) => a + s.amount.paisa);
      }

      total +=
          paid - share + settledOut - settledIn + incomeShare - incomeReceived;
    }
    return Money(total);
  }

  @override
  Future<void> deleteSpace(String spaceId) async {
    _spaces.removeWhere((s) => s.id == spaceId);
    _members.removeWhere((m) => m.spaceId == spaceId);
    _cycles.removeWhere((c) => c.spaceId == spaceId);
    final expenseIds = _expenses
        .where((e) => e.spaceId == spaceId)
        .map((e) => e.id)
        .toSet();
    _expenses.removeWhere((e) => e.spaceId == spaceId);
    _shares.removeWhere((s) => expenseIds.contains(s.expenseId));
    _settlements.removeWhere((s) => s.spaceId == spaceId);
    _hissaIncomes.removeWhere((i) => i.spaceId == spaceId);
    _estimatedExpenses.removeWhere((e) => e.spaceId == spaceId);
    _categories.removeWhere((c) => c.spaceId == spaceId);
    final groupIds = _memberGroups
        .where((g) => g.spaceId == spaceId)
        .map((g) => g.id)
        .toSet();
    _memberGroups.removeWhere((g) => g.spaceId == spaceId);
    _memberGroupMembers.removeWhere((m) => groupIds.contains(m.groupId));
    _groupRequests.removeWhere((r) => r.spaceId == spaceId);
    _spaceJoinRequests.removeWhere((r) => r.spaceId == spaceId);
  }
}
