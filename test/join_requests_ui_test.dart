import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/pending_join_screen.dart';
import 'package:hissa/ui/screens/setup_screen.dart';
import 'package:hissa/ui/screens/space_screen.dart';
import 'package:hissa/ui/screens/spaces_dashboard_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';
import 'package:hissa/ui/widgets/buttons.dart';

/// Space join request UI rules: the Space owner sees pending requests with
/// Approve/Reject in Space → Members, non-owners never see them, and a
/// requester is kept in a pending state on the join screen until approved.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState({String userId = 'u_owner'}) async {
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
    state.debugSetSession(userId: userId, spaceId: 'h1');
    return state;
  }

  Future<void> seedPendingRequest(AppState state) async {
    await state.repo.saveSpaceJoinRequest(
      SpaceJoinRequest(
        id: 'j1',
        spaceId: 'h1',
        requesterUserId: 'u_out',
        requesterName: 'Alex',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  Widget appHarness(AppState state, Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider(create: (_) => ThemeModeController()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider(create: (_) => BiometricAuthController()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );
  }

  testWidgets('space owner sees pending join requests with approve/reject', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(userId: 'u_owner');
    await seedPendingRequest(state);

    await tester.pumpWidget(appHarness(state, const SpaceScreen()));
    await tester.pump();

    expect(find.text('Pending join requests'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('wants to join this space'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets(
    'approving a join request adds the member and clears the request',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState(userId: 'u_owner');
      await seedPendingRequest(state);

      await tester.pumpWidget(appHarness(state, const SpaceScreen()));
      await tester.pump();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Pending join requests'), findsNothing);
      expect(
        state.repo.spaceJoinRequests.single.status,
        SpaceJoinRequestStatus.approved,
      );
      expect(state.members.any((m) => m.userId == 'u_out'), isTrue);
    },
  );

  testWidgets('non-owner never sees the pending join requests section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(userId: 'u_b');
    await seedPendingRequest(state);

    await tester.pumpWidget(appHarness(state, const SpaceScreen()));
    await tester.pump();

    expect(find.text('Pending join requests'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('requester is kept in a pending state on the join screen', (
    tester,
  ) async {
    final state = await makeState(userId: 'u_out');
    state.debugSetSession(userId: 'u_out', spaceId: null);

    var done = false;
    await tester.pumpWidget(
      appHarness(
        state,
        SetupScreen(
          initialCreateMode: false,
          onDone: () => done = true,
          onBack: null,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'ABCD12');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: true);
    await tester.pumpAndSettle();

    // Stuck in the pending state: the Space name is shown but the user cannot
    // enter, so onDone is never invoked.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    expect(done, isFalse);
    expect(
      state.repo.spaceJoinRequests.single.status,
      SpaceJoinRequestStatus.pending,
    );
  });

  testWidgets(
    'join screen keeps pending requests for multiple spaces visible',
    (tester) async {
      final state = await makeState(userId: 'u_out');
      state.debugSetSession(userId: 'u_out', spaceId: null);
      await state.repo.saveSpace(
        Space(
          id: 'h2',
          name: 'Villa',
          currency: 'NPR',
          inviteCode: 'XYZW78',
          mode: SpaceMode.split,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      var done = false;
      await tester.pumpWidget(
        appHarness(
          state,
          SetupScreen(
            initialCreateMode: false,
            onDone: () => done = true,
            onBack: null,
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'ABCD12');
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      // A second request: the input stays available and the new pending card is
      // added next to the first instead of replacing it.
      await tester.enterText(find.byType(TextField), 'XYZW78');
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Villa'), findsOneWidget);
      expect(find.text('Pending approval'), findsNWidgets(2));
      expect(done, isFalse);
    },
  );

  testWidgets('pull to refresh removes a resolved join request', (
    tester,
  ) async {
    final state = await makeState(userId: 'u_out');
    state.debugSetSession(userId: 'u_out', spaceId: null);

    var done = false;
    await tester.pumpWidget(
      appHarness(
        state,
        SetupScreen(
          initialCreateMode: false,
          onDone: () => done = true,
          onBack: null,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'ABCD12');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    // The owner rejects the request while the requester is on the join screen.
    final requestId = state.repo.spaceJoinRequests.single.id;
    await state.repo.updateSpaceJoinRequestStatus(
      requestId,
      SpaceJoinRequestStatus.rejected,
    );

    // Pull to refresh re-queries Firestore and clears the resolved request.
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    expect(find.text('Pending approval'), findsNothing);
    expect(done, isFalse);
  });

  testWidgets('a pending space is not a member space and cannot be opened', (
    tester,
  ) async {
    final state = await makeState(userId: 'u_out');
    state.debugSetSession(userId: 'u_out', spaceId: null);

    await state.requestSpaceJoin('ABCD12');
    await state.refreshPendingSpaceJoinRequests();

    // The requested Space is tracked as pending, but never as a member Space.
    expect(state.pendingSpaces.map((s) => s.id), contains('h1'));
    expect(state.spaces.where((s) => s.id == 'h1'), isEmpty);

    // selectSpace refuses to open a pending Space.
    await state.selectSpace('h1');
    expect(state.space?.id, isNot('h1'));
    expect(state.isPendingSpace('h1'), isTrue);
  });

  testWidgets('spaces dashboard shows the requested Space but never opens it',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(userId: 'u_out');
    state.debugSetSession(userId: 'u_out', spaceId: null);
    await state.requestSpaceJoin('ABCD12');

    var selected = false;
    await tester.pumpWidget(
      appHarness(
        state,
        SpacesDashboardScreen(
          onSelect: (_) => selected = true,
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The pending Space shows with its name and the approval notice.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);

    // Tapping the pending card must not enter the Space.
    await tester.tap(find.byKey(const ValueKey('pending_space_h1')));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(state.space?.id, isNot('h1'));
  });

  testWidgets(
    'approving the request moves the Space from pending into member spaces '
    'on refresh',
    (tester) async {
      final state = await makeState(userId: 'u_out');
      state.debugSetSession(userId: 'u_out', spaceId: null);

      await state.requestSpaceJoin('ABCD12');
      await state.refreshPendingSpaceJoinRequests();
      expect(state.isPendingSpace('h1'), isTrue);

      // The owner approves and grants membership.
      final requestId = state.repo.spaceJoinRequests.single.id;
      await state.repo.updateSpaceJoinRequestStatus(
        requestId,
        SpaceJoinRequestStatus.approved,
      );
      await state.repo.saveMember(
        SpaceMember(
          userId: 'u_out',
          name: 'Alex',
          role: MemberRole.member,
          joinedAt: DateTime(2026, 1, 2),
          spaceId: 'h1',
        ),
        'h1',
      );

      await state.refreshPendingSpaceJoinRequests();

      // No longer pending, and now a member Space the user can open.
      expect(state.isPendingSpace('h1'), isFalse);
      expect(state.spaces.map((s) => s.id), contains('h1'));
      expect(state.pendingSpaces, isEmpty);
    },
  );

  testWidgets('pull to refresh on the dashboard surfaces a newly approved Space',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(userId: 'u_out');
    state.debugSetSession(userId: 'u_out', spaceId: null);
    await state.requestSpaceJoin('ABCD12');

    var selected = false;
    await tester.pumpWidget(
      appHarness(
        state,
        SpacesDashboardScreen(
          onSelect: (_) => selected = true,
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending_space_h1')), findsOneWidget);

    // The owner approves and grants membership while the user is on the
    // dashboard.
    final requestId = state.repo.spaceJoinRequests.single.id;
    await state.repo.updateSpaceJoinRequestStatus(
      requestId,
      SpaceJoinRequestStatus.approved,
    );
    await state.repo.saveMember(
      SpaceMember(
        userId: 'u_out',
        name: 'Alex',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 2),
        spaceId: 'h1',
      ),
      'h1',
    );

    // Pull to refresh re-queries membership + pending requests.
    await tester.fling(find.byType(ListView), const Offset(0, 1000), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsNothing);
    expect(find.byKey(const ValueKey('pending_space_h1')), findsNothing);

    // The approved Space is now a normal, tappable member card.
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
  });

  testWidgets(
    'the pending screen shows the awaiting-approval state and stays put '
    'while the request is unresolved',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState(userId: 'u_out');
      state.debugSetSession(userId: 'u_out', spaceId: null);
      await state.requestSpaceJoin('ABCD12');
      await state.refreshPendingSpaceJoinRequests();

      await tester.pumpWidget(
        appHarness(state, const PendingJoinScreen(spaceId: 'h1')),
      );
      await tester.pumpAndSettle();

      // The requester sees the Space name, the pending chip and the
      // awaiting-approval description — never the Space contents.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Pending approval'), findsOneWidget);
      expect(
        find.textContaining('Your request to join this space is pending'),
        findsOneWidget,
      );
      expect(state.space?.id, isNot('h1'));

      // Pull to refresh while the request is still pending re-checks the
      // request and keeps the pending screen (no crash, no navigation).
      await tester.fling(find.byType(ListView), const Offset(0, 1000), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Pending approval'), findsOneWidget);
      expect(state.space?.id, isNot('h1'));
      expect(state.isPendingSpace('h1'), isTrue);
    },
  );
}
