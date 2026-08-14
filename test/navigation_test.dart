import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

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
          spaceId: 'h1',
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

  testWidgets('personal mode exposes insights but not settlement', (tester) async {
    final state = await makeState(mode: SpaceMode.solo);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Settle'), findsNothing);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('personal insights tab shows spending breakdown, not cycles',
      (tester) async {
    final state = await makeState(mode: SpaceMode.solo);
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: DateTime(2026, 1, 12),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    // Open the Insights tab (index 2 in the personal shell).
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Category breakdown'), findsOneWidget);
    expect(find.text('Lifetime summary'), findsOneWidget);
    // Cycle-specific UI is absent in personal mode.
    expect(find.text('Select cycle'), findsNothing);
    expect(find.text('Who paid this cycle'), findsNothing);
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