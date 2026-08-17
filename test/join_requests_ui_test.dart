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
import 'package:hissa/ui/screens/setup_screen.dart';
import 'package:hissa/ui/screens/space_screen.dart';
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

  testWidgets('space owner sees pending join requests with approve/reject',
      (tester) async {
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

  testWidgets('approving a join request adds the member and clears the request',
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
  });

  testWidgets('non-owner never sees the pending join requests section',
      (tester) async {
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

  testWidgets('requester is kept in a pending state on the join screen',
      (tester) async {
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
    expect(state.repo.spaceJoinRequests.single.status,
        SpaceJoinRequestStatus.pending);
  });
}