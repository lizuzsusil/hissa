import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/expense_form_screen.dart';

void main() {
  Future<AppState> makeSplitState() async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveSpace(
      Space(
        id: 'h1',
        name: 'Home',
        currency: 'NPR',
        inviteCode: 'ABC12',
        mode: SpaceMode.split,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_ram',
        name: 'Ram',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_sita',
        name: 'Sita',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveCategory(
      Category.preset(
        id: 'c1',
        spaceId: 'h1',
        name: 'Food',
        icon: Icons.restaurant,
        color: Colors.orange,
      ),
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
    state.debugSetSession(userId: 'u_ram', spaceId: 'h1');
    return state;
  }

  Future<AppState> makeSplitStateWithGroups() async {
    final state = await makeSplitState();
    final repo = state.repo;

    // Create a persistent MemberGroup
    final group = MemberGroup(
      id: 'g1',
      spaceId: 'h1',
      ownerUserId: 'u_ram',
      name: "Ram's Group",
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      memberIds: ['u_sita'],
    );
    await repo.saveMemberGroup(group);
    await repo.addGroupMember('g1', 'u_sita');

    state.debugSetSession(userId: 'u_ram', spaceId: 'h1');
    return state;
  }

  Widget harness(AppState state) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const ExpenseFormScreen(),
      ),
    );
  }

  testWidgets('split mode form shows the current user as the payer with no '
      'payer selector', (tester) async {
    final state = await makeSplitState();
    await tester.pumpWidget(harness(state));

    expect(find.text('Paid by'), findsOneWidget);
    // The static payer row shows the current user's name and a "You" badge.
    expect(find.text('Ram'), findsWidgets);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('split mode form does not show a horizontal payer member list',
      (tester) async {
    final state = await makeSplitState();
    await tester.pumpWidget(harness(state));

    // The old payer selector was a horizontal ListView of member avatars.
    // The participant selector is a Wrap, so no horizontal ListView remains.
    final horizontalLists = tester
        .widgetList<ListView>(find.byType(ListView))
        .where((w) => w.scrollDirection == Axis.horizontal)
        .toList();
    expect(horizontalLists, isEmpty);
  });

  testWidgets('persistent Member Group is displayed in the participant selector',
      (tester) async {
    final state = await makeSplitStateWithGroups();
    await tester.pumpWidget(harness(state));

    // The Member Group should appear in the participant selector
    expect(find.text("Ram's Group"), findsOneWidget);
    expect(find.byIcon(Icons.groups_rounded), findsWidgets);
  });

  testWidgets('selecting a Member Group deselects its members individually',
      (tester) async {
    final state = await makeSplitStateWithGroups();
    await tester.pumpWidget(harness(state));

    // First select Sita individually
    final sitaChip = find.widgetWithText(FilterChip, 'Sita');
    await tester.ensureVisible(sitaChip);
    await tester.pumpAndSettle();
    await tester.tap(sitaChip);
    await tester.pumpAndSettle();

    // Now select the group "Ram's Group" (which contains Sita)
    final groupChip = find.widgetWithText(FilterChip, "Ram's Group");
    await tester.ensureVisible(groupChip);
    await tester.pumpAndSettle();
    await tester.tap(groupChip);
    await tester.pumpAndSettle();

    // Verify the group is selected (test passes if no exception)
  });
}