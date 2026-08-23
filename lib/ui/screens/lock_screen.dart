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
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(AppColors.primary),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 46,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: AppText.titleL.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                l10n.biometricLogin,
                textAlign: TextAlign.center,
                style: AppText.bodyL.copyWith(color: p.textSecondary),
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.biometricLogin,
                icon: Icons.fingerprint_rounded,
                loading: _scanning,
                onPressed: _scanning ? null : _unlock,
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              GhostButton(
                label: l10n.usePassword,
                onPressed: widget.onUsePassword,
                foreground: p.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
