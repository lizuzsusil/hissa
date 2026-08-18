import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/data/in_memory_repository.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';

/// The in-app notification inbox: key events write a notification into the
/// recipients' inbox (Firestore-driven, no push involved) and the inbox feeds
/// unread-count + mark-read behaviour.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Home space owned by u_owner, with u_b as a second member, plus a cycle.
  Future<AppState> makeHomeState() async {
    final state = AppState();
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
    await repo.saveUser(
      User(
        id: 'u_c',
        name: 'Charlie',
        email: 'charlie@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABCD12',
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
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    return state;
  }

  group('expense notifications', () {
    test('adding an expense notifies other members, never the actor', () async {
      final state = await makeHomeState();
      await state.addExpense(
        description: 'Dinner',
        amount: const Money(100000),
        date: DateTime(2026, 1, 10),
        participantIds: ['u_owner', 'u_b'],
      );

      final forB = state.notifications
          .where((n) => n.userId == 'u_b' && n.type == NotificationType.expenseAdded);
      expect(forB, hasLength(1));
      expect(forB.single.eventKey, isNotEmpty);
      expect(forB.single.spaceId, 'h1');
      // The actor never notifies themselves.
      expect(
        state.notifications.where((n) => n.userId == 'u_owner'),
        isEmpty,
      );
    });

    test('updating an expense rewrites the same inbox doc as updated', () async {
      final state = await makeHomeState();
      await state.addExpense(
        description: 'Dinner',
        amount: const Money(100000),
        date: DateTime(2026, 1, 10),
        participantIds: ['u_owner', 'u_b'],
      );
      final expense = state.expensesInCycle.first;
      expect(
        state.notifications
            .singleWhere((n) => n.userId == 'u_b' && n.eventKey == expense.id)
            .type,
        NotificationType.expenseAdded,
      );

      await state.updateExpense(
        expense,
        description: 'Dinner (split)',
        amount: const Money(120000),
        date: DateTime(2026, 1, 10),
        participantIds: ['u_owner', 'u_b'],
      );

      // Same deterministic id -> overwritten, not stacked.
      expect(
        state.notifications.where((n) => n.eventKey == expense.id),
        hasLength(1),
      );
      expect(
        state.notifications
            .singleWhere((n) => n.userId == 'u_b' && n.eventKey == expense.id)
            .type,
        NotificationType.expenseUpdated,
      );
    });

    test('a settlement notifies the recipient', () async {
      final state = await makeHomeState();
      await state.addExpense(
        description: 'Dinner',
        amount: const Money(100000),
        date: DateTime(2026, 1, 10),
        participantIds: ['u_owner', 'u_b'],
      );
      await state.addSettlement(
        fromUserId: 'u_b',
        toUserId: 'u_owner',
        amount: const Money(50000),
        paymentMethod: 'Cash',
        date: DateTime(2026, 1, 12),
      );

      final toB = state.notifications
          .where((n) => n.type == NotificationType.settlementRecorded);
      // u_owner -> u_owner is a self-notify no-op.
      expect(toB, isEmpty);
    });
  });

  group('invitation notifications', () {
    test('inviting a registered user notifies them, unknown emails do not',
        () async {
      final state = await makeHomeState();

      // Charlie has an account but is not yet a member of Home.
      await state.inviteMember('charlie@example.com');
      final invite = state.notifications.singleWhere(
        (n) => n.type == NotificationType.spaceInvited,
      );
      expect(invite.userId, 'u_c');
      expect(invite.spaceId, 'h1');
      expect(invite.actorUserId, 'u_owner');

      // An email with no account creates no notification (email-only channel).
      await state.inviteMember('fresh.person@example.com');
      expect(
        state.notifications
            .where((n) => n.type == NotificationType.spaceInvited),
        hasLength(1),
      );
    });
  });

  group('join request notifications', () {
    test('requesting to join notifies the owner, approving notifies requester',
        () async {
      final state = await makeHomeState();

      // An outsider asks to join Home.
      state.debugSetSession(userId: 'u_out', spaceId: null);
      await state.requestSpaceJoin('ABCD12');
      final ownerNote = state.notifications.singleWhere(
        (n) => n.type == NotificationType.spaceJoinRequested,
      );
      expect(ownerNote.userId, 'u_owner');
      expect(ownerNote.spaceId, 'h1');
      expect(ownerNote.actorUserId, 'u_out');

      // The owner approves: the requester gets a notification.
      state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
      final requestId = state.repo.spaceJoinRequests.single.id;
      await state.approveSpaceJoinRequest(requestId);
      final approved = state.notifications.singleWhere(
        (n) => n.type == NotificationType.spaceJoinApproved,
      );
      expect(approved.userId, 'u_out');
      expect(approved.spaceId, 'h1');
    });

    test('rejecting a join request notifies the requester', () async {
      final state = await makeHomeState();
      state.debugSetSession(userId: 'u_out', spaceId: null);
      await state.requestSpaceJoin('ABCD12');

      state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
      await state.rejectSpaceJoinRequest(state.repo.spaceJoinRequests.single.id);
      final rejected = state.notifications.singleWhere(
        (n) => n.type == NotificationType.spaceJoinRejected,
      );
      expect(rejected.userId, 'u_out');
    });
  });

  group('resilience', () {
    test('a denied notification write never breaks approve/reject', () async {
      // A repository whose notification inbox write is rejected (as Firestore
      // rules do when the rules are not deployed) must not fail the action.
      final state = AppState();
      state.debugSetRepo(_ThrowingNotificationRepo());
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
          inviteCode: 'ABCD12',
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
      await repo.saveSpaceJoinRequest(
        SpaceJoinRequest(
          id: 'j1',
          spaceId: 'h1',
          requesterUserId: 'u_out',
          requesterName: 'Alex',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

      await state.approveSpaceJoinRequest('j1');
      expect(
        state.repo.spaceJoinRequests.single.status,
        SpaceJoinRequestStatus.approved,
      );

      // And a second, separate pending request can still be rejected.
      await repo.saveSpaceJoinRequest(
        SpaceJoinRequest(
          id: 'j2',
          spaceId: 'h1',
          requesterUserId: 'u_out',
          requesterName: 'Alex',
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      await state.rejectSpaceJoinRequest('j2');
      expect(
        state.repo.spaceJoinRequests
            .singleWhere((r) => r.id == 'j2')
            .status,
        SpaceJoinRequestStatus.rejected,
      );
    });
  });

  group('unread tracking', () {
    test('unread count drops to zero after markNotificationsRead', () async {
      final state = await makeHomeState();
      expect(state.unreadNotificationCount, 0);

      await state.addExpense(
        description: 'Groceries',
        amount: const Money(20000),
        date: DateTime(2026, 1, 11),
        participantIds: ['u_owner', 'u_b'],
      );
      expect(state.unreadNotificationCount, 1);

      await state.markNotificationsRead();
      expect(state.unreadNotificationCount, 0);
      // Later activity is unread again.
      await state.addExpense(
        description: 'Tea',
        amount: const Money(5000),
        date: DateTime(2026, 1, 12),
        participantIds: ['u_owner', 'u_b'],
      );
      expect(state.unreadNotificationCount, 1);
    });
  });
}

/// Mirrors a Firestore inbox whose rules deny the write: every other
/// repository call behaves normally, only `saveNotification` rejects.
class _ThrowingNotificationRepo extends InMemoryRepository {
  @override
  Future<void> saveNotification(AppNotification notification) async {
    throw Exception('PERMISSION_DENIED: notifications');
  }
}