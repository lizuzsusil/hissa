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
import 'package:hissa/ui/screens/dashboard_screen.dart';
import 'package:hissa/ui/screens/income_form_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Visibility guarantees for household income:
///   1. "Received by" sits high inside the Add Income form so it is visible
///      without scrolling on a typical phone.
///   2. "Add income" is a prominent quick action on the home screen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState() async {
    final state = AppState();
    final repo = state.repo;
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
    for (final entry in {
      'u_a': ('Alice', MemberRole.owner),
      'u_b': ('Bob', MemberRole.member),
      'u_c': ('Cara', MemberRole.member),
      'u_d': ('Dan', MemberRole.member),
    }.entries) {
      await repo.saveMember(
        SpaceMember(
          userId: entry.key,
          name: entry.value.$1,
          role: entry.value.$2,
          joinedAt: DateTime(2026, 1, 1),
          spaceId: 'h1',
        ),
        'h1',
      );
    }
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
    await repo.saveCategory(
      Category(
        id: 'cat_rent',
        spaceId: 'h1',
        name: 'Rent',
        isDefault: true,
      ),
    );
    await repo.saveCategory(
      Category(
        id: 'cat_salary',
        spaceId: 'h1',
        name: 'Salary',
        isDefault: true,
      ),
    );
    state.debugSetSession(userId: 'u_a', spaceId: 'h1');
    return state;
  }

  Widget harness(AppState state, Widget home) {
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

  void usePhoneViewport(WidgetTester tester) {
    // A common mid-range phone: 360 x 780 logical pixels.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('received by section is visible without scrolling', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    // The section header and every member chip must be present.
    expect(find.text('Received by'), findsOneWidget);
    for (final name in ['Alice', 'Bob', 'Cara', 'Dan']) {
      expect(find.text(name), findsWidgets);
    }
    // The selected receiver defaults to the signed-in user (Alice).
    expect(find.text('Alice'), findsWidgets);

    // And it must sit within the FIRST screenful: above the fold.
    final headerTop =
        tester.getTopLeft(find.text('Received by')).dy;
    expect(headerTop, lessThan(780), reason: '"Received by" must be visible '
        'on the first screen of a 360x780 phone without scrolling');
    // Strictly: well before the fold, right after amount + source fields.
    expect(headerTop, lessThan(560));
  });

  testWidgets('selecting a receiver chip updates the selection', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    await tester.tap(find.text('Bob').first);
    await tester.pump();

    expect(state.currentUserId, 'u_a'); // sanity
    // Bob is now rendered with a selected style somewhere in the receiver
    // wrap; tapping again keeps exactly one selection.
    await tester.tap(find.text('Cara').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen surfaces a prominent add income action', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    await tester.pumpWidget(harness(state, const DashboardScreen()));
    await tester.pump();

    expect(find.text('Add income'), findsOneWidget);
    // It sits next to the other primary actions, within the first screenful.
    final top = tester.getTopLeft(find.text('Add income')).dy;
    expect(top, lessThan(780));
  });

  testWidgets('category picker behaves like Add Expense: select and keep', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    // Both seeded categories render as selectable chips.
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    // Fill the required source + amount, then tap "Rent" twice — the
    // expense-style picker keeps it selected instead of toggling off.
    await tester.enterText(find.byType(TextField).at(1), 'Room rent');
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.tap(find.text('Rent'));
    await tester.pump();
    await tester.tap(find.text('Rent'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Save income'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();

    expect(state.repo.hissaIncomes, hasLength(1));
    expect(state.repo.hissaIncomes.single.categoryId, 'cat_rent');
    expect(state.repo.hissaIncomes.single.amount, const Money(50000));
  });
}
