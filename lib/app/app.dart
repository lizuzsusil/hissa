import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../ui/screens/auth_screen.dart';
import '../ui/screens/intro_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/setup_screen.dart';
import '../ui/screens/shell_screen.dart';
import '../ui/screens/splash_screen.dart';
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
    return MaterialApp(
      title: 'Hissa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode,
      home: const RootGate(),
    );
  }
}

enum _FlowStep { splash, intro, onboarding, auth, setup, app }

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
    });
  }

  Future<void> _bootstrap() async {
    final state = context.read<AppState>();
    await state.load();
    if (!mounted) return;
    // Give the branded splash a moment to breathe.
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      if (!state.introSeen) {
        _step = _FlowStep.intro;
      } else if (state.isLoggedIn) {
        _step = state.hasHousehold ? _FlowStep.app : _FlowStep.setup;
      } else {
        _step = _FlowStep.onboarding;
      }
    });
  }

  Future<void> _finishIntro() async {
    final state = context.read<AppState>();
    await state.markIntroSeen();
    if (!mounted) return;
    setState(() {
      _step = state.isLoggedIn ? _FlowStep.setup : _FlowStep.onboarding;
    });
  }

  void _go(_FlowStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _FlowStep.splash:
        return const SplashScreen();
      case _FlowStep.intro:
        return IntroScreen(onDone: _finishIntro);
      case _FlowStep.onboarding:
        return OnboardingScreen(
          onContinue: (mode) {
            final state = context.read<AppState>();
            state.setOnboardingMode(mode);
            _go(_FlowStep.auth);
          },
        );
      case _FlowStep.auth:
        return AuthScreen(
          onAuthenticated: () {
            final state = context.read<AppState>();
            _go(state.hasHousehold ? _FlowStep.app : _FlowStep.setup);
          },
          onBack: () => _go(_FlowStep.onboarding),
        );
      case _FlowStep.setup:
        return SetupScreen(onDone: () => _go(_FlowStep.app));
      case _FlowStep.app:
        return const ShellScreen();
    }
  }
}
