import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../state/biometric_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

/// Shown at launch when biometric login is enabled and a session exists.
/// Prompts for a device scan; a password fallback routes back to the
/// sign-in screen.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onUsePassword;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    required this.onUsePassword,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _scanning = false;

  Future<void> _unlock() async {
    if (_scanning) return;
    final biometrics = context.read<BiometricAuthController>();
    final l10n = context.l10n;
    if (await biometrics.availabilityIssue() != null) {
      if (!mounted) return;
      showToast(context, l10n.biometricUnavailable, type: ToastType.danger);
      return;
    }
    setState(() => _scanning = true);
    final ok = await biometrics.authenticate(l10n.biometricLogin);
    if (!mounted) return;
    setState(() => _scanning = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      showToast(context, l10n.biometricFailed, type: ToastType.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.biometricLogin,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.biometricLogin,
                icon: Icons.fingerprint_rounded,
                loading: _scanning,
                onPressed: _scanning ? null : _unlock,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onUsePassword,
                child: Text(l10n.usePassword),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
