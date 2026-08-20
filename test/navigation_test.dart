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
import 'package:hissa/ui/screens/expenses_screen.dart';
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
    // The lifetime summary row is no longer part of the personal insights.
    expect(find.text('Lifetime summary'), findsNothing);
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
    // With a planned amount already set for this month, the quick action
    // switches to "Edit estimate" and no separate estimates list is shown.
    expect(find.text('Edit estimate'), findsOneWidget);
    expect(find.text('Add estimate'), findsNothing);
    expect(find.text('Estimated expenses'), findsNothing);
    // Planned amounts are kept visually distinct from real expenses.
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('personal insights offers a single rolling-window filter', (
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
    // The single filter covers every view level (lifetime is shown below).
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Lifetime'), findsNothing);
    expect(find.text('Category breakdown'), findsOneWidget);
    // The top-categories leaderboard follows the selected window, so an
    // expense from outside the last 6 months is not listed.
    expect(find.text('Top categories'), findsNothing);
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
    // The top-categories leaderboard covers the selected window.
    expect(find.text('Top categories'), findsOneWidget);
  });

  testWidgets('personal insights overlays the planned amount on the chart', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: DateTime.now(),
    );
    await state.addEstimatedExpense(
      description: 'Rent',
      amount: const Money(1500000),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // The month-bucketed view draws the planned amount alongside the actual
    // spending and explains it with a legend.
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('personal insights shows comparison and category sections', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    final now = DateTime.now();
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: now,
    );
    await state.addPersonalExpense(
      description: 'Rent',
      amount: const Money(1500000),
      date: DateTime(now.year, now.month - 1, 5),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // Month-over-month comparison (this + last month both have spending).
    expect(find.text('This month vs last month'), findsOneWidget);
    // All-time category leaderboard is shown; removed sections are absent.
    expect(find.text('Top categories'), findsOneWidget);
    expect(find.text('Spending by day'), findsNothing);
    expect(find.text('Lifetime trend'), findsNothing);
  });

  testWidgets('personal expenses show lifetime summary and inline time filters', (
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

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();

    // Lifetime spending summary sits above the list in personal mode.
    expect(find.text('Lifetime spending'), findsOneWidget);

    // Inline period chips and a date-range action (no filter icon in personal
    // mode — the filter sheet is split-mode only).
    expect(find.byIcon(Icons.date_range_outlined), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ExpensesScreen),
        matching: find.text('All time'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ExpensesScreen),
        matching: find.text('This month'),
      ),
      findsOneWidget,
    );

    // The summary updates with the selected inline filter.
    await tester.tap(
      find.descendant(
        of: find.byType(ExpensesScreen),
        matching: find.text('This month'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lifetime spending'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ExpensesScreen),
        matching: find.text('This month'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('search empty state does not overflow on a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await makeState(mode: SpaceMode.personal);
    await state.addPersonalExpense(
      description: 'Coffee',
      amount: const Money(50000),
      date: DateTime.now(),
    );
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();

    // Search for something that matches nothing.
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching expenses'), findsOneWidget);
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
    // With a planned amount already set, the quick action lets you edit it.
    expect(find.text('Edit estimate'), findsOneWidget);
    expect(find.text('Add estimate'), findsNothing);
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

  testWidgets('add estimate saves a planned amount for the current month', (
    tester,
  ) async {
    final state = await makeState(mode: SpaceMode.personal);
    await tester.pumpWidget(appHarness(state, const ShellScreen()));
    await tester.pump();

    await tester.tap(find.text('Add estimate'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '15000');
    await tester.pump();

    await tester.tap(find.text('Save estimate'));
    await tester.pumpAndSettle();

    expect(state.estimatedExpenses, hasLength(1));
    expect(state.estimatedExpenses.single.amount, const Money(1500000));
    final now = DateTime.now();
    expect(
      state.estimatedExpenses.single.month,
      DateTime(now.year, now.month),
    );
    // After saving, the quick action switches to editing the planned amount.
    expect(find.text('Edit estimate'), findsOneWidget);
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
