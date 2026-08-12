import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      showToast(context, 'Please enter a valid email address',
          type: ToastType.danger);
      return;
    }
    if (_isSignUp && _nameController.text.trim().isEmpty) {
      showToast(context, 'Please tell us your name', type: ToastType.danger);
      return;
    }
    if (password.length < 6) {
      showToast(context, 'Password must be at least 6 characters',
          type: ToastType.danger);
      return;
    }
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
          return 'Incorrect email or password.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
      }
    }
    return 'Something went wrong. Please try again.';
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
              const SizedBox(height: 28),
              Text(
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
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Start tracking shared expenses in seconds.'
                    : 'Log in to keep your household in sync.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    suffixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
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
                icon: Icons.g_mobiledata,
                onPressed: _loading ? null : _google,
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isSignUp = !_isSignUp),
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
