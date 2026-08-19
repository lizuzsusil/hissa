import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/core/money.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    state = AppState();
    final repo = state.repo;
    await repo.saveUser(
      User(
        id: 'u_owner',
        name: 'Owner',
        email: 'owner@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_b',
        name: 'B',
        email: 'b@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_c',
        name: 'C',
        email: 'c@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_d',
        name: 'D',
        email: 'd@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABC12',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_owner',
        name: 'Owner',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_b',
        name: 'B',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_c',
        name: 'C',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_d',
        name: 'D',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
  });

  test('memberGroupsApplicable is false for a two-member space', () async {
    // The setUp space has 4 members, so groups are applicable.
    expect(state.memberGroupsApplicable, isTrue);

    // Remove down to two members.
    final repo = state.repo;
    await repo.removeMember('u_c', 'h1');
    await repo.removeMember('u_d', 'h1');
    expect(state.members.length, 2);
    expect(state.memberGroupsApplicable, isFalse);
  });

  test('groupedUserIds includes owner and members of an active group', () async {
    final repo = state.repo;
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g1',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g1', 'u_b');

    final ids = state.groupedUserIds;
    expect(ids, contains('u_owner'));
    expect(ids, contains('u_b'));
    expect(ids, isNot(contains('u_c')));
  });

  test('inactive groups are excluded from groupedUserIds', () async {
    final repo = state.repo;
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g1',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g1', 'u_b');

    expect(state.groupedUserIds, isEmpty);
  });

  test('a non-owner can submit a group request and is tracked as pending',
      () async {
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    expect(state.canRequestGroup, isTrue);
    expect(state.pendingGroupRequests, isEmpty);

    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);
    expect(request!.requesterUserId, 'u_b');
    expect(request.memberUserIds, ['u_c']);
    expect(state.hasPendingGroupRequest('u_b'), isTrue);

    // A second request while one is pending is rejected.
    final dup = await state.requestGroup(['u_d']);
    expect(dup, isNull);
  });

  test('the owner cannot request a group for themselves', () async {
    expect(state.canRequestGroup, isFalse);
    final request = await state.requestGroup(['u_b']);
    expect(request, isNull);
  });

  test('the owner can approve a pending request, creating the group', () async {
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final group = await state.approveGroupRequest(request!.id);
    expect(group, isNotNull);
    expect(group!.ownerUserId, 'u_b');

    // The requester becomes the owner and the requested member is added.
    expect(state.activeMemberGroups.any((g) => g.id == group.id), isTrue);
    final members = state.repo.memberGroupMembers
        .where((m) => m.groupId == group.id)
        .map((m) => m.userId)
        .toList();
    expect(members, contains('u_c'));

    // The request is resolved so it no longer shows as pending.
    expect(state.pendingGroupRequests, isEmpty);
  });

  test('a non-owner cannot approve a request', () async {
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    final group = await state.approveGroupRequest(request!.id);
    expect(group, isNull);
    expect(state.pendingGroupRequests, hasLength(1));
  });

  test('a non-owner cannot reject a request', () async {
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    await state.rejectGroupRequest(request!.id);
    expect(state.pendingGroupRequests, hasLength(1));
    expect(
      state.pendingGroupRequests.first.status,
      GroupRequestStatus.pending,
    );
  });

  test('the owner can reject a pending request', () async {
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.rejectGroupRequest(request!.id);
    expect(state.pendingGroupRequests, isEmpty);
  });

  test('the owner can only belong to a single group', () async {
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final repo = state.repo;

    // The owner creates their own group (with themselves).
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g_owner',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g_owner', 'u_b');

    // The owner is now grouped, so they can no longer create another.
    expect(state.groupedUserIds, contains('u_owner'));

    // Requests never include the owner, so approving other requests is still
    // possible while the owner has their own single group.
    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    final request = await state.requestGroup(['u_d']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final group = await state.approveGroupRequest(request!.id);
    expect(group, isNotNull);
    expect(state.pendingGroupRequests, isEmpty);
  });

  test('approving a request whose member is already grouped is rejected',
      () async {
    // u_b is already part of the owner's group.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final repo = state.repo;
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g_owner',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g_owner', 'u_b');

    // u_d requests a group that includes the already-grouped u_b.
    state.debugSetSession(userId: 'u_d', spaceId: 'h1');
    final request = await state.requestGroup(['u_b']);
    expect(request, isNotNull);

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final group = await state.approveGroupRequest(request!.id);
    expect(group, isNull);
    expect(state.pendingGroupRequests, hasLength(1));
  });

  test('max group size is (space members - 1)', () async {
    // The space has 4 members, so a group can hold at most 3 users.
    expect(state.members.length, 4);
    expect(state.maxGroupMembers, 3);
    expect(state.groupMemberSlotsRemaining(0), 2);
    expect(state.groupMemberSlotsRemaining(2), 0);
    expect(state.groupMemberSlotsRemaining(3), -1);
  });

  test('a group request exceeding the max size is rejected', () async {
    // The space has 4 members, so max group size is 3 (requester + 2 others).
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final capped = await state.requestGroup(['u_c', 'u_d']);
    expect(capped, isNotNull);
    expect(capped!.memberUserIds, hasLength(2));

    // A fresh requester claiming 3 others would exceed the cap and be rejected.
    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    final tooLarge = await state.requestGroup(['u_d', 'u_b', 'u_owner']);
    expect(tooLarge, isNull);
  });

  test('non-owner can request a group with remaining users in a 4-member space',
      () async {
    // 4-member space: the owner creates a group with B. C and D stay ungrouped.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final repo = state.repo;
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g_owner',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g_owner', 'u_b');

    // C can request a group with D (both ungrouped).
    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    expect(state.canRequestGroup, isTrue);
    expect(
      state.requestableGroupMembers.map((m) => m.userId),
      ['u_d'],
    );
    final request = await state.requestGroup(['u_d']);
    expect(request, isNotNull);
  });

  test('a lone ungrouped user in a 3-member space cannot request a group',
      () async {
    // Remove D so the space has only 3 members.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final repo = state.repo;
    await repo.removeMember('u_d', 'h1');
    expect(state.members.length, 3);

    // The owner has a group with B; C is the last remaining ungrouped user.
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g_owner',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g_owner', 'u_b');

    // C is alone: no one left to group with, so they cannot request.
    state.debugSetSession(userId: 'u_c', spaceId: 'h1');
    expect(state.requestableGroupMembers, isEmpty);
    expect(state.canRequestGroup, isFalse);
    final request = await state.requestGroup(['u_b']);
    expect(request, isNull);
  });

  test('a group is a single balance and settlement participant', () async {
    // Owner's group: Owner + B. C and D stay ungrouped.
    final repo = state.repo;
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g1',
        spaceId: 'h1',
        ownerUserId: 'u_owner',
        name: "Owner's Group",
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_b'],
      ),
    );
    await repo.addGroupMember('g1', 'u_b');
    await repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: 'January 2026',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );

    // The owner (a group member) pays 90 split equally across the group,
    // C and D.
    await state.addExpense(
      description: 'Dinner',
      amount: const Money(90000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_c', 'u_d'],
      memberGroups: [
        MemberGroup(
          id: 'g1',
          spaceId: 'h1',
          ownerUserId: 'u_owner',
          name: "Owner's Group",
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          memberIds: ['u_b'],
        ),
      ],
      splitType: SplitType.equal,
    );

    final balances = state.computeBalances();
    // Grouped members never surface individually; the group is one entry.
    expect(balances.map((b) => b.userId).toSet(), {'g1', 'u_c', 'u_d'});
    final groupBalance = balances.singleWhere((b) => b.userId == 'g1');
    expect(groupBalance.paid, const Money(90000));
    expect(groupBalance.share, const Money(30000));
    expect(groupBalance.balance, const Money(60000));
    expect(
      balances.singleWhere((b) => b.userId == 'u_c').balance,
      const Money(-30000),
    );

    // Settlements reconcile: C and D each owe the group.
    final proposals = state.settlementProposals();
    final byFrom = {for (final p in proposals) p.fromUserId: p.amount};
    expect(byFrom['u_c'], const Money(30000));
    expect(byFrom['u_d'], const Money(30000));
    expect(
      proposals.fold<int>(0, (sum, p) => sum + p.amount.paisa),
      60000,
    );
  });
}