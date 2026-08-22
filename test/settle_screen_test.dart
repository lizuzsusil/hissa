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
import 'package:hissa/ui/screens/settle_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Settle screen empty states: with no expenses recorded yet the screen must
/// explain there is nothing to settle, while a settled-out cycle shows the
/// "All settled up!" confirmation.
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
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    return state;
  }

  Widget appHarness(AppState state) {
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
        home: const SettleScreen(),
      ),
    );
  }

  testWidgets(
    'with no expenses the settle screen explains there is nothing to settle',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      expect(state.expensesInCycle, isEmpty);

      await tester.pumpWidget(appHarness(state));
      await tester.pump();

      expect(find.text('Nothing to settle yet'), findsOneWidget);
      expect(find.text('All settled up!'), findsNothing);
    },
  );

  testWidgets('a settled-out cycle still shows the all settled confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState();
    // Owner paid the whole dinner, split equally between the two of them.
    await state.addExpense(
      description: 'Dinner',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_owner', 'u_b'],
    );
    // B owes their half: as the debtor they request the settlement and the
    // creditor (owner) approves it, making every balance even.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    final requested = await state.requestSettlement(
      toUserId: 'u_owner',
      amount: const Money(50000),
      paymentMethod: 'Cash',
      date: DateTime(2026, 1, 12),
    );
    expect(requested, isTrue);
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    final approved = await state.approveSettlement(
      state.repo.settlements.single.id,
    );
    expect(approved, isTrue);

    expect(state.settlementProposals(), isEmpty);
    expect(state.expensesInCycle, hasLength(1));

    await tester.pumpWidget(appHarness(state));
    await tester.pump();

    expect(find.text('All settled up!'), findsOneWidget);
    expect(find.text('Nothing to settle yet'), findsNothing);
  });
}