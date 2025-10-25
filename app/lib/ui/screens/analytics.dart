import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../utils/formatters.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateRange range = ref.watch(analyticsRangeProvider);
    final AsyncValue<AnalyticsSnapshot> snapshot =
        ref.watch(analyticsSnapshotProvider);
    final LedgerDatabase database = ref.watch(databaseProvider);
    final Map<String, Account> accounts = <String, Account>{
      for (final Account account in database.accounts) account.id: account,
    };

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.text('analysisTitle')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: snapshot.when(
          data: (AnalyticsSnapshot data) {
            final Map<String, double> accountBreakdown =
                database.groupByAccount(range: range);
            return ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                _AnalyticsRangeSelector(range: data.range),
                const SizedBox(height: 24),
                _AnalyticsCard(
                  title: '收支比例',
                  child: _IncomeExpensePie(
                    currency: data.currency,
                    incomeSegments: data.incomeSegments,
                    expenseSegments: data.expenseSegments,
                  ),
                ),
                const SizedBox(height: 16),
                _AnalyticsCard(
                  title: '金流趋势',
                  child: _FlowTrendChart(snapshot: data),
                ),
                const SizedBox(height: 16),
                _AnalyticsCard(
                  title: '总财富趋势',
                  child: _WealthTrendChart(snapshot: data),
                ),
                const SizedBox(height: 16),
                _AnalyticsCard(
                  title: l10n.text('accountDistribution'),
                  child: _AccountDistribution(
                    breakdown: accountBreakdown,
                    accounts: accounts,
                    baseCurrency: data.currency,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Text('加载失败：$error'),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsRangeSelector extends ConsumerWidget {
  const _AnalyticsRangeSelector({required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnalyticsRangePreset preset =
        ref.watch(analyticsRangePresetProvider);
    final ThemeData theme = Theme.of(context);
    final Map<AnalyticsRangePreset, String> labels =
        <AnalyticsRangePreset, String>{
      AnalyticsRangePreset.thisWeek: '本周',
      AnalyticsRangePreset.thisMonth: '本月',
      AnalyticsRangePreset.thisQuarter: '本季度',
      AnalyticsRangePreset.custom: '自定义',
    };

    Future<void> pickCustomRange() async {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(2100, 12, 31),
        initialDateRange: DateTimeRange(
          start: range.start,
          end: range.end,
        ),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: const Color(0xFF6366F1),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (picked != null) {
        ref.read(analyticsCustomRangeProvider.notifier).state = DateRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
        ref.read(analyticsRangePresetProvider.notifier).state =
            AnalyticsRangePreset.custom;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '时间范围',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: labels.entries.map((MapEntry<AnalyticsRangePreset, String> entry) {
            final bool selected = preset == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (bool value) {
                if (!value) {
                  return;
                }
                if (entry.key == AnalyticsRangePreset.custom) {
                  pickCustomRange();
                } else {
                  ref
                      .read(analyticsRangePresetProvider.notifier)
                      .state = entry.key;
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${formatDate(range.start)} - ${formatDate(range.end)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _IncomeExpensePie extends StatelessWidget {
  const _IncomeExpensePie({
    required this.currency,
    required this.incomeSegments,
    required this.expenseSegments,
  });

  final String currency;
  final List<ChartSegment> incomeSegments;
  final List<ChartSegment> expenseSegments;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget buildPie(String title, List<ChartSegment> segments, Color color) {
      final double total =
          segments.fold<double>(0, (double sum, ChartSegment seg) => sum + seg.value);
      if (segments.isEmpty || total == 0) {
        return _PiePlaceholder(title: title);
      }
      final List<PieChartSectionData> sections = segments
          .take(6)
          .map(
            (ChartSegment segment) => PieChartSectionData(
              title: segment.label,
              value: segment.value,
              radius: 60,
              color: color.withValues(
                alpha: 0.4 + (segment.value / total * 0.6),
              ),
              titleStyle: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          )
          .toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '合计：${formatCurrency(total, currency)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth > 600;
        final List<Widget> children = <Widget>[
          Expanded(
            child: buildPie('收入', incomeSegments, const Color(0xFFE53935)),
          ),
          const SizedBox(width: 16, height: 16),
          Expanded(
            child: buildPie('支出', expenseSegments, const Color(0xFF34C759)),
          ),
        ];

        return wide
            ? Row(
                children: children,
              )
            : Column(
                children: children,
              );
      },
    );
  }
}

class _FlowTrendChart extends StatelessWidget {
  const _FlowTrendChart({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.dailyFlows.isEmpty) {
      return const _EmptyPlaceholder(message: '暂无金流数据');
    }

    final DateTime start = DateTime(
      snapshot.range.start.year,
      snapshot.range.start.month,
      snapshot.range.start.day,
    );
    final List<FlSpot> incomeSpots = <FlSpot>[];
    final List<FlSpot> expenseSpots = <FlSpot>[];
    double maxY = 0;

    for (final DailyFlowPoint point in snapshot.dailyFlows) {
      final double x = point.date.difference(start).inDays.toDouble();
      final double income = point.income;
      final double expense = point.expense;
      incomeSpots.add(FlSpot(x, income));
      expenseSpots.add(FlSpot(x, expense));
      maxY = math.max(maxY, math.max(income, expense));
    }

    final double yInterval = _niceStep(0, maxY);
    final double maxX =
        snapshot.dailyFlows.last.date.difference(start).inDays.toDouble();
    final double xInterval = _safeXIntervalDays(start, snapshot.range.end);

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(maxX, 1),
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.1,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: xInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final DateTime label =
                      start.add(Duration(days: value.round()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${label.month}/${label.day}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: const Color(0xFFE53935),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
              ),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: const Color(0xFF34C759),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF34C759).withValues(alpha: 0.12),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            horizontalInterval: yInterval,
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _WealthTrendChart extends StatelessWidget {
  const _WealthTrendChart({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.wealthTrend.isEmpty) {
      return const _EmptyPlaceholder(message: '暂无财富数据');
    }

    final DateTime start = DateTime(
      snapshot.range.start.year,
      snapshot.range.start.month,
      snapshot.range.start.day,
    );

    final List<FlSpot> spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final WealthPoint point in snapshot.wealthTrend) {
      final double x = point.date.difference(start).inDays.toDouble();
      final double y = point.total;
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      spots.add(FlSpot(x, y));
    }

    if ((maxY - minY).abs() < 0.0001) {
      maxY += 1;
      minY = math.max(0, minY - 1);
    }

    final double yInterval = _niceStep(minY, maxY);
    final double maxX =
        snapshot.wealthTrend.last.date.difference(start).inDays.toDouble();
    final double xInterval = _safeXIntervalDays(start, snapshot.range.end);

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(maxX, 1),
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: xInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final DateTime label =
                      start.add(Duration(days: value.round()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${label.month}/${label.day}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF8B5CF6),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            horizontalInterval: yInterval,
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _AccountDistribution extends StatelessWidget {
  const _AccountDistribution({
    required this.breakdown,
    required this.accounts,
    required this.baseCurrency,
  });

  final Map<String, double> breakdown;
  final Map<String, Account> accounts;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const _EmptyPlaceholder(message: '暂无账户分布数据');
    }

    final ThemeData theme = Theme.of(context);
    final List<BarChartGroupData> groups = <BarChartGroupData>[];
    int index = 0;
    double maxY = 0;
    breakdown.forEach((String key, double value) {
      maxY = math.max(maxY, value.abs());
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: value,
              width: 12,
              color: value >= 0 ? theme.colorScheme.primary : Colors.pinkAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      index++;
    });

    final double yInterval = _niceStep(-maxY, maxY);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: yInterval,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int idx = value.toInt();
                  if (idx < 0 || idx >= breakdown.length) {
                    return const SizedBox.shrink();
                  }
                  final String accountId =
                      breakdown.keys.elementAt(idx);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      accounts[accountId]?.name ?? accountId,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PiePlaceholder extends StatelessWidget {
  const _PiePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          '$title暂无数据',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

double _niceStep(double minV, double maxV,
    {int targetTicks = 4, double minStep = 1}) {
  final double range = (maxV - minV).abs();
  if (range == 0 || range.isNaN || range.isInfinite) {
    return minStep;
  }
  final double raw = range / targetTicks;
  if (raw <= 0) {
    return minStep;
  }
  final int exp = (math.log(raw) / math.log(10)).floor();
  final double base = math.pow(10.0, exp).toDouble();
  final List<double> candidates = <double>[1, 2, 2.5, 5, 10]
      .map((double m) => m * base)
      .toList()
    ..sort((double a, double b) => (a - raw).abs().compareTo((b - raw).abs()));
  final double best = candidates.first;
  return best > 0 ? best : minStep;
}

double _safeXIntervalDays(DateTime start, DateTime end) {
  final int days = end.difference(start).inDays.abs();
  final int step = days ~/ 4;
  return step <= 0 ? 1.0 : step.toDouble();
}
