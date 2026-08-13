import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../state/biometric_controller.dart';
import '../state/locale_controller.dart';
import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/misc.dart';
import '../widgets/toasts.dart';
import 'categories_screen.dart';
import 'export_screen.dart';
import 'household_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final biometrics = context.watch<BiometricAuthController>();
    final user = state.currentUser;
    final household = state.household;
    final cycle = state.selectedCycle;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _ProfileCard(
            name: user?.name ?? 'User',
            email: user?.email ?? '',
            onTap: () => _push(context, ProfileScreen()),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.household),
          _SettingTile(
            icon: Icons.home_work_outlined,
            title: l10n.householdAndMembers,
            subtitle: household?.name ?? 'No household',
            onTap: () => _push(context, HouseholdScreen()),
          ),
          _SettingTile(
            icon: Icons.category_outlined,
            title: l10n.categories,
            subtitle: '${state.categories.length} categories',
            onTap: () => _push(context, CategoriesScreen()),
          ),
          _SettingTile(
            icon: Icons.currency_rupee,
            title: l10n.currency,
            subtitle: household?.currency ?? 'NPR',
            onTap: () => _showCurrencyPicker(context, state),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.spendingCycle),
          _SettingTile(
            icon: Icons.event_available_outlined,
            title: l10n.currentCycle,
            subtitle: cycle?.name ?? l10n.noActiveCycle,
            onTap: cycle == null
                ? null
                : () => _showCycleDialog(context, state),
          ),
          if (state.isOwner) ...[
            _SettingTile(
              icon: Icons.lock_outline_rounded,
              title: cycle?.status == CycleStatus.closed
                  ? l10n.startNewCycle
                  : l10n.closeCurrentCycle,
              subtitle: l10n.ownersCanManage,
              onTap: () => _handleCycleAction(context, state),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(title: l10n.data),
          _SettingTile(
            icon: Icons.download_outlined,
            title: l10n.export,
            subtitle: l10n.csvOfCurrentCycle,
            onTap: () => _push(context, ExportScreen()),
          ),
          _SettingTile(
            icon: Icons.notifications_outlined,
            title: l10n.notifications,
            subtitle: l10n.notificationsSubtitle,
            onTap: () => _showNotifications(context),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.appearance),
          _SettingTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: l10n.darkMode,
            subtitle: isDark ? l10n.onValue : l10n.offValue,
            trailing: Switch(
              value: isDark,
              onChanged: (v) {
                context.read<ThemeModeController>().setMode(
                  v ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            onTap: null,
          ),
          _SettingTile(
            icon: Icons.language_rounded,
            title: l10n.language,
            subtitle: l10n.languageSubtitle,
            onTap: () =>
                _showLanguagePicker(context, context.read<LocaleController>()),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.security),
          if (biometrics.supported)
            _SettingTile(
              icon: Icons.fingerprint_rounded,
              title: l10n.biometricLogin,
              subtitle: biometrics.enabled ? l10n.onValue : l10n.offValue,
              trailing: Switch(
                value: biometrics.enabled,
                onChanged: (v) => _toggleBiometric(context, biometrics, v),
              ),
              onTap: null,
            ),
          const SizedBox(height: 24),
          _SettingTile(
            icon: Icons.logout_rounded,
            title: l10n.signOut,
            subtitle: l10n.signOutSubtitle,
            destructive: true,
            onTap: () => _confirmSignOut(context, state),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.appName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.version,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    BiometricAuthController biometrics,
    bool value,
  ) async {
    final l10n = context.l10n;
    if (value) {
      final issue = await biometrics.availabilityIssue();
      
      if (!context.mounted) return;
      if (issue != null) {
        showToast(
          context,
          issue == 'notEnrolled'
              ? l10n.biometricNotEnrolled
              : l10n.biometricUnavailable,
          type: ToastType.warning,
        );
        return;
      }
      final ok = await biometrics.enable(l10n.biometricLogin);
      if (!context.mounted) return;
      if (!ok) {
        showToast(context, l10n.biometricFailed, type: ToastType.warning);
      }
    } else {
      await biometrics.disable();
    }
  }

  Future<void> _handleCycleAction(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final cycle = state.selectedCycle;
    if (cycle == null) return;
    if (cycle.status == CycleStatus.closed) {
      await state.startNewCycle();
      if (!context.mounted) return;
      showToast(context, l10n.newCycleStarted, type: ToastType.success);
      return;
    }
    final proposals = state.settlementProposals();
    if (proposals.isNotEmpty) {
      showToast(context, l10n.settleBeforeClose, type: ToastType.warning);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeCycleTitle(cycle.name)),
        content: Text(l10n.closeCycleMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.closeCycle),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.closeCycle();
      if (!context.mounted) return;
      showToast(context, l10n.cycleClosed, type: ToastType.success);
    }
  }

  void _showCycleDialog(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.spendingCycle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (final c in state.cycles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    c.status == CycleStatus.closed
                        ? Icons.history_rounded
                        : Icons.radio_button_checked,
                    color: c.status == CycleStatus.closed
                        ? AppColors.textMuted
                        : AppColors.positive,
                  ),
                  title: Text(c.name),
                  subtitle: Text(_cycleStatusLabel(context.l10n, c.status)),
                  trailing: Text(
                    formatMonthRange(c),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  onTap: () {
                    state.selectCycle(c.id);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String formatMonthRange(Cycle c) {
    return '${c.startDate.month}/${c.startDate.year}';
  }

  void _showCurrencyPicker(BuildContext context, AppState state) {
    final current = state.household?.currency ?? 'NPR';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.currency,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (final code in const ['NPR', 'USD', 'INR', 'EUR'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.currency_exchange_outlined),
                  title: Text(code),
                  trailing: current == code
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    if (state.household != null) {
                      state.renameHouseholdCurrency(code);
                    }
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.notifications,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.notificationsSheet,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.signOut();
    }
  }

  void _showLanguagePicker(BuildContext context, LocaleController controller) {
    final l10n = context.l10n;
    final current = controller.locale;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('System'),
                trailing: current == null
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  controller.setLocale(null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_rounded),
                title: Text(l10n.english),
                trailing: current == const Locale('en')
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  controller.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_rounded),
                title: Text(l10n.nepali),
                trailing: current == const Locale('ne')
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  controller.setLocale(const Locale('ne'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cycleStatusLabel(AppLocalizations l10n, CycleStatus status) {
  switch (status) {
    case CycleStatus.active:
      return l10n.statusActive;
    case CycleStatus.readyToSettle:
      return l10n.statusReady;
    case CycleStatus.settled:
      return l10n.statusSettled;
    case CycleStatus.closed:
      return l10n.statusClosed;
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          MemberAvatar(name: name, size: 58, outline: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = destructive ? AppColors.negative : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: destructive ? AppColors.negative : null,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
