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
import 'package:hissa/ui/screens/spaces_dashboard_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Default Space behaviour: a user with a single Space auto-enters it, a
/// multi-Space user can mark one Space as the default ("open by default next
/// time") and the dashboard exposes a per-card toggle to set/clear it.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState({required List<String> spaceIds}) async {
    final state = AppState();
    final repo = state.repo;
    var n = 0;
    for (final id in spaceIds) {
      n++;
      await repo.saveSpace(
        Space(
          id: id,
          name: 'Space $n',
          currency: 'NPR',
          inviteCode: 'ABC${(n + 10)}12',
          mode: SpaceMode.split,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'Ram',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: id,
        ),
        id,
      );
    }
    state.debugSetSession(userId: 'u1', spaceId: null);
    await state.refreshSpaces();
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

  testWidgets('a user with a single Space auto-lands on that Space', (
    tester,
  ) async {
    final state = await makeState(spaceIds: ['h1']);
    expect(state.spaces, hasLength(1));
    expect(state.launchSpace?.id, 'h1');
  });

  testWidgets('multi-Space user with no default lands on the dashboard', (
    tester,
  ) async {
    final state = await makeState(spaceIds: ['h1', 'h2']);
    expect(state.launchSpace, isNull);
  });

  testWidgets('multi-Space user with a default lands on the default Space', (
    tester,
  ) async {
    final state = await makeState(spaceIds: ['h1', 'h2']);
    await state.setDefaultSpace('h2');
    expect(state.launchSpace?.id, 'h2');
  });

  testWidgets('setDefaultSpace persists and rejects non-member Spaces', (
    tester,
  ) async {
    final state = await makeState(spaceIds: ['h1', 'h2']);

    await state.setDefaultSpace('h2');
    expect(state.defaultSpaceId, 'h2');

    // Persisted in the session blob.
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString('hissa_session_v1');
    expect(raw, contains('"defaultSpaceId":"h2"'));

    // A Space the user does not belong to is never set.
    await state.setDefaultSpace('nope');
    expect(state.defaultSpaceId, 'h2');

    // Clearing works.
    await state.setDefaultSpace(null);
    expect(state.defaultSpaceId, isNull);
  });

  testWidgets('the default Space is stored on the user profile in the '
      'repository so it survives a fresh login', (tester) async {
    final state = await makeState(spaceIds: ['h1', 'h2']);
    await state.repo.saveUser(
      User(
        id: 'u1',
        name: 'Ram',
        email: 'ram@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    await state.setDefaultSpace('h2');
    final saved = state.repo.users.singleWhere((u) => u.id == 'u1');
    expect(saved.defaultSpaceId, 'h2');

    // Clearing the preference also clears the stored profile value.
    await state.setDefaultSpace(null);
    expect(state.repo.users.singleWhere((u) => u.id == 'u1').defaultSpaceId,
        isNull);
  });

  testWidgets('a fresh login routes directly to the profile-stored default '
      'Space', (tester) async {
    // A brand-new session (no local blob) whose repository holds the user
    // profile written by the previous session.
    final state = AppState();
    await state.repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Space 1',
        currency: 'NPR',
        inviteCode: 'ABCD12',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await state.repo.saveSpace(
      Space(
        id: 'h2',
        name: 'Space 2',
        currency: 'NPR',
        inviteCode: 'ABCD13',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    for (final id in ['h1', 'h2']) {
      await state.repo.saveMember(
        SpaceMember(
          userId: 'u1',
          name: 'Ram',
          role: MemberRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
        id,
      );
    }
    await state.repo.saveUser(
      User(
        id: 'u1',
        name: 'Ram',
        email: 'ram@example.com',
        defaultSpaceId: 'h2',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    state.debugSetSession(userId: 'u1');
    await state.refreshSpaces();

    // The attach step loads the preference from the profile (DB source of
    // truth) and the user is routed into their chosen Space.
    expect(state.defaultSpaceId, isNull);
    state.syncDefaultSpaceFromProfile();
    expect(state.defaultSpaceId, 'h2');
    expect(state.launchSpace?.id, 'h2');
  });

  testWidgets('the dashboard toggles a default Space and shows a confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(spaceIds: ['h1', 'h2']);
    await tester.pumpWidget(
      appHarness(
        state,
        SpacesDashboardScreen(
          onSelect: (_) {},
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both cards expose the "open by default" toggle; none is default yet.
    expect(find.byKey(const ValueKey('default_toggle_h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('default_toggle_h2')), findsOneWidget);
    expect(state.defaultSpaceId, isNull);

    // Mark Space 2 as the default.
    await tester.tap(find.byKey(const ValueKey('default_toggle_h2')));
    await tester.pumpAndSettle();
    expect(state.defaultSpaceId, 'h2');
    expect(find.text('Space 2 will open by default next time'), findsOneWidget);

    // Tapping again clears the default.
    await tester.tap(find.byKey(const ValueKey('default_toggle_h2')));
    await tester.pumpAndSettle();
    expect(state.defaultSpaceId, isNull);
  });

  testWidgets('no default toggle is shown when the user has a single Space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(spaceIds: ['h1']);
    await tester.pumpWidget(
      appHarness(
        state,
        SpacesDashboardScreen(
          onSelect: (_) {},
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Space 1'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('space cards fit a narrow screen with the default toggle', (
    tester,
  ) async {
    // Narrow phone: the mode chip + member count + star toggle must all fit
    // without overflowing. The width is chosen so the pre-fix layout (fixed
    // member-count text) overflowed while the ellipsized layout fits.
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState(spaceIds: ['h1', 'h2']);
    await state.setDefaultSpace('h1');
    await tester.pumpWidget(
      appHarness(
        state,
        SpacesDashboardScreen(
          onSelect: (_) {},
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('default_toggle_h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('default_toggle_h2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}