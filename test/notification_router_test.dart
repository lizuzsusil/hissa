import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/services/notification_router.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/dashboard_screen.dart';
import 'package:hissa/ui/screens/expense_detail_screen.dart';
import 'package:hissa/ui/screens/member_groups_screen.dart';
import 'package:hissa/ui/screens/settle_screen.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Split-mode Home owned by u_owner with member u_b and one cycle.
  Future<AppState> makeHomeState({bool personal = false}) async {
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
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABCD12',
        mode: personal ? SpaceMode.personal : SpaceMode.split,
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

  Future<NotificationRouter> pumpRouter(
    WidgetTester tester,
    AppState state,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          navigatorKey: key,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: Text('root')),
        ),
      ),
    );
    return NotificationRouter(navigatorKey: key, state: state);
  }

  testWidgets('expenseAdded deep-links to the expense detail screen',
      (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    await state.addExpense(
      description: 'Dinner',
      amount: const Money(100000),
      date: DateTime(2026, 1, 10),
      participantIds: ['u_owner', 'u_b'],
    );
    final expenseId = state.expensesInCycle.first.id;

    await router.open({
      'type': 'expenseAdded',
      'spaceId': 'h1',
      'eventKey': expenseId,
    });
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    expect(
      tester.widget<ExpenseDetailScreen>(find.byType(ExpenseDetailScreen))
          .expense
          .id,
      expenseId,
    );
  });

  testWidgets('settlementRecorded deep-links to the settle screen',
      (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    await router.open({'type': 'settlementRecorded', 'spaceId': 'h1'});
    await tester.pumpAndSettle();
    expect(find.byType(SettleScreen), findsOneWidget);
  });

  testWidgets('personal mode settles to the dashboard instead', (tester) async {
    final state = await makeHomeState(personal: true);
    final router = await pumpRouter(tester, state);
    await router.open({'type': 'settlementRecorded', 'spaceId': 'h1'});
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('groupApproved deep-links to member groups', (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    await router.open({'type': 'groupApproved', 'spaceId': 'h1'});
    await tester.pumpAndSettle();
    expect(find.byType(MemberGroupsScreen), findsOneWidget);
  });

  testWidgets('spaceJoinApproved enters the space without pushing a screen',
      (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    await router.open({'type': 'spaceJoinApproved', 'spaceId': 'h1'});
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(find.byType(ExpenseDetailScreen), findsNothing);
  });

  testWidgets('an unknown type is ignored', (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    await router.open({'type': 'mystery', 'spaceId': 'h1'});
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('buffered deep links flush once signed in', (tester) async {
    final state = await makeHomeState();
    final router = await pumpRouter(tester, state);
    router.buffer({'type': 'settlementRecorded', 'spaceId': 'h1'});
    await router.flush();
    await tester.pumpAndSettle();
    expect(find.byType(SettleScreen), findsOneWidget);
  });
}