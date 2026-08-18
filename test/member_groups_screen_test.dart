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
import 'package:hissa/ui/screens/member_groups_screen.dart';
import 'package:hissa/ui/screens/space_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Member Groups UI rules: only the Space owner sees Approve/Reject, the
/// requester sees a clear "Pending approval" status, and the feature lives
/// inside the Space → Members section.
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
    for (final u in ['u_b', 'u_c', 'u_d']) {
      await repo.saveMember(
        SpaceMember(
          userId: u,
          name: u == 'u_b'
              ? 'B'
              : u == 'u_c'
                  ? 'C'
                  : 'D',
          role: MemberRole.member,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );
    }
    state.debugSetSession(userId: userId, spaceId: 'h1');
    return state;
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

  testWidgets('requester sees pending approval and no approve/reject actions',
      (tester) async {
    final state = await makeState(userId: 'u_b');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);

    await tester.pumpWidget(appHarness(state, const MemberGroupsScreen()));
    await tester.pump();

    expect(find.text('Pending approval'), findsOneWidget);
    expect(
      find.text(
        'Your group request is pending approval. You\'ll be notified once the space owner decides.',
      ),
      findsOneWidget,
    );
    // The requester is not the owner, so the actions are hidden everywhere.
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('space owner sees approve and reject for pending requests',
      (tester) async {
    final state = await makeState(userId: 'u_owner');
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.requestGroup(['u_c']);
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await tester.pumpWidget(appHarness(state, const MemberGroupsScreen()));
    await tester.pump();

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('approving a request updates the UI to show the new group',
      (tester) async {
    final state = await makeState(userId: 'u_owner');
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.requestGroup(['u_c']);
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await tester.pumpWidget(appHarness(state, const MemberGroupsScreen()));
    await tester.pump();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    // The request is resolved: no pending card, and the group now exists.
    expect(find.text('Pending approval'), findsNothing);
    expect(find.text("B's Group"), findsOneWidget);
  });

  testWidgets('rejecting a request clears the pending state for the requester',
      (tester) async {
    final state = await makeState(userId: 'u_owner');
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final request = await state.requestGroup(['u_c']);
    expect(request, isNotNull);
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await tester.pumpWidget(appHarness(state, const MemberGroupsScreen()));
    await tester.pump();

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    // The request is no longer pending and no group was created.
    expect(find.text('Pending approval'), findsNothing);
    expect(state.pendingGroupRequests, isEmpty);

    // The requester can now request again.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    expect(state.hasPendingGroupRequest('u_b'), isFalse);
    expect(state.canRequestGroup, isTrue);
  });

  testWidgets('member groups is reachable from the space members section',
      (tester) async {
    final state = await makeState(userId: 'u_owner');

    // Use a tall viewport so the lazily-built ListView includes the Member
    // Groups tile at the bottom of the members section.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(appHarness(state, const SpaceScreen()));
    await tester.pump();

    expect(find.text('Member Groups'), findsOneWidget);

    await tester.tap(find.text('Member Groups'));
    await tester.pumpAndSettle();

    expect(find.text('No member groups yet'), findsOneWidget);
  });
}
