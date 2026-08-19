import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/core/money.dart';
import 'package:hissa/data/in_memory_repository.dart';
import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/spaces_dashboard_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Delete/Leave a Space: swipe-to-reveal action per card (Delete for the
/// owner, Leave for members), a 10s undoable countdown before anything is
/// destroyed, and a block on leaving while the member still owes money —
/// historical transactions stay untouched.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// u1 owns h1 and is a regular member of h2 (owned by u_other).
  Future<AppState> makeState() async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveUser(
      User(
        id: 'u1',
        name: 'Ram',
        email: 'ram@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_other',
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
        mode: SpaceMode.split,
        createdBy: 'u1',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveSpace(
      Space(
        id: 'h2',
        name: 'Trip',
        currency: 'NPR',
        inviteCode: 'ABCD13',
        mode: SpaceMode.split,
        createdBy: 'u_other',
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
    await repo.saveMember(
      SpaceMember(
        userId: 'u_other',
        name: 'B',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h2',
      ),
      'h2',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u1',
        name: 'Ram',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h2',
      ),
      'h2',
    );
    state.debugSetSession(userId: 'u1', spaceId: null);
    await state.refreshSpaces();
    return state;
  }

  /// An open cycle where [payerId] paid Rs 100 split 50/50 with [memberId],
  /// so [memberId] owes Rs 50 unless a settlement covers it.
  Future<void> seedOutstanding(
    AppState state, {
    required String spaceId,
    required String payerId,
    required String memberId,
    String cycleId = 'c1',
    String expenseId = 'e1',
  }) async {
    final repo = state.repo;
    await repo.saveCycle(
      Cycle(
        id: cycleId,
        spaceId: spaceId,
        name: 'Cycle 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );
    await repo.saveExpense(
      Expense(
        id: expenseId,
        spaceId: spaceId,
        cycleId: cycleId,
        paidByUserId: payerId,
        amount: const Money(10000),
        description: 'Dinner',
        date: DateTime(2026, 1, 5),
        createdAt: DateTime(2026, 1, 5),
        updatedAt: DateTime(2026, 1, 5),
      ),
      [
        ExpenseShare(
          id: '${expenseId}_s1',
          expenseId: expenseId,
          userId: payerId,
          amount: const Money(5000),
        ),
        ExpenseShare(
          id: '${expenseId}_s2',
          expenseId: expenseId,
          userId: memberId,
          amount: const Money(5000),
        ),
      ],
    );
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
        home: SpacesDashboardScreen(
          onSelect: (_) {},
          onCreate: () {},
          onJoin: () {},
          onSignOut: () {},
        ),
      ),
    );
  }

  Future<void> swipeLeft(WidgetTester tester, String spaceId) async {
    await tester.drag(
      find.byKey(ValueKey('space_card_$spaceId')),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
  }

  group('leaving rules', () {
    test('the owner cannot leave (they must delete instead)', () async {
      final state = await makeState();
      expect(state.isOwnerOf('h1'), isTrue);
      expect(await state.leaveSpace('h1'), isFalse);
      expect(state.spaces.map((s) => s.id), contains('h1'));
    });

    test('outstandingDuesFor reflects the member\'s net balance', () async {
      final state = await makeState();
      await seedOutstanding(
        state,
        spaceId: 'h2',
        payerId: 'u_other',
        memberId: 'u1',
      );
      final dues = await state.outstandingDuesFor('h2', 'u1');
      expect(dues.paisa, -5000);
    });

    test('leaving is blocked while the member has outstanding dues', () async {
      final state = await makeState();
      await seedOutstanding(
        state,
        spaceId: 'h2',
        payerId: 'u_other',
        memberId: 'u1',
      );

      expect(await state.leaveSpace('h2'), isFalse);
      // Membership (and the Space) are untouched.
      expect(state.spaces.map((s) => s.id), contains('h2'));
      expect(
        state.repo.members.any((m) => m.userId == 'u1' && m.spaceId == 'h2'),
        isTrue,
      );
    });

    test('leaving succeeds once the balance is fully settled', () async {
      final state = await makeState();
      await seedOutstanding(
        state,
        spaceId: 'h2',
        payerId: 'u_other',
        memberId: 'u1',
      );
      await state.repo.saveSettlement(
        Settlement(
          id: 'st1',
          spaceId: 'h2',
          cycleId: 'c1',
          fromUserId: 'u1',
          toUserId: 'u_other',
          amount: const Money(5000),
          currency: 'NPR',
          paymentMethod: 'Cash',
          date: DateTime(2026, 1, 6),
          status: SettlementStatus.paid,
          createdAt: DateTime(2026, 1, 6),
        ),
      );
      expect((await state.outstandingDuesFor('h2', 'u1')).isZero, isTrue);

      expect(await state.leaveSpace('h2'), isTrue);
      expect(state.spaces.map((s) => s.id), isNot(contains('h2')));
      // The member is gone, but historical transactions are preserved.
      expect(
        state.repo.members.any((m) => m.userId == 'u1' && m.spaceId == 'h2'),
        isFalse,
      );
      expect(state.repo.expenses.any((e) => e.id == 'e1'), isTrue);
      expect(state.repo.shares.any((s) => s.userId == 'u1'), isTrue);
    });
  });

  group('deleting rules', () {
    test('only the owner can delete a Space', () async {
      final state = await makeState();
      expect(await state.deleteSpace('h2'), isFalse);
      expect(state.spaces.map((s) => s.id), contains('h2'));
    });

    test('the owner deleting removes the Space and all of its data', () async {
      final state = await makeState();
      await seedOutstanding(
        state,
        spaceId: 'h1',
        payerId: 'u1',
        memberId: 'u1',
        cycleId: 'c_h1',
        expenseId: 'e_h1',
      );

      expect(await state.deleteSpace('h1'), isTrue);
      expect(state.spaces.map((s) => s.id), isNot(contains('h1')));
      expect(state.repo.expenses.any((e) => e.spaceId == 'h1'), isFalse);
      expect(state.repo.shares.any((s) => s.expenseId == 'e_h1'), isFalse);
      expect(state.repo.cycles.any((c) => c.spaceId == 'h1'), isFalse);
      expect(state.repo.members.any((m) => m.spaceId == 'h1'), isFalse);

      // The other Space (h2, owned by u_other) is untouched.
      expect(state.spaces.map((s) => s.id), contains('h2'));
      expect(state.repo.members.any((m) => m.spaceId == 'h2'), isTrue);
    });
  });

  group('swipe reveal', () {
    testWidgets('the owner card reveals Delete and the member card reveals '
        'Leave', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      await tester.pumpWidget(appHarness(state));
      await tester.pumpAndSettle();

      await swipeLeft(tester, 'h1');
      expect(find.byKey(const ValueKey('space_action_h1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('space_action_h1')),
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
        findsOneWidget,
      );

      // Close it again and swipe the member card.
      await tester.tap(find.byKey(const ValueKey('space_card_h1')));
      await tester.pumpAndSettle();
      await swipeLeft(tester, 'h2');
      expect(find.byKey(const ValueKey('space_action_h2')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('space_action_h2')),
          matching: find.byIcon(Icons.logout_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Undo cancels the leave and the Space stays', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      await tester.pumpWidget(appHarness(state));
      await tester.pumpAndSettle();

      await swipeLeft(tester, 'h2');
      await tester.tap(find.byKey(const ValueKey('space_action_h2')));
      await tester.pumpAndSettle();

      expect(find.text('Leaving Trip in 10s'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Nothing was removed.
      expect(find.text('Trip'), findsOneWidget);
      expect(state.spaces.map((s) => s.id), contains('h2'));
    });

    testWidgets('leaving executes after the 10s countdown expires', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      await tester.pumpWidget(appHarness(state));
      await tester.pumpAndSettle();

      await swipeLeft(tester, 'h2');
      await tester.tap(find.byKey(const ValueKey('space_action_h2')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(state.spaces.map((s) => s.id), isNot(contains('h2')));
      expect(find.text('Trip'), findsNothing);
    });

    testWidgets('deleting executes after the 10s countdown expires', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      await tester.pumpWidget(appHarness(state));
      await tester.pumpAndSettle();

      await swipeLeft(tester, 'h1');
      await tester.tap(find.byKey(const ValueKey('space_action_h1')));
      await tester.pumpAndSettle();
      expect(find.text('Deleting Home in 10s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(state.spaces.map((s) => s.id), isNot(contains('h1')));
    });

    testWidgets('leaving is blocked up front when dues are outstanding', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await makeState();
      await seedOutstanding(
        state,
        spaceId: 'h2',
        payerId: 'u_other',
        memberId: 'u1',
      );
      await tester.pumpWidget(appHarness(state));
      await tester.pumpAndSettle();

      await swipeLeft(tester, 'h2');
      await tester.tap(find.byKey(const ValueKey('space_action_h2')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('outstanding balance'),
        findsOneWidget,
      );
      // No countdown, no removal.
      expect(find.text('Undo'), findsNothing);
      expect(state.spaces.map((s) => s.id), contains('h2'));
    });
  });

  test('members getter dedupes duplicate rows for the same user', () {
    final state = AppState();
    state.debugSetRepo(_DuplicatedMembersRepo());
    state.debugSetSession(userId: 'u1', spaceId: 'h1');

    expect(state.members.map((m) => m.userId), ['u1', 'u_other']);
  });
}

/// Repo mirroring the legacy duplicate rows seen in Firestore (same user
/// stored twice under different doc ids). [InMemoryRepository.saveMember]
/// upserts by userId so it cannot reproduce this shape on its own.
class _DuplicatedMembersRepo extends InMemoryRepository {
  @override
  List<SpaceMember> get members => [
    SpaceMember(
      userId: 'u1',
      name: 'Ram',
      role: MemberRole.owner,
      joinedAt: _d,
      spaceId: 'h1',
    ),
    SpaceMember(
      userId: 'u1',
      name: 'Ram',
      role: MemberRole.owner,
      joinedAt: _d,
      spaceId: 'h1',
    ),
    SpaceMember(
      userId: 'u_other',
      name: 'B',
      role: MemberRole.member,
      joinedAt: _d,
      spaceId: 'h1',
    ),
  ];

  static final DateTime _d = DateTime(2026, 1, 1);
}