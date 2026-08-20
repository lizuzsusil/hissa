import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../widgets/cards.dart';
import '../widgets/misc.dart';
import 'personal/estimated_expense_sheet.dart';
import 'personal/personal_widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final isPersonal = state.isPersonalMode;

    // Personal (personal) spaces have no cycles or shares, so Insights shows
    // a filterable spending chart, category breakdown and lifetime summary.
    if (isPersonal) {
      return const _PersonalInsights();
    }

    final cycles = state.cycles;
    final cycle = state.selectedCycle;
    final cycleBalances = state.computeBalances();
    final categories = state.categories;
    final members = state.members;

    final monthlyData = <({String label, Money total})>[];
    for (final c in cycles) {
      monthlyData.add((
        label: formatMonthShort(c.startDate),
        total: state.totalSpent(c.id),
      ));
    }

    final categoryData = _categoryTotals(state.expensesInCycle);
    final memberPaid = _memberPaidTotals(state, cycleBalances, members);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insights)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              // Grouped members are represented by their Member Group.
              for (final m in members.where(
                (m) => !state.groupedUserIds.contains(m.userId),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberPaidRow(
                    name: m.name,
                    paid: memberPaid[m.userId] ?? Money.zero(),
                    total: cycleBalances.fold<int>(
                      0,
                      (sum, b) => sum + b.paid.paisa,
                    ),
                  ),
                ),
              for (final g in state.activeMemberGroups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberPaidRow(
                    name: g.name,
                    paid: memberPaid[g.id] ?? Money.zero(),
                    total: cycleBalances.fold<int>(
                      0,
                      (sum, b) => sum + b.paid.paisa,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _SummaryRow(cycles: cycles),
            ],
          ],
        ),
      ),
    );
  }

  void _showCyclePicker(
    BuildContext context,
    AppState state,
    List<Cycle> cycles,
  ) {
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
              child: Text(
                context.l10n.selectCycle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
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

Map<String, Money> _categoryTotals(List<Expense> expenses) {
  final totals = <String, Money>{};
  for (final e in expenses) {
    final id = e.categoryId ?? 'other';
    totals[id] = (totals[id] ?? Money.zero()) + e.amount;
  }
  return totals;
}

Map<String, Money> _memberPaidTotals(
  AppState state,
  List<BalanceInfo> balances,
  List<SpaceMember> members,
) {
  final totals = <String, Money>{};
  for (final b in balances) {
    totals[b.userId] = b.paid;
  }
  return totals;
}

enum _ChartGranularity { day, week, month, year }

enum _SpendingPeriod { monthly, yearly, lifetime }

/// Insights layout for personal spaces: a filterable spending chart
/// (ascending, chronological, with granularity + period controls), the
/// month's planned-vs-actual estimates, category breakdown and the lifetime
/// summary. No cycle picker or per-member settlement section.
class _PersonalInsights extends StatefulWidget {
  const _PersonalInsights();

  @override
  State<_PersonalInsights> createState() => _PersonalInsightsState();
}

class _PersonalInsightsState extends State<_PersonalInsights> {
  _ChartGranularity _granularity = _ChartGranularity.month;
  _SpendingPeriod _period = _SpendingPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;

    final range = _periodRange(state.personalExpenses, _period);
    final chart = _bucketPersonalSpending(
      state.personalExpenses,
      start: range.$1,
      end: range.$2,
      granularity: _granularity,
    );
    final scopeExpenses = state.personalExpenses
        .where((e) => !e.date.isBefore(range.$1) && !e.date.isAfter(range.$2))
        .toList();
    final scopeTotal = scopeExpenses.fold<Money>(
      Money.zero(),
      (sum, e) => sum + e.amount,
    );
    final periodLabel = _periodLabel(l10n, _period);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insights)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedControl<_SpendingPeriod>(
                    value: _period,
                    options: const [
                      SegmentOption(
                        value: _SpendingPeriod.monthly,
                        label: 'Monthly',
                      ),
                      SegmentOption(
                        value: _SpendingPeriod.yearly,
                        label: 'Yearly',
                      ),
                      SegmentOption(
                        value: _SpendingPeriod.lifetime,
                        label: 'Lifetime',
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _period = value;
                        _granularity = switch (value) {
                          _SpendingPeriod.monthly => _ChartGranularity.day,
                          _SpendingPeriod.yearly => _ChartGranularity.month,
                          _SpendingPeriod.lifetime => _ChartGranularity.month,
                        };
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SegmentedControl<_ChartGranularity>(
                    value: _granularity,
                    options: [
                      SegmentOption(
                        value: _ChartGranularity.day,
                        label: l10n.granularityDay,
                      ),
                      SegmentOption(
                        value: _ChartGranularity.week,
                        label: l10n.granularityWeek,
                      ),
                      SegmentOption(
                        value: _ChartGranularity.month,
                        label: l10n.granularityMonth,
                      ),
                      SegmentOption(
                        value: _ChartGranularity.year,
                        label: l10n.granularityYear,
                      ),
                    ],
                    onChanged: (value) => setState(() => _granularity = value),
                  ),
                  const SizedBox(height: 16),
                  _SpendingChartCard(
                    points: chart.points,
                    capped: chart.capped,
                    total: scopeTotal,
                    periodLabel: periodLabel,
                    granularity: _granularity,
                  ),
                  const SizedBox(height: 24),
                  if (_period == _SpendingPeriod.monthly) ...[
                    SectionHeader(title: l10n.estimatedExpenses),
                    EstimateProgressCard(
                      month: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                      ),
                      spent: state.personalTotalSpent(
                        DateTime(DateTime.now().year, DateTime.now().month),
                      ),
                      estimated: state.estimatedTotalForMonth(
                        DateTime(DateTime.now().year, DateTime.now().month),
                      ),
                      onAddEstimate: () => showEstimatedExpenseSheet(context),
                      onManageEstimates: () => showMonthEstimatesSheet(
                        context,
                        month: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SectionHeader(title: l10n.categoryBreakdown),
                  _CategoryPie(
                    categories: state.categories,
                    categoryData: _categoryTotals(scopeExpenses),
                  ),
                  const SizedBox(height: 24),
                  const _SummaryRow(cycles: null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single bar in the spending chart, in ascending chronological order.
class _ChartPoint {
  final DateTime start;
  final String label;
  final String tooltipLabel;
  final Money total;

  const _ChartPoint({
    required this.start,
    required this.label,
    required this.tooltipLabel,
    required this.total,
  });
}

/// Returns the inclusive [start, end] range for a spending period, ending at
/// the very end of today so same-day expenses are counted. The lifetime range
/// starts at the earliest recorded expense (or today).
(DateTime, DateTime) _periodRange(
  List<Expense> expenses,
  _SpendingPeriod period,
) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (period) {
    case _SpendingPeriod.monthly:
      return (DateTime(now.year, now.month, 1), todayEnd);
    case _SpendingPeriod.yearly:
      return (DateTime(now.year, 1, 1), todayEnd);
    case _SpendingPeriod.lifetime:
      final earliest = expenses.isEmpty
          ? null
          : expenses
              .map((e) => e.date)
              .reduce((a, b) => a.isBefore(b) ? a : b);
      return (earliest ?? todayStart, todayEnd);
  }
}

String _periodLabel(AppLocalizations l10n, _SpendingPeriod period) {
  switch (period) {
    case _SpendingPeriod.monthly:
      return l10n.periodMonthly;
    case _SpendingPeriod.yearly:
      return l10n.periodYearly;
    case _SpendingPeriod.lifetime:
      return l10n.periodLifetime;
  }
}

DateTime _startOfWeek(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

({List<_ChartPoint> points, bool capped}) _bucketPersonalSpending(
  List<Expense> expenses, {
  required DateTime start,
  required DateTime end,
  required _ChartGranularity granularity,
}) {
  // Build bucket boundaries from range start, aligned to the granularity.
  final starts = <DateTime>[];
  var cursor = switch (granularity) {
    _ChartGranularity.day => start,
    _ChartGranularity.week => _startOfWeek(start),
    _ChartGranularity.month => DateTime(start.year, start.month, 1),
    _ChartGranularity.year => DateTime(start.year, 1, 1),
  };
  var guard = 0;
  while (!cursor.isAfter(end) && guard < 6000) {
    starts.add(cursor);
    guard++;
    cursor = switch (granularity) {
      _ChartGranularity.day => cursor.add(const Duration(days: 1)),
      _ChartGranularity.week => cursor.add(const Duration(days: 7)),
      _ChartGranularity.month => DateTime(cursor.year, cursor.month + 1, 1),
      _ChartGranularity.year => DateTime(cursor.year + 1, 1, 1),
    };
  }

  final maxBuckets = switch (granularity) {
    _ChartGranularity.day => 31,
    _ChartGranularity.week => 16,
    _ChartGranularity.month => 24,
    _ChartGranularity.year => 12,
  };
  var capped = false;
  var visibleStarts = starts;
  if (starts.length > maxBuckets) {
    visibleStarts = starts.sublist(starts.length - maxBuckets);
    capped = true;
  }

  final byKey = <String, int>{};
  for (final e in expenses) {
    final d = e.date;
    if (d.isBefore(start) || d.isAfter(end)) continue;
    final bucket = switch (granularity) {
      _ChartGranularity.day => DateTime(d.year, d.month, d.day),
      _ChartGranularity.week => _startOfWeek(d),
      _ChartGranularity.month => DateTime(d.year, d.month, 1),
      _ChartGranularity.year => DateTime(d.year, 1, 1),
    };
    final key = bucket.toIso8601String();
    byKey[key] = (byKey[key] ?? 0) + e.amount.paisa;
  }

  final points = <_ChartPoint>[];
  for (final bucket in visibleStarts) {
    final key = bucket.toIso8601String();
    final paisa = byKey[key] ?? 0;
    points.add(
      _ChartPoint(
        start: bucket,
        label: _axisLabel(bucket, granularity, start, end),
        tooltipLabel: _tooltipLabel(bucket, granularity),
        total: Money(paisa),
      ),
    );
  }
  return (points: points, capped: capped);
}

String _axisLabel(
  DateTime bucket,
  _ChartGranularity granularity,
  DateTime rangeStart,
  DateTime end,
) {
  final spansYears = rangeStart.year != end.year;
  switch (granularity) {
    case _ChartGranularity.day:
      return spansYears
          ? DateFormat('d MMM').format(bucket)
          : DateFormat('d').format(bucket);
    case _ChartGranularity.week:
      return DateFormat('d MMM').format(bucket);
    case _ChartGranularity.month:
      return spansYears
          ? DateFormat('MMM yy').format(bucket)
          : DateFormat('MMM').format(bucket);
    case _ChartGranularity.year:
      return DateFormat('yyyy').format(bucket);
  }
}

String _tooltipLabel(DateTime bucket, _ChartGranularity granularity) {
  switch (granularity) {
    case _ChartGranularity.day:
      return DateFormat('d MMM yyyy').format(bucket);
    case _ChartGranularity.week:
      return DateFormat('d MMM yyyy').format(bucket);
    case _ChartGranularity.month:
      return DateFormat('MMMM yyyy').format(bucket);
    case _ChartGranularity.year:
      return DateFormat('yyyy').format(bucket);
  }
}

/// Card showing the personal spending chart in ascending chronological order,
/// with the selected scope's total on top, tooltips and a caption when only the
/// most recent buckets are shown.
class _SpendingChartCard extends StatelessWidget {
  final List<_ChartPoint> points;
  final bool capped;
  final Money total;
  final String periodLabel;
  final _ChartGranularity granularity;

  const _SpendingChartCard({
    required this.points,
    required this.capped,
    required this.total,
    required this.periodLabel,
    required this.granularity,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (total.isZero) {
      return SurfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChartHeader(total: total, periodLabel: periodLabel),
            const SizedBox(height: 12),
            EmptyState(
              icon: Icons.bar_chart_rounded,
              title: l10n.noSpendingChartTitle,
              message: l10n.noSpendingChartMessage,
            ),
          ],
        ),
      );
    }

    final maxValue = points.isEmpty
        ? 1.0
        : points.fold<double>(
            0,
            (m, p) => p.total.major > m ? p.total.major : m,
          );
    final barWidth = points.length > 20
        ? 8.0
        : points.length > 12
            ? 11.0
            : 20.0;
    final labelStep = (points.length / 6).ceil().clamp(1, points.length);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(total: total, periodLabel: periodLabel),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.18,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark
                            ? AppColors.borderDark
                            : AppColors.border)
                        .withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
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
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 ||
                            index >= points.length ||
                            (index % labelStep != 0 &&
                                index != points.length - 1)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[index].label,
                            style: TextStyle(
                              fontSize: 10.5,
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark
                        ? AppColors.surfaceAltDark
                        : const Color(0xFF22313F),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= points.length) return null;
                      final point = points[groupIndex];
                      return BarTooltipItem(
                        '${point.tooltipLabel}\n${formatMoney(point.total)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].total.major,
                          width: barWidth,
                          gradient: AppColors.heroGradient,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (capped) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 13,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.showingRecentWindow,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color:
                        isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final Money total;
  final String periodLabel;

  const _ChartHeader({required this.total, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.spendingOverview,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(total),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.spentInPeriod(formatMoneyCompact(total), periodLabel),
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
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

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
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
                          gradient: AppGradients
                              .barChart[i % AppGradients.barChart.length],
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
          for (final entry in data.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      gradient: AppGradients
                          .barChart[entry.key % AppGradients.barChart.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    entry.value.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(entry.value.total),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

class _CategoryPie extends StatelessWidget {
  final List<Category> categories;
  final Map<String, Money> categoryData;

  const _CategoryPie({required this.categories, required this.categoryData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final total = categoryData.values.fold<Money>(
      Money.zero(),
      (a, b) => a + b,
    );

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
      final category = categories.where((c) => c.id == e.key).firstOrNull;
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

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
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
                      color:
                          categories
                                  .where((c) => c.id == e.key)
                                  .firstOrNull
                                  ?.colorValue ==
                              null
                          ? AppColors.primary
                          : Color(
                              categories
                                  .where((c) => c.id == e.key)
                                  .firstOrNull!
                                  .colorValue!,
                            ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      categories
                              .where((c) => c.id == e.key)
                              .firstOrNull
                              ?.name ??
                          l10n.other,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
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
    final fraction = total <= 0 ? 0.0 : paid.paisa / total;
    final color = avatarColorFor(name);
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(paid),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  color: color,
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
  final List<Cycle>? cycles;

  const _SummaryRow({this.cycles});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final allExpenses = state.repo.expenses;
    final totalAllTime = allExpenses.fold<Money>(
      Money.zero(),
      (sum, e) => sum + e.amount,
    );
    final totalExpenses = allExpenses.length;
    final avg = totalExpenses == 0
        ? Money.zero()
        : Money((totalAllTime.paisa / totalExpenses).round());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.tertiary.withValues(alpha: 0.10),
            AppColors.tertiary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.tertiary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lifetimeSummary,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
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
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
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
