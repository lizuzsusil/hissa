import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_state.dart';
import '../../core/validators.dart';
import '../../l10n/l10n.dart';
import '../state/biometric_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/google_logo.dart';
import '../widgets/toasts.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _rememberKey = 'hissa_remember_email_v1';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _googleLoading = false;
  bool _biometricLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  bool get _busy => _loading || _googleLoading || _biometricLoading;

  @override
  void initState() {
    super.initState();
    // Default to sign-in (login); user can toggle to sign-up
    _isSignUp = false;
    _restoreRememberedEmail();
  }

  /// Pre-fills the email field with the account the user last asked us to
  /// remember, and re-checks the "Remember me" box to match.
  Future<void> _restoreRememberedEmail() async {
    final prefs = SharedPreferencesAsync();
    final email = await prefs.getString(_rememberKey);
    if (!mounted || email == null) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = email;
    });
  }

  Future<void> _persistRememberedEmail() async {
    final prefs = SharedPreferencesAsync();
    if (_rememberMe) {
      await prefs.setString(_rememberKey, _emailController.text.trim());
    } else {
      await prefs.remove(_rememberKey);
    }
  }

  /// Returns `true` when the device appears to have a network connection,
  /// otherwise shows an offline toast and returns `false`.
  Future<bool> _ensureOnline() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online && mounted) {
      final message = context.l10n.authNetwork;
      showToast(context, message, type: ToastType.danger);
    }
    return online;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final l10n = context.l10n;
    if (!await _ensureOnline()) return;
    if (_busy) return;
    final vm = ValidatorMessages.fromL10n(l10n);
    final nameError = _isSignUp
        ? validateName(_nameController.text, label: l10n.yourName, messages: vm)
        : null;
    final emailError = validateEmail(_emailController.text, messages: vm);
    final passwordError = validatePassword(
      _passwordController.text,
      messages: vm,
    );
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (nameError != null || emailError != null || passwordError != null) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _loading = true);
    if (_isSignUp) {
      try {
        await state.signUp(
          name: _nameController.text.trim(),
          email: email,
          password: password,
        );
      } on Exception catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          showToast(context, _friendlyAuthMessage(e), type: ToastType.danger);
          return;
        }
      }
    } else {
      try {
        final ok = await state.signIn(email: email, password: password);
        if (mounted && !ok) {
          setState(() => _loading = false);
          showToast(
            context,
            context.l10n.errIncorrectCredentials,
            type: ToastType.danger,
          );
          return;
        }
      } on Exception catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          showToast(context, _friendlyAuthMessage(e), type: ToastType.danger);
        }
        return;
      }
      await _persistRememberedEmail();
    }
    if (mounted) {
      setState(() => _loading = false);
      widget.onAuthenticated();
    }
  }

  Future<void> _google() async {
    final state = context.read<AppState>();
    if (!await _ensureOnline()) return;
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final ok = await state.signInWithGoogle();
      if (!mounted) return;
      if (!ok) {
        // The Google account picker was dismissed.
        setState(() => _googleLoading = false);
        return;
      }
      setState(() => _googleLoading = false);
      widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() => _googleLoading = false);
        showToast(context, _friendlyAuthMessage(e), type: ToastType.danger);
      }
    }
  }

  Future<void> _biometric() async {
    if (_biometricLoading) return;
    final biometrics = context.read<BiometricAuthController>();
    final l10n = context.l10n;
    if (await biometrics.availabilityIssue() != null) {
      if (!mounted) return;
      showToast(context, l10n.biometricUnavailable, type: ToastType.danger);
      return;
    }
    setState(() => _biometricLoading = true);
    final ok = await biometrics.authenticate(l10n.biometricLogin);
    if (!mounted) return;
    setState(() => _biometricLoading = false);
    if (ok) {
      widget.onAuthenticated();
    } else {
      showToast(context, l10n.biometricFailed, type: ToastType.danger);
    }
  }

  String _friendlyAuthMessage(Object error) {
    debugPrint('Auth error: $error');
    final l10n = context.l10n;
    if (error is GoogleAccountConflictException) {
      return l10n.authGoogleConflict;
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return l10n.authEmailInUse;
        case 'weak-password':
          return l10n.authWeakPassword;
        case 'invalid-email':
          return l10n.authInvalidEmail;
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return l10n.authIncorrect;
        case 'user-disabled':
          return l10n.authUserDisabled;
        case 'too-many-requests':
          return l10n.authTooManyRequests;
        case 'network-request-failed':
          return l10n.authNetwork;
        case 'operation-not-allowed':
          return l10n.authOperationNotAllowed;
        case 'invalid-api-key':
        case 'app-not-authorized':
          return l10n.authConfigError;
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return l10n.authFirestoreDenied;
        case 'unavailable':
        case 'failed-precondition':
          return l10n.authFirestoreUnavailable;
      }
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
          return l10n.authGoogleConfig;
        case GoogleSignInExceptionCode.providerConfigurationError:
          return l10n.authGooglePlayServices;
        case GoogleSignInExceptionCode.uiUnavailable:
          return l10n.authGoogleUi;
        default:
          break;
      }
    }
    return l10n.authSomethingWentWrong;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final biometrics = context.watch<BiometricAuthController>();
    // Only show quick biometric shortcut when the *currently persisted* Firebase
    // user is the one who enabled it. After a full sign-out there is no
    // Firebase session to unlock — tapping biometric here would otherwise call
    // onAuthenticated with no user and appear to create a separate user.
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    final biometricsEnabled = fbUid != null && biometrics.isEnabledFor(fbUid);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Text(
                  _isSignUp ? l10n.createYourAccount : l10n.welcomeBack,
                  style: AppText.displayL.copyWith(
                    fontSize: 30,
                    letterSpacing: -0.6,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  _isSignUp ? l10n.authSignupSubtitle : l10n.authLoginSubtitle,
                  textAlign: TextAlign.center,
                  style: AppText.bodyL.copyWith(color: p.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.yourName,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    errorText: _nameError,
                  ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg - 2),
                ],
              TextField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.emailAddress,
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                  ),
                  errorText: _emailError,
                ),
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg - 2),
              TextField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  errorText: _passwordError,
                  prefixIcon: IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
              ),
              if (!_isSignUp)
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _rememberMe = value ?? false),
                    ),
                    Text(
                      l10n.rememberMe,
                      style: AppText.labelL.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              if (!_isSignUp && biometricsEnabled) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: _busy ? null : _biometric,
                      child: _biometricLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.biometricLogin),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
              PrimaryButton(
                label: _isSignUp ? l10n.createAccount : l10n.logIn,
                icon: _isSignUp ? Icons.person_add_alt : Icons.login_rounded,
                loading: _loading,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.lg - 2),
              Row(
                children: [
                  Expanded(child: Divider(color: p.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      l10n.or,
                      style: AppText.bodyM.copyWith(color: p.textMuted),
                    ),
                  ),
                  Expanded(child: Divider(color: p.border)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg - 2),
              SecondaryButton(
                label: l10n.continueWithGoogle,
                leading: const GoogleLogo(size: 18),
                loading: _googleLoading,
                onPressed: _busy ? null : _google,
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
              Center(
                child: GestureDetector(
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _nameError = null;
                          _emailError = null;
                          _passwordError = null;
                        }),
                  child: RichText(
                    text: TextSpan(
                      style: AppText.labelL.copyWith(color: p.textSecondary),
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? l10n.alreadyHaveAccount
                              : l10n.newToHissa,
                        ),
                        TextSpan(
                          text: _isSignUp ? l10n.logInLink : l10n.createOne,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
