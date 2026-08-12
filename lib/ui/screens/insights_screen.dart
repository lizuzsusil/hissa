import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../logic/balances.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/misc.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final cycles = state.cycles;
    final cycle = state.selectedCycle;
    final cycleBalances = state.computeBalances();
    final categories = state.categories;
    final members = state.members;

    final monthlyData = <({String label, Money total})>[];
    for (final c in cycles) {
      monthlyData.add((label: formatMonthShort(c.startDate), total: state.totalSpent(c.id)));
    }

    final categoryData = _categoryTotals(state);
    final memberPaid = _memberPaidTotals(state, cycleBalances, members);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insights)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (cycles.length > 1) ...[
            SectionHeader(title: l10n.monthlySpending),
            _MonthlyBarChart(data: monthlyData.reversed.toList()),
            const SizedBox(height: 24),
          ],
          if (cycle != null) ...[
            SectionHeader(
              title: l10n.cycleNameByCategory(cycle.name),
              actionLabel: l10n.cycle,
              onAction: () => _showCyclePicker(context, state, cycles),
            ),
            _CategoryPie(categories: categories, categoryData: categoryData),
            const SizedBox(height: 24),
            SectionHeader(title: l10n.whoPaidThisCycle),
            const SizedBox(height: 4),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberPaidRow(
                  name: m.name,
                  paid: memberPaid[m.userId] ?? Money.zero(),
                  total: cycleBalances.fold<int>(
                          0, (sum, b) => sum + b.paid.paisa),
                ),
              ),
            const SizedBox(height: 12),
            _SummaryRow(cycles: cycles),
          ],
        ],
      ),
    );
  }

  void _showCyclePicker(
      BuildContext context, AppState state, List<Cycle> cycles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.selectCycle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final c in cycles)
              ListTile(
                leading: Icon(
                  c.status == CycleStatus.closed
                      ? Icons.history_rounded
                      : Icons.radio_button_checked,
                  color: c.id == state.selectedCycle?.id
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                title: Text(c.name),
                subtitle: Text(_cycleStatusLabel(context.l10n, c.status)),
                onTap: () {
                  state.selectCycle(c.id);
                  Navigator.pop(context);
                },
              ),
          ],
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

Map<String, Money> _categoryTotals(AppState state) {
  final totals = <String, Money>{};
  for (final e in state.expensesInCycle) {
    final id = e.categoryId ?? 'other';
    totals[id] = (totals[id] ?? Money.zero()) + e.amount;
  }
  return totals;
}

Map<String, Money> _memberPaidTotals(
  AppState state,
  List<BalanceInfo> balances,
  List<HouseholdMember> members,
) {
  final totals = <String, Money>{};
  for (final b in balances) {
    totals[b.userId] = b.paid;
  }
  return totals;
}

class _MonthlyBarChart extends StatelessWidget {
  final List<({String label, Money total})> data;

  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = data.isEmpty
        ? 1.0
        : data.fold<double>(0, (m, d) => d.total.major > m ? d.total.major : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? AppColors.borderDark : AppColors.border)
                        .withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value >= 1000
                            ? '${(value / 1000).toStringAsFixed(0)}k'
                            : value.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[index].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].total.major,
                          width: 22,
                          gradient: AppColors.heroGradient,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final d in data)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(d.label,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary)),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(d.total),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  final List<Category> categories;
  final Map<String, Money> categoryData;

  const _CategoryPie({
    required this.categories,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final total = categoryData.values.fold<Money>(Money.zero(), (a, b) => a + b);

    final entries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty || total.isZero) {
      return EmptyState(
        icon: Icons.donut_small_outlined,
        title: l10n.nothingToChart,
        message: l10n.nothingToChartMessage,
      );
    }

    final sections = entries.map((e) {
      final category =
          categories.where((c) => c.id == e.key).firstOrNull;
      final color = category?.colorValue == null
          ? AppColors.primary
          : Color(category!.colorValue!);
      return PieChartSectionData(
        value: e.value.major,
        color: color,
        radius: 58,
        title: '${(e.value.paisa / total.paisa * 100).round()}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 42,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: categories
                          .where((c) => c.id == e.key)
                          .firstOrNull
                          ?.colorValue == null
                          ? AppColors.primary
                          : Color(categories
                              .where((c) => c.id == e.key)
                              .firstOrNull!
                              .colorValue!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      categories.where((c) => c.id == e.key).firstOrNull?.name ??
                          l10n.other,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatMoneyCompact(e.value, showSymbol: false),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberPaidRow extends StatelessWidget {
  final String name;
  final Money paid;
  final int total;

  const _MemberPaidRow({
    required this.name,
    required this.paid,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction = total <= 0 ? 0.0 : paid.paisa / total;
    return Row(
      children: [
        MemberAvatar(name: name, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(paid),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? AppColors.surfaceAltDark
                      : AppColors.surfaceAlt,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<Cycle> cycles;

  const _SummaryRow({required this.cycles});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final allExpenses = state.repo.expenses;
    final totalAllTime = allExpenses.fold<Money>(
        Money.zero(), (sum, e) => sum + e.amount);
    final totalExpenses = allExpenses.length;
    final avg = totalExpenses == 0
        ? Money.zero()
        : Money((totalAllTime.paisa / totalExpenses).round());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.lifetimeSummary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: l10n.totalSpent,
                  value: formatMoneyCompact(totalAllTime),
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.expenses,
                  value: '$totalExpenses',
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.average,
                  value: formatMoneyCompact(avg),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
