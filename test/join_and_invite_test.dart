import 'package:flutter_test/flutter_test.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppState state;

  setUp(() async {
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
        id: 'u_out',
        name: 'Alex',
        email: 'alex@example.com',
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
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
  });

  test('inviteMember adds a member with an invite email and requester marker',
      () async {
    final ok = await state.inviteMember('new.person@example.com');
    expect(ok, isTrue);

    final member = state.members.where((m) => m.invitedEmail != null).single;
    expect(member.name, 'New Person');
    expect(member.invitedEmail, 'new.person@example.com');
    expect(member.invitedByUserId, 'u_owner');

    final invited = state.repo.users
        .where((u) => u.email == 'new.person@example.com')
        .single;
    expect(invited.name, 'New Person');
  });

  test('inviteMember rejects an email already belonging to a member', () async {
    expect(await state.inviteMember('alex@example.com'), isTrue);
    // The same address cannot be invited twice.
    expect(await state.inviteMember('alex@example.com'), isFalse);
    // A member's own address cannot be invited.
    expect(await state.inviteMember('owner@example.com'), isFalse);
  });

  test('requestSpaceJoin reports a missing invite code', () async {
    expect(
      await state.requestSpaceJoin('ZZZZZZ'),
      SpaceJoinOutcome.spaceNotFound,
    );
  });

  test('requestSpaceJoin opens the space directly for an existing member',
      () async {
    final outcome = await state.requestSpaceJoin('ABC12');
    expect(outcome, SpaceJoinOutcome.alreadyMember);
  });

  test('a non-member requesting a space creates a pending request', () async {
    state.debugSetSession(userId: 'u_out', spaceId: null);

    final outcome = await state.requestSpaceJoin('ABC12');
    expect(outcome, SpaceJoinOutcome.requestCreated);

    final request = state.repo.spaceJoinRequests.single;
    expect(request.spaceId, 'h1');
    expect(request.requesterUserId, 'u_out');
    expect(request.requesterName, 'Alex');
    expect(request.status, SpaceJoinRequestStatus.pending);
  });

  test('re-requesting while a request is pending keeps the pending state',
      () async {
    state.debugSetSession(userId: 'u_out', spaceId: null);
    expect(
      await state.requestSpaceJoin('ABC12'),
      SpaceJoinOutcome.requestCreated,
    );
    expect(
      await state.requestSpaceJoin('ABC12'),
      SpaceJoinOutcome.requestPending,
    );
    expect(state.repo.spaceJoinRequests, hasLength(1));
  });

  test('the owner approving a join request adds the requester as a member',
      () async {
    state.debugSetSession(userId: 'u_out', spaceId: null);
    await state.requestSpaceJoin('ABC12');
    final requestId = state.repo.spaceJoinRequests.single.id;

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.approveSpaceJoinRequest(requestId);

    expect(state.members.any((m) => m.userId == 'u_out'), isTrue);
    expect(state.pendingSpaceJoinRequests, isEmpty);
    expect(
      state.repo.spaceJoinRequests.single.status,
      SpaceJoinRequestStatus.approved,
    );
  });

  test('a non-owner cannot approve a join request', () async {
    state.debugSetSession(userId: 'u_out', spaceId: null);
    await state.requestSpaceJoin('ABC12');
    final requestId = state.repo.spaceJoinRequests.single.id;

    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.approveSpaceJoinRequest(requestId);

    expect(state.members.any((m) => m.userId == 'u_out'), isFalse);
    expect(
      state.repo.spaceJoinRequests.single.status,
      SpaceJoinRequestStatus.pending,
    );
  });

  test('the owner can reject a join request', () async {
    state.debugSetSession(userId: 'u_out', spaceId: null);
    await state.requestSpaceJoin('ABC12');
    final requestId = state.repo.spaceJoinRequests.single.id;

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.rejectSpaceJoinRequest(requestId);

    expect(state.members.any((m) => m.userId == 'u_out'), isFalse);
    expect(state.pendingSpaceJoinRequests, isEmpty);
    expect(
      state.repo.spaceJoinRequests.single.status,
      SpaceJoinRequestStatus.rejected,
    );
  });
}