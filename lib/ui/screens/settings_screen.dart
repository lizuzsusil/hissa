import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
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
    final user = state.currentUser;
    final household = state.household;
    final cycle = state.selectedCycle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _ProfileCard(
            name: user?.name ?? 'User',
            email: user?.email ?? '',
            onTap: () => _push(context, ProfileScreen()),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Household'),
          _SettingTile(
            icon: Icons.home_work_outlined,
            title: 'Household & members',
            subtitle: household?.name ?? 'No household',
            onTap: () => _push(context, HouseholdScreen()),
          ),
          _SettingTile(
            icon: Icons.category_outlined,
            title: 'Categories',
            subtitle: '${state.categories.length} categories',
            onTap: () => _push(context, CategoriesScreen()),
          ),
          _SettingTile(
            icon: Icons.currency_rupee,
            title: 'Currency',
            subtitle: household?.currency ?? 'NPR',
            onTap: () => _showCurrencyPicker(context, state),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Spending cycle'),
          _SettingTile(
            icon: Icons.event_available_outlined,
            title: 'Current cycle',
            subtitle: cycle?.name ?? 'No active cycle',
            onTap: cycle == null
                ? null
                : () => _showCycleDialog(context, state),
          ),
          if (state.isOwner) ...[
            _SettingTile(
              icon: Icons.lock_outline_rounded,
              title: cycle?.status == CycleStatus.closed
                  ? 'Start a new cycle'
                  : 'Close current cycle',
              subtitle: 'Owners can manage cycles',
              onTap: () => _handleCycleAction(context, state),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Data'),
          _SettingTile(
            icon: Icons.download_outlined,
            title: 'Export',
            subtitle: 'CSV of the current cycle',
            onTap: () => _push(context, ExportScreen()),
          ),
          _SettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Expenses, balances & reminders',
            onTap: () => _showNotifications(context),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Appearance'),
          _SettingTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'Dark mode',
            subtitle: isDark ? 'On' : 'Off',
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
          const SizedBox(height: 24),
          _SettingTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Switch account or household',
            destructive: true,
            onTap: () => _confirmSignOut(context, state),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Hissa · Household Expense Tracker',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v1.0.0',
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

  Future<void> _handleCycleAction(BuildContext context, AppState state) async {
    final cycle = state.selectedCycle;
    if (cycle == null) return;
    if (cycle.status == CycleStatus.closed) {
      await state.startNewCycle();
      if (!context.mounted) return;
      showToast(context, 'New cycle started', type: ToastType.success);
      return;
    }
    final proposals = state.settlementProposals();
    if (proposals.isNotEmpty) {
      showToast(
        context,
        'Settle all balances before closing the cycle',
        type: ToastType.warning,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close ${cycle.name}?'),
        content: const Text(
          'The cycle becomes read-only and historical. A new cycle will start next month.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Close cycle'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.closeCycle();
      if (!context.mounted) return;
      showToast(context, 'Cycle closed', type: ToastType.success);
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
              const Text(
                'Spending cycles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                  subtitle: Text(c.status.label),
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
              const Text(
                'Currency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Push notifications arrive with Firebase Cloud Messaging in the connected build.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.signOut();
    }
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
