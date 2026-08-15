import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../state/shell_tab_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import 'dashboard_screen.dart';
import 'expense_form_screen.dart';
import 'expenses_screen.dart';
import 'insights_screen.dart';
import 'personal_dashboard_screen.dart';
import 'settle_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  /// Invoked when the user wants to return to the Spaces dashboard to switch
  /// between Spaces.
  final VoidCallback? onBackToSpaces;

  const ShellScreen({super.key, this.onBackToSpaces});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final ShellTabController _tabController = ShellTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPersonal = state.isPersonalMode;
    final settings = SettingsScreen(onOpenSpaces: widget.onBackToSpaces);
    final screens = isPersonal
        ? <Widget>[
            const PersonalDashboardScreen(),
            const ExpensesScreen(),
            const InsightsScreen(),
            settings,
          ]
        : <Widget>[
            const DashboardScreen(),
            const ExpensesScreen(),
            const SettleScreen(),
            const InsightsScreen(),
            settings,
          ];
    return ChangeNotifierProvider<ShellTabController>.value(
      value: _tabController,
      child: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) => PopScope(
          canPop: _tabController.index == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _tabController.index != 0) {
              _tabController.switchTo(0);
            }
          },
          child: Scaffold(
            body: state.isSwitchingSpace
                ? const _SpaceSwitchingScreen()
                : IndexedStack(index: _tabController.index, children: screens),
            floatingActionButton: _tabController.index == screens.length - 1
                ? null
                : _FloatingAddButton(),
            bottomNavigationBar: _NavBar(
              index: _tabController.index,
              isPersonal: isPersonal,
              onChanged: _tabController.switchTo,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceSwitchingScreen extends StatelessWidget {
  const _SpaceSwitchingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.loadingSpace,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cycle = state.selectedCycle;
    if (!state.isPersonalMode &&
        (cycle == null || cycle.status == CycleStatus.closed)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 30),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final bool isPersonal;
  final ValueChanged<int> onChanged;

  const _NavBar({
    required this.index,
    required this.isPersonal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final items = isPersonal
        ? [
            (Icons.home_rounded, Icons.home_outlined, l10n.home),
            (
              Icons.receipt_long_rounded,
              Icons.receipt_long_outlined,
              l10n.expenses,
            ),
            (
              Icons.donut_small_rounded,
              Icons.donut_small_outlined,
              l10n.insights,
            ),
            (Icons.settings_rounded, Icons.settings_outlined, l10n.settings),
          ]
        : [
            (Icons.home_rounded, Icons.home_outlined, l10n.home),
            (
              Icons.receipt_long_rounded,
              Icons.receipt_long_outlined,
              l10n.expenses,
            ),
            (
              Icons.account_balance_wallet_rounded,
              Icons.account_balance_wallet_outlined,
              l10n.settle,
            ),
            (
              Icons.donut_small_rounded,
              Icons.donut_small_outlined,
              l10n.insights,
            ),
            (Icons.settings_rounded, Icons.settings_outlined, l10n.settings),
          ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: cardShadow(),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    selected: index == i,
                    icon: index == i ? items[i].$1 : items[i].$2,
                    label: items[i].$3,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
