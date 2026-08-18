import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/models.dart';
import '../services/fcm_service.dart';
import '../state/app_state.dart';
import '../ui/screens/auth_screen.dart';
import '../ui/screens/intro_screen.dart';
import '../ui/screens/lock_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/setup_screen.dart';
import '../ui/screens/shell_screen.dart';
import '../ui/screens/spaces_dashboard_screen.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/state/biometric_controller.dart';
import '../ui/state/locale_controller.dart';
import '../ui/state/theme_controller.dart';
import '../ui/theme/app_theme.dart';
import '../ui/screens/member_groups_screen.dart';

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
      child: _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  _AppView();

  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeModeController>();
    final localeController = context.watch<LocaleController>();
    return MaterialApp(
      title: 'Hissa',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
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
      home: RootGate(navigatorKey: _navigatorKey),
    );
  }
}

enum _FlowStep { splash, intro, onboarding, auth, setup, lock, dashboard, app }

class RootGate extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const RootGate({super.key, required this.navigatorKey});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  _FlowStep _step = _FlowStep.splash;
  bool _setupCreateMode = true;

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
  /// app shell or the Spaces dashboard (or back to mode selection if it was
  /// never completed).
  void _onStateChanged() {
    if (!mounted) return;
    final state = context.read<AppState>();
    if ((_step == _FlowStep.app || _step == _FlowStep.dashboard) &&
        !state.isLoggedIn) {
      setState(() {
        _step = state.onboardingMode != null
            ? _FlowStep.auth
            : _FlowStep.onboarding;
      });
    }
  }

  Future<void> _bootstrap() async {
    final state = context.read<AppState>();
    FcmMessagingService.init(
      onGroupRequestTap: () {
        widget.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MemberGroupsScreen()),
        );
      },
    );
    await Future.wait([
      state.load(),
      context.read<LocaleController>().load(),
      context.read<BiometricAuthController>().load(),
    ]);
    if (!mounted) return;
    // Give the branded splash a moment to breathe.
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final _FlowStep step;
    if (!state.introSeen) {
      // First launch: show the feature intro, then mode selection.
      step = _FlowStep.intro;
    } else if (state.onboardingMode != null) {
      // Returning user: skip the intro/mode screens entirely.
      step = state.isLoggedIn ? await _signedInStep(state) : _FlowStep.auth;
    } else {
      // Intro seen but no mode picked yet.
      step = _FlowStep.onboarding;
    }
    if (!mounted) return;
    setState(() => _step = step);
  }

  Future<void> _finishIntro() async {
    final state = context.read<AppState>();
    await state.markIntroSeen();
    if (!mounted) return;
    final _FlowStep step;
    if (state.onboardingMode != null) {
      step = state.isLoggedIn ? await _signedInStep(state) : _FlowStep.auth;
    } else {
      step = _FlowStep.onboarding;
    }
    if (!mounted) return;
    setState(() => _step = step);
  }

  /// Where a signed-in user lands: a biometric gate when the user opted into
  /// it, otherwise straight into their only Space, their chosen default Space,
  /// or the Spaces dashboard.
  Future<_FlowStep> _signedInStep(AppState state) async {
    final biometrics = context.read<BiometricAuthController>();
    if (biometrics.enabled) return _FlowStep.lock;
    return _spaceLanding(state);
  }

  /// Lands the user inside their Space when they only belong to one, or inside
  /// their chosen default Space when they are still a member of it. In all
  /// other cases the Spaces dashboard is shown so the user can pick.
  Future<_FlowStep> _spaceLanding(AppState state) async {
    final launch = state.launchSpace;
    if (launch != null) {
      if (launch.id != state.space?.id) {
        await state.selectSpace(launch.id);
      }
      return _FlowStep.app;
    }
    return _FlowStep.dashboard;
  }

  Future<void> _enterApp() async {
    final state = context.read<AppState>();
    final landing = await _spaceLanding(state);
    if (!mounted) return;
    _go(landing);
  }

  void _selectSpace(Space space) {
    context.read<AppState>().selectSpace(space.id);
    _go(_FlowStep.app);
  }

  void _openSetup({required bool create}) {
    _setupCreateMode = create;
    _go(_FlowStep.setup);
  }

  void _signOutFromDashboard() {
    context.read<AppState>().signOut();
    _go(_FlowStep.auth);
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
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            // Intercept the system back button so it returns to the Spaces
            // dashboard instead of exiting the app.
            if (!didPop) _go(_FlowStep.dashboard);
          },
          child: SetupScreen(
            initialCreateMode: _setupCreateMode,
            onDone: () => _go(_FlowStep.app),
            onBack: () => _go(_FlowStep.dashboard),
          ),
        );
      case _FlowStep.dashboard:
        return SpacesDashboardScreen(
          onSelect: _selectSpace,
          onCreate: () => _openSetup(create: true),
          onJoin: () => _openSetup(create: false),
          onSignOut: _signOutFromDashboard,
        );
      case _FlowStep.app:
        return ShellScreen(onBackToSpaces: () => _go(_FlowStep.dashboard));
    }
  }
}
