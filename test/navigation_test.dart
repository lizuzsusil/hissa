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
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState({required SpaceMode mode}) async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: mode == SpaceMode.personal ? 'Me' : 'My Space',
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
    if (mode != SpaceMode.personal) {
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

  testWidgets('personal mode exposes insights but not settlement', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Settle'), findsNothing);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('personal insights tab shows spending breakdown, not cycles', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
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

  testWidgets('personal dashboard shows quick actions and planned amounts', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    await state.addEstimatedExpense(
      description: 'Rent',
      amount: const Money(1500000),
      month: month,
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Add estimate'), findsOneWidget);
    expect(find.text('Estimated expenses'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    // Planned amounts are kept visually distinct from real expenses.
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('personal insights offers period and granularity filters', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: DateTime(2026, 1, 12),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Spending overview'), findsOneWidget);
    // Period scope toggle.
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    // Granularity filter.
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Category breakdown'), findsOneWidget);
  });

  testWidgets('personal insights chart renders with same-day expenses', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: DateTime.now(),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Spending overview'), findsOneWidget);
    // Same-day spending must produce chart bars, not the empty state.
    expect(find.text('Nothing to chart yet'), findsNothing);
  });

  testWidgets('personal dashboard fits narrow screens without overflow', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    await state.addEstimatedExpense(
      description: 'Rent',
      amount: const Money(1500000),
      month: month,
    );
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Add estimate'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('estimated spending form is simplified to amount only', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Add estimate'));
    await tester.pumpAndSettle();

    expect(find.text('Estimated spending amount'), findsOneWidget);
    // Description, category and date picker are intentionally not part of the
    // planned-amount form.
    expect(find.text('What are you planning for?'), findsNothing);
    expect(find.text('Date'), findsNothing);
    expect(find.text('Category'), findsNothing);
    expect(find.text('Save estimate'), findsOneWidget);
  });

  testWidgets('spaces dashboard shows empty state with create/join actions', (
    tester,
  ) async {
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
