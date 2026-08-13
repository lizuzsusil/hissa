import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../ui/screens/auth_screen.dart';
import '../ui/screens/intro_screen.dart';
import '../ui/screens/lock_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/setup_screen.dart';
import '../ui/screens/shell_screen.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/state/biometric_controller.dart';
import '../ui/state/locale_controller.dart';
import '../ui/state/theme_controller.dart';
import '../ui/theme/app_theme.dart';

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ThemeModeController()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider(create: (_) => BiometricAuthController()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeModeController>();
    final localeController = context.watch<LocaleController>();
    return MaterialApp(
      title: 'Hissa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode,
      locale: localeController.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ne')],
      home: const RootGate(),
    );
  }
}

enum _FlowStep { splash, intro, onboarding, auth, setup, lock, app }

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  _FlowStep _step = _FlowStep.splash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
      final state = context.read<AppState>();
      state.addListener(_onStateChanged);
    });
  }

  @override
  void dispose() {
    context.read<AppState>().removeListener(_onStateChanged);
    super.dispose();
  }

  /// Sends the user to the login screen when they sign out from inside the
  /// app shell (or back to mode selection if it was never completed).
  void _onStateChanged() {
    if (!mounted) return;
    final state = context.read<AppState>();
    if (_step == _FlowStep.app && !state.isLoggedIn) {
      setState(() {
        _step = state.onboardingMode != null
            ? _FlowStep.auth
            : _FlowStep.onboarding;
      });
    }
  }

  Future<void> _bootstrap() async {
    final state = context.read<AppState>();
    await Future.wait([
      state.load(),
      context.read<LocaleController>().load(),
      context.read<BiometricAuthController>().load(),
    ]);
    if (!mounted) return;
    // Give the branded splash a moment to breathe.
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      if (!state.introSeen) {
        // First launch: show the feature intro, then mode selection.
        _step = _FlowStep.intro;
      } else if (state.onboardingMode != null) {
        // Returning user: skip the intro/mode screens entirely.
        _step = state.isLoggedIn ? _signedInStep(state) : _FlowStep.auth;
      } else {
        // Intro seen but no mode picked yet.
        _step = _FlowStep.onboarding;
      }
    });
  }

  Future<void> _finishIntro() async {
    final state = context.read<AppState>();
    await state.markIntroSeen();
    if (!mounted) return;
    setState(() {
      _step = state.onboardingMode != null
          ? (state.isLoggedIn ? _signedInStep(state) : _FlowStep.auth)
          : _FlowStep.onboarding;
    });
  }

  /// Where a signed-in user lands: a biometric gate when the user opted into
  /// it, otherwise straight into the shell (or household setup).
  _FlowStep _signedInStep(AppState state) {
    final biometrics = context.read<BiometricAuthController>();
    if (biometrics.enabled) return _FlowStep.lock;
    return state.hasHousehold ? _FlowStep.app : _FlowStep.setup;
  }

  void _enterApp() {
    final state = context.read<AppState>();
    _go(state.hasHousehold ? _FlowStep.app : _FlowStep.setup);
  }

  void _go(_FlowStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _FlowStep.splash:
        return const SplashScreen();
      case _FlowStep.intro:
        return OnboardingScreen(onDone: _finishIntro);
      case _FlowStep.onboarding:
        return IntroScreen(
          onContinue: (mode) {
            final state = context.read<AppState>();
            state.setOnboardingMode(mode);
            _go(_FlowStep.auth);
          },
        );
      case _FlowStep.auth:
        return AuthScreen(
          onAuthenticated: _enterApp,
        );
      case _FlowStep.lock:
        return LockScreen(
          onUnlocked: _enterApp,
          onUsePassword: () => _go(_FlowStep.auth),
        );
      case _FlowStep.setup:
        return SetupScreen(onDone: () => _go(_FlowStep.app));
      case _FlowStep.app:
        return const ShellScreen();
    }
  }
}
