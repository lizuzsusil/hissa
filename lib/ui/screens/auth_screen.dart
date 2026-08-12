import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/validators.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/google_logo.dart';
import '../widgets/toasts.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onBack;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.onBack,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nameError = _isSignUp
        ? validateName(_nameController.text, label: 'Your name')
        : null;
    final emailError = validateEmail(_emailController.text);
    final passwordError = validatePassword(_passwordController.text);
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
    final state = context.read<AppState>();
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
      final ok = await state.signIn(email: email, password: password);
      if (mounted && !ok) {
        setState(() => _loading = false);
        showToast(
          context,
          'Incorrect email or password. Try again or create an account.',
          type: ToastType.danger,
        );
        return;
      }
    }
    if (mounted) {
      setState(() => _loading = false);
      widget.onAuthenticated();
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      final ok = await state.signInWithGoogle();
      if (!mounted) return;
      if (!ok) {
        // The Google account picker was dismissed.
        setState(() => _loading = false);
        return;
      }
      setState(() => _loading = false);
      widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, _friendlyAuthMessage(e), type: ToastType.danger);
      }
    }
  }

  String _friendlyAuthMessage(Object error) {
    debugPrint('Auth error: $error');
    if (error is GoogleAccountConflictException) {
      return 'That email already has a password account. Log in with your '
          'email and password instead.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email. Log in instead.';
        case 'weak-password':
          return 'That password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'That email address does not look valid.';
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your connection and retry.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled yet. Enable it in the '
              'Firebase console (Authentication > Sign-in method).';
        case 'invalid-api-key':
        case 'app-not-authorized':
          return 'Authentication is not configured correctly. Open the '
              'Firebase console and check the app config, keys and SHA '
              'fingerprints.';
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'The database is rejecting this action. Publish the '
              'firestore.rules file from the project to Firebase.';
        case 'unavailable':
        case 'failed-precondition':
          return 'The database is busy or not ready yet. Please try again.';
      }
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'Google sign-in is not configured yet. In the Firebase '
              'console, add your Android SHA-1 fingerprint, then re-run '
              '`flutterfire configure`.';
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'Google Play services is unavailable or misconfigured on '
              'this device.';
        case GoogleSignInExceptionCode.uiUnavailable:
          return 'The Google sign-in window could not be shown right now. '
              'Please try again.';
        default:
          break;
      }
    }
    return 'Something went wrong. Check the debug logs for the exact error '
        '(${error.runtimeType}).';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAction(
                    icon: Icons.arrow_back_rounded,
                    onPressed: widget.onBack,
                  ),
                ],
              ),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  _isSignUp ? 'Create your account' : 'Welcome back',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isSignUp
                      ? 'Start tracking shared expenses in seconds.'
                      : 'Log in to keep your household in sync.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    errorText: _nameError,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                  errorText: _emailError,
                ),
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSignUp ? 'Create account' : 'Log in',
                icon: _isSignUp ? Icons.person_add_alt : Icons.login_rounded,
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'Continue with Google',
                leading: const GoogleLogo(size: 18),
                onPressed: _loading ? null : _google,
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _nameError = null;
                    _emailError = null;
                    _passwordError = null;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : 'New to Hissa? ',
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Log in' : 'Create one',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
