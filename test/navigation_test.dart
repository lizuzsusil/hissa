import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/shell_screen.dart';
import 'package:hissa/ui/screens/spaces_dashboard_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Phase 8 — Navigation tests: the shell exposes mode-appropriate tabs and
/// the Spaces dashboard never auto-redirects into Create/Join.
void main() {
  Future<AppState> makeState({required SpaceMode mode}) async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: mode == SpaceMode.solo ? 'Me' : 'My Space',
        currency: 'NPR',
        inviteCode: 'ABC12',
        mode: mode,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u1',
        name: 'Ram',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    if (mode != SpaceMode.solo) {
      await repo.saveCycle(
        Cycle(
          id: 'c1',
          householdId: 'h1',
          name: 'January 2026',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          status: CycleStatus.active,
        ),
      );
    }
    state.debugSetSession(userId: 'u1', spaceId: 'h1');
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

  testWidgets('split mode exposes settle and insights tabs', (tester) async {
    final state = await makeState(mode: SpaceMode.split);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Settle'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('personal mode does not expose settlement', (tester) async {
    final state = await makeState(mode: SpaceMode.solo);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Settle'), findsNothing);
    expect(find.text('Insights'), findsNothing);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('spaces dashboard shows empty state with create/join actions',
      (tester) async {
    final state = await makeState(mode: SpaceMode.split);
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
    await tester.pump();

    expect(find.text('My Spaces'), findsOneWidget);
    // The empty state lists the explicit Create / Join actions only.
    expect(find.text('No spaces yet'), findsOneWidget);
    expect(find.text('Create Space'), findsOneWidget);
    expect(find.text('Join Space'), findsOneWidget);
  });
}