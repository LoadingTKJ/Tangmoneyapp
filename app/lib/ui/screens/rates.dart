import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/rate_provider.dart';
import '../../repository/rate_repository.dart';
import '../../services/rate_service.dart';
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

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  void _retryLatest() {
    ref.invalidate(ratesLatestProvider);
    ref.invalidate(ratesSeriesProvider);
  }

  Future<void> _runDiagnostics() async {
    final RateService service = ref.read(rateServiceProvider);
    const List<Map<String, String>> tests = <Map<String, String>>[
      <String, String>{'base': 'AUD', 'target': 'CNY'},
      <String, String>{'base': 'USD', 'target': 'CNY'},
    ];

    for (final Map<String, String> item in tests) {
      final String base = item['base']!;
      final String target = item['target']!;
      try {
        final RateLatest latest =
            await service.getLatest(base: base, target: target);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $base → $target via ${latest.source} = ${latest.rate.toStringAsFixed(4)}',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $base → $target: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String base = ref.watch(ratesBaseProvider);
    final List<String> currencies = ref.watch(currencyOptionsProvider);
    final String target = ref.watch(ratesTargetProvider);
    final int rangeDays = ref.watch(ratesRangeProvider);
    final AsyncValue<RateSnapshot<RateLatest>> latest =
        ref.watch(ratesLatestProvider);
    final AsyncValue<RateSnapshot<RateSeries>> series =
        ref.watch(ratesSeriesProvider);
    final DateRange selectedRange = ref.watch(ratesDateRangeProvider);

    final List<Widget> sections = <Widget>[
      KeyedSubtree(
        key: const ValueKey('rates-header'),
        child: Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '汇率',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (kDebugMode)
              IconButton(
                key: const ValueKey('rates-debug-button'),
                icon: const Icon(Icons.network_check, color: Colors.white),
                tooltip: '测试汇率接口',
                onPressed: _runDiagnostics,
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: const ValueKey('rates-base-selector'),
        child: _BaseSelector(base: base, currencies: currencies),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: const ValueKey('rates-target-selector'),
        child: _TargetSelector(target: target, currencies: currencies),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: const ValueKey('rates-range-selector'),
        child: _RangeSelector(selected: rangeDays),
      ),
      const SizedBox(height: 24),
      KeyedSubtree(
        key: const ValueKey('rates-latest-card'),
        child: _LatestRatesCard(
          latest: latest,
          base: base,
          target: target,
          onRetry: _retryLatest,
        ),
      ),
      const SizedBox(height: 24),
      const KeyedSubtree(
        key: ValueKey('rates-calculator'),
        child: _RateCalculatorCard(),
      ),
      const SizedBox(height: 24),
      KeyedSubtree(
        key: const ValueKey('rates-chart'),
        child: _RateChart(
          series: series,
          base: base,
          target: target,
          rangeDays: rangeDays,
          range: selectedRange,
          onRetry: _retryLatest,
        ),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6C63FF), Color(0xFFA084E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('rates-scroll'),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => sections[index],
                  childCount: sections.length,
                ),
              ),
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
  const _LatestRatesCard({
    required this.latest,
    required this.base,
    required this.target,
    required this.onRetry,
  });

  final AsyncValue<RateSnapshot<RateLatest>> latest;
  final String base;
  final String target;
  final VoidCallback onRetry;

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
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: latest.when(
        data: (RateSnapshot<RateLatest> snapshot) {
          if (snapshot.status == RateSnapshotStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.status == RateSnapshotStatus.error) {
            return _ErrorContent(
                message: snapshot.message ?? '未知错误', onRetry: onRetry);
          }

          final RateLatest data = snapshot.data!;
          final Map<String, double> rates = <String, double>{
            data.target: data.rate,
          };
          final DateTime fetchedAt = data.fetchedAt.toLocal();
          final List<MapEntry<String, double>> entries = rates.entries.toList()
            ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
                a.key.compareTo(b.key));

          final List<Widget> messages = <Widget>[];
          if (snapshot.fromCache) {
            messages.add(
              const Text(
                '离线模式，展示上次更新数据',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            );
          }
          if (snapshot.message != null) {
            messages.add(
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '获取汇率失败（使用缓存）。错误：${snapshot.message}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('实时汇率（1 $base）',
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              ...messages,
              const SizedBox(height: 12),
              DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: const <DataColumn>[
                  DataColumn(label: Text('货币')),
                  DataColumn(label: Text('汇率')),
                ],
                rows: entries
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
              Text('来源：${data.source}',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('上次更新：${DateFormat('yyyy-MM-dd HH:mm').format(fetchedAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorContent(
          message: '获取汇率失败：$error',
          onRetry: onRetry,
        ),
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
  String? _lastBase;
  String? _lastTarget;

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
    if (!mounted) {
      return;
    }
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
    final AsyncValue<RateSnapshot<RateLatest>> latestSnapshot =
        ref.watch(ratesLatestProvider);
    final RateSnapshot<RateLatest>? latestData = latestSnapshot.asData?.value;
    DateTime? lastUpdated;
    bool lastFromCache = false;
    String? lastSource;
    if (latestData != null && latestData.hasData) {
      lastUpdated = latestData.data!.fetchedAt;
      lastFromCache = latestData.fromCache;
      lastSource = latestData.data!.source;
    }

    if (_lastBase != base || _lastTarget != target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastBase = base;
        _lastTarget = target;
        _syncFromBase();
      });
    }

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
            '基准：$base → $target  ·  上次更新：${lastUpdated != null ? DateFormat('yyyy-MM-dd HH:mm').format(lastUpdated.toLocal()) : '--'}${lastFromCache ? '（缓存）' : ''}${lastSource != null ? ' · 来源：$lastSource' : ''}',
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
    required this.onRetry,
  });

  final AsyncValue<RateSnapshot<RateSeries>> series;
  final String base;
  final String target;
  final int rangeDays;
  final DateRange range;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    final DateFormat dayFormat = DateFormat('yyyy-MM-dd');
    final DateFormat tsFormat = DateFormat('yyyy-MM-dd HH:mm');
    final String rangeLabel =
        '区间：${dayFormat.format(range.start)} ~ ${dayFormat.format(range.end)}';

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
        data: (RateSnapshot<RateSeries> snapshot) {
          final bool waiting = snapshot.status == RateSnapshotStatus.loading &&
              !snapshot.hasData;
          final bool hasData = snapshot.hasData;
          final RateSeries? data = snapshot.data;
          final DateTime? fetchedAt = hasData ? data!.fetchedAt : null;
          final String updatedLabel = fetchedAt != null
              ? '上次更新：${tsFormat.format(fetchedAt.toLocal())}${snapshot.fromCache ? '（缓存）' : ''}'
              : '上次更新：--';
          final String sourceLabel = hasData ? '来源：${data!.source}' : '';

          final List<Widget> meta = <Widget>[
            Text(rangeLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              sourceLabel.isEmpty
                  ? updatedLabel
                  : '$updatedLabel · $sourceLabel',
              style: theme.textTheme.bodySmall,
            ),
          ];

          if (snapshot.fromCache && hasData) {
            meta.insert(
              0,
              const Text(
                '离线模式，展示上次更新数据',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            );
            meta.insert(1, const SizedBox(height: 4));
          }

          if (snapshot.message != null && snapshot.message!.trim().isNotEmpty) {
            meta.add(const SizedBox(height: 4));
            meta.add(
              Text(
                '获取新数据失败（使用缓存）。错误：${snapshot.message}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            );
          }

          Widget body;
          if (waiting) {
            body = const Center(child: CircularProgressIndicator());
          } else if (!hasData) {
            body = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const _ChartErrorPlaceholder(),
                const SizedBox(height: 8),
                Text(
                  snapshot.message ?? '无法获取历史汇率，请稍后重试',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('重试'),
                ),
              ],
            );
          } else {
            final List<RatePoint> sorted = List<RatePoint>.from(data!.points)
              ..sort(
                (RatePoint a, RatePoint b) => a.date.compareTo(b.date),
              );
            if (sorted.length <= 1) {
              body = const _EmptyChartPlaceholder();
            } else {
              final DateTime startDate = DateTime(
                range.start.year,
                range.start.month,
                range.start.day,
              );
              final DateTime endDate = DateTime(
                range.end.year,
                range.end.month,
                range.end.day,
              );
              final List<FlSpot> spots = sorted
                  .map(
                    (RatePoint point) => FlSpot(
                      point.date.difference(startDate).inDays.toDouble(),
                      point.rate,
                    ),
                  )
                  .toList();

              double minY = sorted
                  .map((RatePoint p) => p.rate)
                  .reduce((double a, double b) => math.min(a, b));
              double maxY = sorted
                  .map((RatePoint p) => p.rate)
                  .reduce((double a, double b) => math.max(a, b));
              if ((maxY - minY).abs() < 1e-6) {
                minY -= 0.0001;
                maxY += 0.0001;
              }
              final double spread = (maxY - minY).abs();
              final double padding = spread == 0 ? 0.0005 : spread * 0.05;
              final double minChartY = minY - padding;
              final double maxChartY = maxY + padding;

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

              body = LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minChartY,
                  maxY: maxChartY,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: yInterval,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toStringAsFixed(4),
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
                          final DateTime label = startDate.add(
                            Duration(days: value.round()),
                          );
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
              );
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '历史汇率（$base → $target，近 $rangeDays 天）',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              ...meta,
              const SizedBox(height: 12),
              Expanded(child: body),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const _ChartErrorPlaceholder(),
            const SizedBox(height: 8),
            Text(
              '错误：$error',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
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

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ],
    );
  }
}
