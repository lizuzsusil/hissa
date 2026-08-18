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
import 'package:hissa/ui/screens/setup_screen.dart';
import 'package:hissa/ui/state/biometric_controller.dart';
import 'package:hissa/ui/state/locale_controller.dart';
import 'package:hissa/ui/state/theme_controller.dart';

/// The Space creation screen shows a cycle type choice (Monthly/Custom) only
/// for Split spaces, and the choice is selectable.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState() async {
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
    state.debugSetSession(userId: 'u_owner', spaceId: null);
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

  // A selected _ModeCard renders Icons.check_circle_rounded inside its subtree.
  bool isSelected(WidgetTester tester, String key) {
    final icons = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Icon),
    );
    return icons.evaluate().any(
          (e) => (e.widget as Icon).icon == Icons.check_circle_rounded,
        );
  }

  testWidgets('split space creation offers monthly and custom cycles',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState();
    await tester.pumpWidget(
      appHarness(
        state,
        SetupScreen(
          initialCreateMode: true,
          onDone: () {},
          onBack: null,
        ),
      ),
    );
    await tester.pump();

    // Split mode is the default, so the cycle type choice is visible.
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // Monthly is pre-selected; tapping Custom switches the selection.
    expect(isSelected(tester, 'cycle_monthly'), isTrue);
    expect(isSelected(tester, 'cycle_custom'), isFalse);

    await tester.tap(find.byKey(const ValueKey('cycle_custom')));
    await tester.pump();

    expect(isSelected(tester, 'cycle_monthly'), isFalse);
    expect(isSelected(tester, 'cycle_custom'), isTrue);
  });

  testWidgets('personal space creation hides the cycle type choice',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await makeState();
    await tester.pumpWidget(
      appHarness(
        state,
        SetupScreen(
          initialCreateMode: true,
          onDone: () {},
          onBack: null,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Personal Mode'));
    await tester.pump();

    expect(find.text('Monthly'), findsNothing);
    expect(find.text('Custom'), findsNothing);
    expect(find.byKey(const ValueKey('cycle_monthly')), findsNothing);
  });
}
