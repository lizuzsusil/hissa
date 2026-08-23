import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../state/biometric_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

/// Shown at launch when biometric login is enabled for the *current* Firebase
/// user. Prompts for a device scan; a password fallback routes back to the
/// sign-in screen.
///
/// Per-uid binding ensures User A enabling never unlocks User B. If the device
/// has multiple accounts with biometrics enabled, a picker is shown so the
/// user can choose which previously-enabled account to unlock.
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
  String? _selectedUid;

  Future<void> _unlock() async {
    if (_scanning) return;
    final biometrics = context.read<BiometricAuthController>();
    final state = context.read<AppState>();
    final l10n = context.l10n;
    if (await biometrics.availabilityIssue() != null) {
      if (!mounted) return;
      showToast(context, l10n.biometricUnavailable, type: ToastType.danger);
      return;
    }
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = _selectedUid ?? biometrics.boundAccountForCurrentUser?.uid ?? state.currentUser?.id ?? fbUid;
    // Enforce per-uid binding: the device biometrics may only unlock the
    // account it was explicitly enabled for. This prevents "creating a
    // separate user" — a scan for User A never logs in User B.
    if (targetUid != null && !biometrics.isEnabledFor(targetUid)) {
      if (!mounted) return;
      showToast(context, l10n.biometricFailed, type: ToastType.danger);
      return;
    }
    if (fbUid != null && targetUid != null && fbUid != targetUid) {
      if (!mounted) return;
      showToast(context, l10n.biometricFailed, type: ToastType.warning);
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
    final biometrics = context.watch<BiometricAuthController>();
    final state = context.watch<AppState>();
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    final bound = biometrics.boundAccountForCurrentUser;
    final displayName = bound?.name ?? state.currentUser?.name ?? 'User';
    final displayEmail = bound?.email ?? state.currentUser?.email ?? '';
    final avatarUrl = bound?.avatarUrl ?? state.currentUser?.avatarUrl;
    final enabledAccounts = biometrics.enabledAccounts;
    final showPicker = enabledAccounts.length > 1;
    _selectedUid ??= bound?.uid ?? fbUid ?? state.currentUser?.id;

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
                child: MemberAvatar(name: displayName, avatarUrl: avatarUrl, size: 96, outline: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: AppText.titleL.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                displayEmail,
                textAlign: TextAlign.center,
                style: AppText.bodyM.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Biometrics enabled for this account',
                      style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (showPicker) ...[
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose account', style: AppText.labelM.copyWith(color: p.textPrimary)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < enabledAccounts.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 68, endIndent: AppSpacing.lg),
                        _AccountTile(
                          account: enabledAccounts[i],
                          selected: _selectedUid == enabledAccounts[i].uid,
                          onTap: () => setState(() => _selectedUid = enabledAccounts[i].uid),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Each account’s biometrics is bound separately. Selecting another account still requires its own scan and an active session.',
                  style: AppText.caption.copyWith(color: p.textMuted),
                ),
              ],
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

class _AccountTile extends StatelessWidget {
  final BiometricAccount account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({required this.account, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      leading: MemberAvatar(name: account.name, avatarUrl: account.avatarUrl, size: 40),
      title: Text(account.name, style: AppText.titleS.copyWith(color: p.textPrimary)),
      subtitle: Text(account.email, style: AppText.caption.copyWith(color: p.textSecondary)),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : const Icon(Icons.circle_outlined, color: Color(0xFF878FA0)),
    );
  }
}
