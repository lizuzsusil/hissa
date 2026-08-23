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
import '../widgets/sheets.dart';
import 'personal/personal_widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final isPersonal = state.isPersonalMode;

    // Personal (personal) spaces have no cycles or shares, so Insights shows
    // a filterable spending chart, category breakdown, month-over-month
    // comparison and a top-categories leaderboard for the selected window.
    if (isPersonal) {
      return const _PersonalInsights();
    }

    final cycles = state.cycles;
    final cycle = state.selectedCycle;

    // Group spaces: before the first cycle exists the old layout rendered a
    // blank page — surface an explicit empty state instead so there is
    // always something on screen.
    if (cycle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.insights)),
        body: EmptyState(
          icon: Icons.donut_small_outlined,
          title: l10n.cycle,
          message: l10n.loadingSpace,
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            100,
          ),
          children: [
            if (cycles.length > 1) ...[
              SectionHeader(title: l10n.monthlySpending),
              _MonthlyBarChart(data: monthlyData.reversed.toList()),
              const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
            ],
            SectionHeader(
              title: l10n.cycleNameByCategory(cycle.name),
              actionLabel: l10n.cycle,
              onAction: () => _showCyclePicker(context, state, cycles),
            ),
            _CategoryPie(categories: categories, categoryData: categoryData),
            const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
            SectionHeader(title: l10n.whoPaidThisCycle),
            const SizedBox(height: AppSpacing.xs),
            // Grouped members are represented by their Member Group.
            for (final m in members.where(
              (m) => !state.groupedUserIds.contains(m.userId),
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _MemberPaidRow(
                  name: g.name,
                  paid: memberPaid[g.id] ?? Money.zero(),
                  total: cycleBalances.fold<int>(
                    0,
                    (sum, b) => sum + b.paid.paisa,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _SummaryRow(cycles: cycles),
          ],
        ),
      ),
    );
  }

  Future<void> _showCyclePicker(
    BuildContext context,
    AppState state,
    List<Cycle> cycles,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final selectedId = state.selectedCycle?.id;
    return showAppSheet(
      context: context,
      title: l10n.cycle,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          for (final c in cycles)
            ListTile(
              leading: Icon(
                c.status == CycleStatus.closed
                    ? Icons.history_rounded
                    : Icons.radio_button_checked,
                color: c.id == selectedId ? AppColors.primary : p.textMuted,
              ),
              title: Text(c.name),
              subtitle: Text(_cycleStatusLabel(l10n, c.status)),
              trailing: c.id == selectedId
                  ? const Icon(Icons.check_rounded,
                      size: 20, color: AppColors.primary)
                  : null,
              onTap: () {
                state.selectCycle(c.id);
                Navigator.pop(sheetContext);
              },
            ),
        ],
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

/// Single combined view filter for the personal spending chart: rolling
/// windows from "last 7 days" up to "last 5 years". Lifetime data is shown
/// via separate summary cards further down the page.
enum _ChartScope { daily, weekly, monthly, yearly }

/// Insights layout for personal spaces: a spending chart with a single
/// rolling-window filter (daily/weekly/monthly/yearly), an optional
/// planned-vs-actual overlay, the category breakdown, a month-over-month
/// comparison and a top-categories leaderboard for the selected window. No
/// cycle picker or per-member settlement section.
class _PersonalInsights extends StatefulWidget {
  const _PersonalInsights();

  @override
  State<_PersonalInsights> createState() => _PersonalInsightsState();
}

class _PersonalInsightsState extends State<_PersonalInsights> {
  _ChartScope _scope = _ChartScope.monthly;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;

    final range = _scopeRange(state.personalExpenses, _scope);
    final chart = _bucketPersonalSpending(
      state.personalExpenses,
      start: range.$1,
      end: range.$2,
      granularity: _scopeGranularity(_scope),
      plannedForMonth: (month) => state.estimatedTotalForMonth(month),
    );
    final scopeExpenses = state.personalExpenses
        .where((e) => !e.date.isBefore(range.$1) && !e.date.isAfter(range.$2))
        .toList();
    final scopeTotal = scopeExpenses.fold<Money>(
      Money.zero(),
      (sum, e) => sum + e.amount,
    );
    final scopeCategoryData = _categoryTotals(scopeExpenses);
    final caption = _scopeCaption(l10n, _scope);

    final now = DateTime.now();

    // Month-over-month comparison.
    final currentMonthTotal =
        state.personalTotalSpent(DateTime(now.year, now.month));
    final previousMonthTotal =
        state.personalTotalSpent(DateTime(now.year, now.month - 1));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insights)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            100,
          ),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedControl<_ChartScope>(
                    value: _scope,
                    options: [
                      SegmentOption(
                        value: _ChartScope.daily,
                        label: l10n.periodDaily,
                      ),
                      SegmentOption(
                        value: _ChartScope.weekly,
                        label: l10n.periodWeekly,
                      ),
                      SegmentOption(
                        value: _ChartScope.monthly,
                        label: l10n.periodMonthly,
                      ),
                      SegmentOption(
                        value: _ChartScope.yearly,
                        label: l10n.periodYearly,
                      ),
                    ],
                    onChanged: (value) => setState(() => _scope = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SpendingChartCard(
                    title: l10n.spendingOverview,
                    points: chart.points,
                    capped: chart.capped,
                    total: scopeTotal,
                    periodLabel: caption,
                  ),
                  const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
                  SectionHeader(title: l10n.categoryBreakdown),
                  _CategoryPie(
                    categories: state.categories,
                    categoryData: scopeCategoryData,
                  ),
                  if (currentMonthTotal.isPositive ||
                      previousMonthTotal.isPositive) ...[
                    const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
                    SectionHeader(title: l10n.monthCompare),
                    _MonthCompareCard(
                      current: currentMonthTotal,
                      previous: previousMonthTotal,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single bar group in the spending chart, in ascending chronological order.
class _ChartPoint {
  final DateTime start;
  final String label;
  final String tooltipLabel;
  final Money total;
  final Money planned;

  const _ChartPoint({
    required this.start,
    required this.label,
    required this.tooltipLabel,
    required this.total,
    required this.planned,
  });
}

/// Returns the inclusive [start, end] range for a chart scope, ending at the
/// very end of today so same-day expenses are counted.
(DateTime, DateTime) _scopeRange(List<Expense> expenses, _ChartScope scope) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (scope) {
    case _ChartScope.daily:
      return (todayStart.subtract(const Duration(days: 6)), todayEnd);
    case _ChartScope.weekly:
      return (todayStart.subtract(const Duration(days: 41)), todayEnd);
    case _ChartScope.monthly:
      return (DateTime(now.year, now.month - 5, 1), todayEnd);
    case _ChartScope.yearly:
      return (DateTime(now.year - 4, 1, 1), todayEnd);
  }
}

_ChartGranularity _scopeGranularity(_ChartScope scope) {
  switch (scope) {
    case _ChartScope.daily:
      return _ChartGranularity.day;
    case _ChartScope.weekly:
      return _ChartGranularity.week;
    case _ChartScope.monthly:
      return _ChartGranularity.month;
    case _ChartScope.yearly:
      return _ChartGranularity.year;
  }
}

String _scopeCaption(AppLocalizations l10n, _ChartScope scope) {
  switch (scope) {
    case _ChartScope.daily:
      return l10n.lastDays;
    case _ChartScope.weekly:
      return l10n.lastWeeks;
    case _ChartScope.monthly:
      return l10n.lastMonths;
    case _ChartScope.yearly:
      return l10n.lastYears;
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
  Money Function(DateTime month)? plannedForMonth,
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
    // Planned amounts are monthly, so they only map onto month-bucketed
    // views (monthly + lifetime scopes).
    final planned =
        granularity == _ChartGranularity.month && plannedForMonth != null
            ? plannedForMonth(bucket)
            : Money.zero();
    points.add(
      _ChartPoint(
        start: bucket,
        label: _axisLabel(bucket, granularity, start, end),
        tooltipLabel: _tooltipLabel(bucket, granularity),
        total: Money(paisa),
        planned: planned,
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
      return DateFormat('MMM d').format(bucket);
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
/// with the selected scope's total on top, tooltips, a planned-vs-actual
/// overlay when a monthly plan exists, and a caption when only the most
/// recent buckets are shown.
class _SpendingChartCard extends StatelessWidget {
  final String title;
  final List<_ChartPoint> points;
  final bool capped;
  final Money total;
  final String periodLabel;

  const _SpendingChartCard({
    required this.title,
    required this.points,
    required this.capped,
    required this.total,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final dark = context.isDark;

    if (total.isZero) {
      return SurfaceCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChartHeader(title: title, total: total, periodLabel: periodLabel),
            const SizedBox(height: AppSpacing.md),
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
            (m, p) {
              final peak = p.total.major > p.planned.major
                  ? p.total.major
                  : p.planned.major;
              return peak > m ? peak : m;
            },
          );
    final barWidth = points.length > 20
        ? 8.0
        : points.length > 12
            ? 11.0
            : 20.0;
    final labelStep = (points.length / 6).ceil().clamp(1, points.length);
    final hasPlanned = points.any((p) => p.planned.isPositive);
    final plannedColor = dark
        ? AppColors.primaryBright.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.28);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(title: title, total: total, periodLabel: periodLabel),
          const SizedBox(height: AppSpacing.lg),
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
                    color: p.border.withValues(alpha: 0.6),
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
                        style: TextStyle(fontSize: 10, color: p.textMuted),
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
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            points[index].label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: p.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        dark ? const Color(0xFF272D38) : const Color(0xFF20242C),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= points.length) return null;
                      final point = points[groupIndex];
                      final buffer = StringBuffer(
                        '${point.tooltipLabel}\n'
                        '${l10n.chartSpent}: ${formatMoney(point.total)}',
                      );
                      if (point.planned.isPositive) {
                        buffer.write(
                          '\n${l10n.chartPlanned}: ${formatMoney(point.planned)}',
                        );
                      }
                      return BarTooltipItem(
                        buffer.toString(),
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
                        if (points[i].planned.isPositive)
                          BarChartRodData(
                            toY: points[i].planned.major,
                            width: barWidth * 0.55,
                            color: plannedColor,
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
          if (hasPlanned) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _LegendDot(color: AppColors.primary, label: l10n.chartSpent),
                const SizedBox(width: AppSpacing.xl),
                _LegendDot(color: plannedColor, label: l10n.chartPlanned),
              ],
            ),
          ],
          if (capped) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 13,
                  color: p.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.showingRecentWindow,
                  style: AppText.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: p.textMuted,
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppText.labelM.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

/// Two-bar comparison of the current month against the previous one.
class _MonthCompareCard extends StatelessWidget {
  final Money current;
  final Money previous;

  const _MonthCompareCard({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final dark = context.isDark;
    final maxValue = [current.major, previous.major, 1.0]
        .reduce((a, b) => a > b ? a : b);
    final plannedColor = dark
        ? AppColors.primaryBright.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.28);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.25,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: p.border.withValues(alpha: 0.6),
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
                        style: TextStyle(fontSize: 10, color: p.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index > 1) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            index == 0 ? l10n.lastMonth : l10n.thisMonth,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: p.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        dark ? const Color(0xFF272D38) : const Color(0xFF20242C),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 || groupIndex > 1) return null;
                      final value = groupIndex == 0 ? previous : current;
                      return BarTooltipItem(
                        '${groupIndex == 0 ? l10n.lastMonth : l10n.thisMonth}\n${formatMoney(value)}',
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
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: previous.major,
                        width: 22,
                        color: plannedColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: current.major,
                        width: 22,
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LegendDot(color: AppColors.primary, label: l10n.thisMonth),
              const SizedBox(width: AppSpacing.xl),
              _LegendDot(color: plannedColor, label: l10n.lastMonth),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final String title;
  final Money total;
  final String periodLabel;

  const _ChartHeader({
    required this.title,
    required this.total,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.titleM.copyWith(color: p.textPrimary),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(total),
              style: AppText.titleL.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.spentInPeriod(formatMoneyCompact(total), periodLabel),
              style: AppText.caption.copyWith(color: p.textMuted),
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
    final p = context.palette;
    final maxValue = data.isEmpty
        ? 1.0
        : data.fold<double>(0, (m, d) => d.total.major > m ? d.total.major : m);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
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
                    color: p.border.withValues(alpha: 0.6),
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
                        style: TextStyle(fontSize: 10, color: p.textMuted),
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
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            data[index].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.textSecondary,
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
          const SizedBox(height: AppSpacing.md),
          for (final entry in data.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    entry.value.label,
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(entry.value.total),
                    style: AppText.labelM.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
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
    final p = context.palette;
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
      padding: const EdgeInsets.all(AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.lg),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      categories
                              .where((c) => c.id == e.key)
                              .firstOrNull
                              ?.name ??
                          l10n.other,
                      style: AppText.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatMoneyCompact(e.value, showSymbol: false),
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.textSecondary,
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
    final p = context.palette;
    final fraction = total <= 0 ? 0.0 : paid.paisa / total;
    final color = avatarColorFor(name);
    return Row(
      children: [
        MemberAvatar(name: name, size: 34),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoneyCompact(paid),
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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

/// Lifetime totals strip for group spaces: violet-tinted surface with three
/// labelled cells (total spent, expense count, average).
class _SummaryRow extends StatelessWidget {
  final List<Cycle>? cycles;

  const _SummaryRow({this.cycles});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final p = context.palette;
    final dark = context.isDark;
    final allExpenses = state.repo.expenses;
    final totalAllTime = allExpenses.fold<Money>(
      Money.zero(),
      (sum, e) => sum + e.amount,
    );
    final totalExpenses = allExpenses.length;
    final avg = totalExpenses == 0
        ? Money.zero()
        : Money((totalAllTime.paisa / totalExpenses).round());

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.tint(
          AppColors.tertiary,
          alpha: dark ? 0.16 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.22)),
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        color: Colors.transparent,
        border: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lifetimeSummary,
              style: AppText.titleM.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
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
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.labelM.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppText.titleS.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
