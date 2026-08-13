import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/expense_form_screen.dart';
import 'package:hissa/ui/widgets/buttons.dart';

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
        householdId: 'h1',
        name: 'Food',
        icon: Icons.restaurant,
        color: Colors.orange,
      ),
    );
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

  testWidgets('create group combines selected members into one party',
      (tester) async {
    final state = await makeSplitState();
    await tester.pumpWidget(harness(state));

    // All members are pre-selected by default; open the group picker and
    // create a group from the second member.
    final groupButton = find.widgetWithText(TextButton, 'Create group');
    await tester.ensureVisible(groupButton);
    await tester.pumpAndSettle();
    await tester.tap(groupButton);
    await tester.pumpAndSettle();

    // The picker lists the two members; pick both and confirm.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ram'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sita'));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(PrimaryButton, 'Create group'),
    );
    await tester.pumpAndSettle();

    // A group chip with the combined member name is rendered in the form.
    expect(find.text('Ram + Sita'), findsWidgets);
    expect(find.byIcon(Icons.group_outlined), findsWidgets);
  });

  testWidgets('creating a group from a single member is not possible',
      (tester) async {
    final state = await makeSplitState();
    await tester.pumpWidget(harness(state));

    // Deselect one member so only one ungrouped member remains.
    final sitaChip = find.widgetWithText(FilterChip, 'Sita');
    await tester.ensureVisible(sitaChip);
    await tester.pumpAndSettle();
    await tester.tap(sitaChip);
    await tester.pump();

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Create group'),
    );
    expect(button.onPressed, isNull);
  });
}