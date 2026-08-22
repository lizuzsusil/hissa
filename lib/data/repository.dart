import '../core/money.dart';
import '../models/models.dart';

/// Persistence boundary. [InMemoryRepository] backs the signed-out placeholder
/// state and unit tests; [FirestoreRepository] persists to Firebase. Read
/// access is synchronous over locally-cached lists so the UI can rebuild
/// eagerly; mutations are async and await the underlying write.
abstract class ExpenseRepository {
  List<User> get users;
  List<Space> get spaces;
  List<SpaceMember> get members;
  List<Cycle> get cycles;
  List<Expense> get expenses;
  List<ExpenseShare> get shares;
  List<Settlement> get settlements;
  List<HissaIncome> get hissaIncomes;
  List<EstimatedExpense> get estimatedExpenses;
  List<Category> get categories;
  List<MemberGroup> get memberGroups;
  List<MemberGroupMember> get memberGroupMembers;
  List<GroupRequest> get groupRequests;
  List<SpaceJoinRequest> get spaceJoinRequests;

  Future<void> saveUser(User user);
  Future<void> saveSpace(Space space);
  Future<void> saveMember(SpaceMember member, [String? spaceId]);
  Future<void> removeMember(String userId, String spaceId);
  Future<void> saveCycle(Cycle cycle);
  Future<void> saveExpense(Expense expense, List<ExpenseShare> shares);
  Future<void> deleteExpense(String expenseId);
  Future<void> addShare(ExpenseShare share);
  Future<void> saveSettlement(Settlement settlement);
  Future<void> saveCategory(Category category);

  /// Persists a Split-space [HissaIncome]. Upserts by id.
  Future<void> saveHissaIncome(HissaIncome income);

  /// Permanently removes a [HissaIncome] by id. Balances are derived, so
  /// no share rows need cleaning up.
  Future<void> deleteHissaIncome(String incomeId);

  /// Persists a Personal-space [EstimatedExpense]. Upserts by id.
  Future<void> saveEstimatedExpense(EstimatedExpense estimate);

  /// Permanently removes an [EstimatedExpense] by id.
  Future<void> deleteEstimatedExpense(String estimateId);

  /// Creates a Member Group owned by [ownerUserId]. Group members must already
  /// belong to [spaceId]; the owner is always implied and never stored as a
  /// member row.
  Future<void> saveMemberGroup(MemberGroup group);

  /// Adds [userId] to [groupId]. The user must be a member of the group's
  /// Space and must not already belong to the group.
  Future<void> addGroupMember(String groupId, String userId);

  /// Removes [userId] from [groupId]. Removing the owner is rejected.
  Future<void> removeGroupMember(String groupId, String userId);

  /// Records a non-owner's request to create a Member Group (Rule 4).
  Future<void> saveGroupRequest(GroupRequest request);

  /// Updates a group creation request's status (owner approves/rejects).
  Future<void> updateGroupRequestStatus(
    String requestId,
    GroupRequestStatus status,
  );

  /// Records a user's request to join a Space with an invite code. Joining is
  /// never immediate: the Space owner must approve the request first.
  Future<void> saveSpaceJoinRequest(SpaceJoinRequest request);

  /// Updates a Space join request's status (Space owner approves/rejects).
  Future<void> updateSpaceJoinRequestStatus(
    String requestId,
    SpaceJoinRequestStatus status,
  );

  /// The still-pending join request for [userId] in [spaceId], if any. Used by
  /// the join screen to keep the requester in a pending state on re-entry.
  Future<SpaceJoinRequest?> findPendingSpaceJoinRequest(
    String spaceId,
    String userId,
  );

  /// Every still-pending join request [userId] has submitted across Spaces.
  /// Unlike [findPendingSpaceJoinRequest] this works even when the user is not
  /// a member of any Space (the join screen scenario), so the join screen can
  /// keep the requester in a persistent pending state for all their requests.
  Future<List<SpaceJoinRequest>> fetchMyPendingSpaceJoinRequests(String userId);

  /// A single Space by id, resolved from the cache or Firestore. Used to show
  /// Space names for pending join requests the user is not a member of yet.
  Future<Space?> fetchSpaceById(String spaceId);

  /// Members of [spaceId], even when that Space is not currently selected.
  /// Used to resolve notification recipients (e.g. the Space owner) from flows
  /// like join requests that run outside an attached Space.
  Future<List<SpaceMember>> fetchSpaceMembers(String spaceId);

  /// Marks [groupId] inactive (deleted) without touching historical expenses.
  Future<void> deleteMemberGroup(String groupId);

  List<ExpenseShare> sharesForExpense(String expenseId);
  List<ExpenseShare> sharesForCycle(List<Expense> expenses);

  Future<Space?> findSpaceByInviteCode(String code);
  Future<String?> findSpaceIdForUser(String userId);

  /// All spaces the user belongs to, used by the Spaces dashboard.
  Future<List<Space>> findSpacesForUser(String userId);

  /// Number of members in a Space, used for the Spaces dashboard card.
  Future<int> countMembers(String spaceId);

  /// Total outstanding balance for [userId] in [spaceId] across every open
  /// cycle, after recorded settlements. A non-zero value means the member has
  /// outstanding dues and must settle before leaving the Space.
  Future<Money> fetchOutstandingDues(String spaceId, String userId);

  /// Permanently deletes [spaceId] and every piece of data scoped to it
  /// (memberships, cycles, expenses, shares, settlements, categories, member
  /// groups and join/group requests). Only the Space owner may call this.
  Future<void> deleteSpace(String spaceId);

  /// Saves a notification to the inbox of [userId]. The writer must be a
  /// co-member of the referenced [spaceId] (or the requester of a pending
  /// join/group request). Notification docs are never deleted by
  /// [deleteSpace].
  Future<void> saveNotification(AppNotification notification);

  /// All notifications for the current user (across all Spaces). Listened to
  /// in real-time from the moment the user signs in, independent of Space
  /// selection. Returns only notifications where [userId] == current user.
  List<AppNotification> get notifications;
}
