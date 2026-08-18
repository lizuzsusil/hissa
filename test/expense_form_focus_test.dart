import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/l10n/generated/app_localizations.dart';
import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';
import 'package:hissa/ui/screens/expense_form_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// Split inputs on the add-expense form must keep focus while typing: the
/// percentage and custom amount fields used to rebuild a brand new
/// TextEditingController on every keystroke, which dropped focus.
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
        home: const ExpenseFormScreen(),
      ),
    );
  }

  bool fieldHasFocus(WidgetTester tester, String key) {
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    );
    return editable.focusNode.hasFocus;
  }

  testWidgets('percentage input keeps focus while typing', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState();
    await tester.pumpWidget(appHarness(state));
    await tester.pump();

    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('pct_u_b')), '5');
    await tester.pump();

    // Rebuild happened (model updated) but the field must stay focused.
    expect(fieldHasFocus(tester, 'pct_u_b'), isTrue);
    expect(
      tester.widget<TextField>(
        find.byKey(const ValueKey('pct_u_b')),
      ).controller!.text,
      '5',
    );

    // Removing the value also keeps focus.
    await tester.enterText(find.byKey(const ValueKey('pct_u_b')), '');
    await tester.pump();
    expect(fieldHasFocus(tester, 'pct_u_b'), isTrue);
  });

  testWidgets('custom amount input keeps focus while typing', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState();
    await tester.pumpWidget(appHarness(state));
    await tester.pump();

    await tester.tap(find.text('Amounts'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('amt_u_b')), '250');
    await tester.pump();

    expect(fieldHasFocus(tester, 'amt_u_b'), isTrue);
    expect(
      tester.widget<TextField>(
        find.byKey(const ValueKey('amt_u_b')),
      ).controller!.text,
      '250',
    );
  });
}