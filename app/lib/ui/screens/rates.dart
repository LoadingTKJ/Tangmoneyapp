import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/rate_provider.dart';
import '../../state/providers.dart';

double _niceStep(double minV, double maxV,
    {int targetTicks = 4, double minStep = 0.0001}) {
  final double range = (maxV - minV).abs();
  if (range == 0 || range.isNaN || range.isInfinite) return minStep;
  final double raw = range / targetTicks;
  if (raw <= 0) return minStep;
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

double _safeYInterval(double minV, double maxV) {
  return _niceStep(minV, maxV, targetTicks: 4, minStep: 0.0001);
}

class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String base = ref.watch(ratesBaseProvider);
    final List<String> currencies = ref.watch(currencyOptionsProvider);
    final String target = ref.watch(ratesTargetProvider);
    final int rangeDays = ref.watch(ratesRangeProvider);
    final AsyncValue<Map<String, double>> latest =
        ref.watch(ratesLatestProvider);
    final AsyncValue<List<RateSeriesPoint>> series =
        ref.watch(ratesSeriesProvider);
    final RateProvider rateSvc = ref.watch(rateProvider);
    final List<String> symbolSet = <String>[];
    for (final String code in currencies) {
      final String upper = code.toUpperCase();
      if (upper == base.toUpperCase()) {
        continue;
      }
      if (!symbolSet.contains(upper)) {
        symbolSet.add(upper);
      }
    }
    if (!symbolSet.contains(target.toUpperCase())) {
      symbolSet.add(target.toUpperCase());
    }
    if (symbolSet.isEmpty) {
      symbolSet.add(target.toUpperCase());
    }
    final DateTime? updatedAt = rateSvc.lastUpdated(base, symbolSet);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6C63FF), Color(0xFFA084E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            _BaseSelector(base: base, currencies: currencies),
            const SizedBox(height: 16),
            _TargetSelector(target: target, currencies: currencies),
            const SizedBox(height: 16),
            _RangeSelector(selected: rangeDays),
            const SizedBox(height: 24),
            _LatestRatesCard(
                latest: latest,
                updatedAt: updatedAt,
                base: base,
                symbols: symbolSet),
            const SizedBox(height: 24),
            const _RateCalculatorCard(),
            const SizedBox(height: 24),
            _RateChart(
              series: series,
              base: base,
              target: target,
              rangeDays: rangeDays,
              range: ref.watch(ratesDateRangeProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseSelector extends ConsumerWidget {
  const _BaseSelector({required this.base, required this.currencies});

  final String base;
  final List<String> currencies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.read(ledgerServiceProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          const Icon(Icons.currency_exchange, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: base,
                items: currencies
                    .map(
                      (String code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) async {
                  if (value != null && value != base) {
                    ref.read(ratesBaseProvider.notifier).state = value;
                    ref.read(selectedBaseCurrencyProvider.notifier).state =
                        value;
                    await ledger.rebaseTransactions(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '基准币',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TargetSelector extends ConsumerWidget {
  const _TargetSelector({required this.target, required this.currencies});

  final String target;
  final List<String> currencies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String base = ref.watch(ratesBaseProvider);
    final List<String> options = currencies
        .where((String code) => code.toUpperCase() != base.toUpperCase())
        .toList();
    String currentTarget = target;
    if (!options.contains(currentTarget) && options.isNotEmpty) {
      currentTarget = options.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ratesTargetProvider.notifier).state = currentTarget;
      });
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          const Icon(Icons.swap_horiz, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(currentTarget) ? currentTarget : null,
                items: options
                    .map(
                      (String code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    ref.read(ratesTargetProvider.notifier).state = value;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '目标货币',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final int days in <int>[7, 30, 90])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ChoiceChip(
              label: Text('$days 天'),
              selected: selected == days,
              onSelected: (bool value) {
                if (value) {
                  ref.read(ratesRangeProvider.notifier).state = days;
                }
              },
            ),
          ),
      ],
    );
  }
}

class _LatestRatesCard extends ConsumerWidget {
  const _LatestRatesCard(
      {required this.latest,
      required this.updatedAt,
      required this.base,
      required this.symbols});

  final AsyncValue<Map<String, double>> latest;
  final DateTime? updatedAt;
  final String base;
  final List<String> symbols;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: latest.when(
        data: (Map<String, double> rates) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('实时汇率（1 $base）',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: const <DataColumn>[
                  DataColumn(label: Text('货币')),
                  DataColumn(label: Text('汇率')),
                ],
                rows: rates.entries
                    .map(
                      (MapEntry<String, double> e) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(e.key)),
                          DataCell(Text(e.value.toStringAsFixed(4))),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text('数据来源：exchangerate.host / frankfurter.dev',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(
                '上次更新：${updatedAt != null ? updatedAt!.toLocal().toString() : '未知'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Text('加载实时汇率失败：$error'),
      ),
    );
  }
}

class _RateCalculatorCard extends ConsumerStatefulWidget {
  const _RateCalculatorCard();

  @override
  ConsumerState<_RateCalculatorCard> createState() =>
      _RateCalculatorCardState();
}

class _RateCalculatorCardState extends ConsumerState<_RateCalculatorCard> {
  final TextEditingController _baseController =
      TextEditingController(text: '1');
  final TextEditingController _targetController = TextEditingController();
  bool _isBusy = false;
  String? _error;
  bool _isUpdatingFields = false;

  @override
  void initState() {
    super.initState();
    ref.listen<String>(
      ratesBaseProvider,
      (_, __) => _syncFromBase(),
    );
    ref.listen<String>(
      ratesTargetProvider,
      (_, __) => _syncFromBase(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromBase());
  }

  @override
  void dispose() {
    _baseController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _syncFromBase() async {
    if (!mounted) {
      return;
    }
    await _convert(forward: true);
  }

  Future<void> _convert({required bool forward}) async {
    final String base = ref.read(ratesBaseProvider);
    final String target = ref.read(ratesTargetProvider);
    final RateProvider svc = ref.read(rateProvider);
    final double amount = double.tryParse(
          forward ? _baseController.text : _targetController.text,
        ) ??
        0;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final double converted = forward
          ? await svc.convert(
              date: DateTime.now(),
              amount: amount,
              from: base,
              to: target,
            )
          : await svc.convert(
              date: DateTime.now(),
              amount: amount,
              from: target,
              to: base,
            );
      _isUpdatingFields = true;
      if (forward) {
        _targetController.text = converted.toStringAsFixed(4);
      } else {
        _baseController.text = converted.toStringAsFixed(4);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isUpdatingFields = false;
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String base = ref.watch(ratesBaseProvider);
    final String target = ref.watch(ratesTargetProvider);
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '汇率计算器',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _baseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: base,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onChanged: (_) {
                    if (_isUpdatingFields) {
                      return;
                    }
                    _convert(forward: true);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: IconButton(
                  onPressed: () {
                    final String originalBase = ref.read(ratesBaseProvider);
                    final String originalTarget = ref.read(ratesTargetProvider);
                    ref.read(ratesBaseProvider.notifier).state = originalTarget;
                    ref.read(ratesTargetProvider.notifier).state = originalBase;
                  },
                  icon: const Icon(Icons.swap_horiz_sharp),
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: target,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onChanged: (_) {
                    if (_isUpdatingFields) {
                      return;
                    }
                    _convert(forward: false);
                  },
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '基准：$base → $target  ·  ${DateTime.now().toLocal()}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RateChart extends StatelessWidget {
  const _RateChart({
    required this.series,
    required this.base,
    required this.target,
    required this.rangeDays,
    required this.range,
  });

  final AsyncValue<List<RateSeriesPoint>> series;
  final String base;
  final String target;
  final int rangeDays;
  final DateRange range;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      height: 320,
      child: series.when(
        data: (List<RateSeriesPoint> rawPoints) {
          final List<RateSeriesPoint> points =
              List<RateSeriesPoint>.from(rawPoints)
                ..sort((RateSeriesPoint a, RateSeriesPoint b) =>
                    a.date.compareTo(b.date));
          if (points.isEmpty || points.length <= 1) {
            return const _EmptyChartPlaceholder();
          }

          final DateTime startDate =
              DateTime(range.start.year, range.start.month, range.start.day);
          final DateTime endDate =
              DateTime(range.end.year, range.end.month, range.end.day);

          final List<FlSpot> spots = points
              .map((RateSeriesPoint point) => FlSpot(
                    point.date.difference(startDate).inDays.toDouble(),
                    point.rate,
                  ))
              .toList();

          double minY = spots
              .map((FlSpot e) => e.y)
              .reduce((double a, double b) => math.min(a, b));
          double maxY = spots
              .map((FlSpot e) => e.y)
              .reduce((double a, double b) => math.max(a, b));
          if ((maxY - minY).abs() < 1e-6) {
            minY -= 0.0001;
            maxY += 0.0001;
          }

          double minX = spots
              .map((FlSpot e) => e.x)
              .reduce((double a, double b) => math.min(a, b));
          double maxX = spots
              .map((FlSpot e) => e.x)
              .reduce((double a, double b) => math.max(a, b));
          if (minX > 0) {
            minX = 0;
          }
          if ((maxX - minX).abs() < 1e-6) {
            maxX = minX + 1;
          }

          final double yInterval = _safeYInterval(minY, maxY);
          final double xInterval = _safeXIntervalDays(startDate, endDate);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '历史汇率（$base → $target，近 $rangeDays 天）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: minY * 0.98,
                    maxY: maxY * 1.02,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: yInterval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(value.toStringAsFixed(4),
                                style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: xInterval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final DateTime label =
                                startDate.add(Duration(days: value.round()));
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
                        color: primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: primary.withValues(alpha: 0.15),
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            const _ChartErrorPlaceholder(),
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Opacity(
        opacity: 0.7,
        child: Text('暂无可绘制的汇率数据', style: TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _ChartErrorPlaceholder extends StatelessWidget {
  const _ChartErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Opacity(
        opacity: 0.7,
        child: Text('获取汇率失败，请稍后重试', style: TextStyle(fontSize: 13)),
      ),
    );
  }
}
