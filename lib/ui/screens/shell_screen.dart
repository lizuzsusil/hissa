import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../state/shell_tab_controller.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'expense_form_screen.dart';
import 'expenses_screen.dart';
import 'insights_screen.dart';
import 'settle_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final ShellTabController _tabController = ShellTabController();

  late final List<Widget> _screens = const [
    DashboardScreen(),
    ExpensesScreen(),
    SettleScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShellTabController>.value(
      value: _tabController,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) =>
              IndexedStack(index: _tabController.index, children: _screens),
        ),
        floatingActionButton: _FloatingAddButton(),
        bottomNavigationBar: ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) => _NavBar(
            index: _tabController.index,
            onChanged: _tabController.switchTo,
          ),
        ),
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final cycle = state.selectedCycle;
    if (cycle == null || cycle.status == CycleStatus.closed) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ExpenseFormScreen(),
        ));
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        l10n.add,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _NavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final items = [
      (Icons.home_rounded, Icons.home_outlined, l10n.home),
      (Icons.receipt_long_rounded, Icons.receipt_long_outlined, l10n.expenses),
      (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, l10n.settle),
      (Icons.donut_small_rounded, Icons.donut_small_outlined, l10n.insights),
      (Icons.settings_rounded, Icons.settings_outlined, l10n.settings),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
