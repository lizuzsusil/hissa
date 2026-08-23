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
import '../widgets/cards.dart';
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/toasts.dart';
import 'categories_screen.dart';
import 'cycle_detail_screen.dart';
import 'export_screen.dart';
import 'notifications_screen.dart';
import 'space_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  /// Invoked to return to the Spaces dashboard so the user can switch Spaces.
  final VoidCallback? onOpenSpaces;

  const SettingsScreen({super.key, this.onOpenSpaces});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final biometrics = context.watch<BiometricAuthController>();
    final user = state.currentUser;
    final space = state.space;
    final cycle = state.selectedCycle;
    final isDark = context.isDark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            _ProfileCard(
              name: user?.name ?? 'User',
              email: user?.email ?? '',
              avatarUrl: user?.avatarUrl,
              onTap: () => _push(context, ProfileScreen()),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (onOpenSpaces != null) ...[
              SectionHeader(title: l10n.mySpaces),
              _SettingsGroup(
                children: [
                  _SettingTile(
                    icon: Icons.workspaces_outline,
                    title: l10n.switchSpace,
                    subtitle: l10n.switchSpaceSubtitle,
                    onTap: onOpenSpaces,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            SectionHeader(title: l10n.space),
            _SettingsGroup(
              children: [
                _SettingTile(
                  icon: Icons.home_work_outlined,
                  title: l10n.spaceAndMembers,
                  subtitle: space?.name ?? l10n.noSpace,
                  onTap: () => _push(context, SpaceScreen()),
                ),
                _SettingTile(
                  icon: Icons.category_outlined,
                  title: l10n.categories,
                  subtitle: '${state.categories.length} categories',
                  onTap: () => _push(context, CategoriesScreen()),
                ),
              ],
            ),
            if (!state.isPersonalMode) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.spendingCycle),
              _SettingsGroup(
                children: [
                  _SettingTile(
                    icon: Icons.event_available_outlined,
                    title: l10n.currentCycle,
                    subtitle: cycle?.name ?? l10n.noActiveCycle,
                    onTap: cycle == null
                        ? null
                        : () => _showCycleDialog(context, state),
                  ),
                  if (state.closedCycles.isNotEmpty)
                    _SettingTile(
                      icon: Icons.history_rounded,
                      title: l10n.previousCycles,
                      subtitle:
                          l10n.previousCyclesCount(state.closedCycles.length),
                      onTap: () => _push(context, PreviousCyclesScreen()),
                    ),
                  if (state.isOwner)
                    _SettingTile(
                      icon: Icons.lock_outline_rounded,
                      title: cycle?.status == CycleStatus.closed
                          ? l10n.startNewCycle
                          : l10n.closeCurrentCycle,
                      subtitle: l10n.ownersCanManage,
                      onTap: () => _handleCycleAction(context, state),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.data),
            _SettingsGroup(
              children: [
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
                  trailing: state.unreadNotificationCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${state.unreadNotificationCount}',
                            style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => _showNotifications(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.appearance),
            _SettingsGroup(
              children: [
                _SettingTile(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
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
                  onTap: () => _showLanguagePicker(
                    context,
                    context.read<LocaleController>(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.security),
            _SettingsGroup(
              children: [
                if (biometrics.supported)
                  _SettingTile(
                    icon: Icons.fingerprint_rounded,
                    title: l10n.biometricLogin,
                    subtitle: biometrics.enabled ? l10n.onValue : l10n.offValue,
                    trailing: Switch(
                      value: biometrics.enabled,
                      onChanged: (v) =>
                          _toggleBiometric(context, biometrics, v),
                    ),
                    onTap: null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsGroup(
              children: [
                _SettingTile(
                  icon: Icons.logout_rounded,
                  title: l10n.signOut,
                  subtitle: l10n.signOutSubtitle,
                  destructive: true,
                  onTap: () => _confirmSignOut(context, state),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl - AppSpacing.sm),
            Center(
              child: Text(
                l10n.appName,
                style: AppText.overline.copyWith(color: context.palette.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                l10n.version,
                style:
                    AppText.caption.copyWith(color: context.palette.textMuted),
              ),
            ),
          ],
        ),
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
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.closeCycleTitle(cycle.name),
      message: l10n.closeCycleMessage,
      confirmLabel: l10n.closeCycle,
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (confirmed) {
      await state.closeCycle();
      if (!context.mounted) return;
      showToast(context, l10n.cycleClosed, type: ToastType.success);
    }
  }

  void _showCycleDialog(BuildContext context, AppState state) {
    showAppSheet(
      context: context,
      title: context.l10n.spendingCycle,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in state.cycles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    c.status == CycleStatus.closed
                        ? Icons.history_rounded
                        : Icons.radio_button_checked,
                    color: c.status == CycleStatus.closed
                        ? p.textMuted
                        : AppColors.positive,
                  ),
                  title: Text(c.name),
                  subtitle: Text(_cycleStatusLabel(sheetContext.l10n, c.status)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isOwner &&
                          state.space?.cycleType == CycleType.custom) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: sheetContext.l10n.renameCycle,
                          onPressed: () => _renameCycle(sheetContext, state, c),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Text(
                        _cycleDateRange(c),
                        style:
                            AppText.caption.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _push(context, CycleDetailScreen(cycleId: c.id));
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(sheetContext.l10n.done),
              ),
            ],
          ),
        );
      },
    );
  }

  String _cycleDateRange(Cycle c) {
    return '${c.startDate.month}/${c.startDate.year}';
  }

  Future<void> _renameCycle(
    BuildContext context,
    AppState state,
    Cycle cycle,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: cycle.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.renameCycleTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.cycleName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    final ok = await state.renameCycle(cycle.id, newName);
    if (!ok || !context.mounted) return;
    showToast(context, l10n.cycleRenamed, type: ToastType.success);
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.signOutTitle,
      message: l10n.signOutMessage,
      confirmLabel: l10n.signOut,
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) {
      await state.signOut();
    }
  }

  void _showLanguagePicker(BuildContext context, LocaleController controller) {
    final l10n = context.l10n;
    final current = controller.locale;
    showAppSheet(
      context: context,
      title: l10n.language,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        Widget option({
          required IconData icon,
          required String label,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: p.textSecondary),
            title: Text(label),
            trailing: selected
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: onTap,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                icon: Icons.settings_suggest_outlined,
                label: 'System',
                selected: current == null,
                onTap: () {
                  controller.setLocale(null);
                  Navigator.pop(sheetContext);
                },
              ),
              option(
                icon: Icons.language_rounded,
                label: l10n.english,
                selected: current == const Locale('en'),
                onTap: () {
                  controller.setLocale(const Locale('en'));
                  Navigator.pop(sheetContext);
                },
              ),
              option(
                icon: Icons.language_rounded,
                label: l10n.nepali,
                selected: current == const Locale('ne'),
                onTap: () {
                  controller.setLocale(const Locale('ne'));
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
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

/// Hairline-bordered surface grouping one settings section's rows, with
/// dividers between them.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.lg,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 68, endIndent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: HeroCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            MemberAvatar(
              name: name,
              avatarUrl: avatarUrl,
              size: 58,
              outline: true,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppText.titleL.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppText.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final p = context.palette;
    final accent = destructive ? AppColors.negative : AppColors.primary;
    return ListTile(
      onTap: onTap,
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppGradients.tint(accent, alpha: context.isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: accent),
      ),
      title: Text(
        title,
        style: AppText.titleS.copyWith(
          color: destructive ? AppColors.negative : p.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppText.labelM.copyWith(color: p.textSecondary),
            ),
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: p.textMuted,
                )
              : null),
    );
  }
}
