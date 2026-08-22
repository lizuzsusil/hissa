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
    // A Member Group so the form must surface group parties too.
    await repo.saveMemberGroup(
      MemberGroup(
        id: 'g1',
        spaceId: 'h1',
        ownerUserId: 'u_b',
        name: 'Flatmates',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        memberIds: ['u_c'],
      ),
    );
    await repo.addGroupMember('g1', 'u_c');
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

    // The section header and every eligible party must be present:
    // ungrouped members individually, plus the Member Group as ONE party.
    expect(find.text('Received by'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Dan'), findsWidgets);
    expect(find.text('Flatmates'), findsWidgets);
    // Grouped members (Bob owns Flatmates, Cara belongs to it) are
    // represented by their group only — never as individual chips.
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Cara'), findsNothing);
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

  testWidgets('received by is locked to the recording member', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    // Alice records the income, so the locked receiver row shows her with
    // the "You" badge.
    expect(find.text('Received by'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('You'), findsOneWidget);

    // Nothing else in the received-by section is selectable: tapping another
    // member's chip elsewhere on the form must not raise errors or change
    // anything about the locked row.
    await tester.tap(find.text('You'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'received by shows the recording member\'s group when they have one',
      (tester) async {
    usePhoneViewport(tester);

    final state = await makeState();
    // Bob belongs to the "Flatmates" Member Group: the GROUP becomes the
    // locked receiver instead of Bob individually.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    expect(find.text('Flatmates'), findsWidgets);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('saving records the recording member as receiver', (
    tester,
  ) async {
    usePhoneViewport(tester);

    final state = await makeState();
    // Bob is in the Flatmates group, so saving must record the GROUP as the
    // receiving financial participant — without any manual selection.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await tester.pumpWidget(harness(state, const IncomeFormScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), 'Room rent');
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.scrollUntilVisible(
      find.text('Save income'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();

    expect(state.repo.hissaIncomes, hasLength(1));
    final income = state.repo.hissaIncomes.single;
    expect(income.receivedByUserId, 'g1');
    expect(income.participantIds, contains('g1'));
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
