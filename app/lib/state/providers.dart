import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/rate_provider.dart';
import '../domain/services/ledger_service.dart';
import '../domain/services/recurring_service.dart';
import '../domain/services/report_service.dart';

final databaseProvider = Provider<LedgerDatabase>(
  (ref) => LedgerDatabase.instance,
);

final rateProvider = Provider<RateProvider>(
  (ref) => RateProvider(database: ref.watch(databaseProvider)),
);

final ledgerServiceProvider = Provider<LedgerService>(
  (ref) => LedgerService(
    database: ref.watch(databaseProvider),
    rateProvider: ref.watch(rateProvider),
  ),
);

final recurringServiceProvider = Provider<RecurringService>(
  (ref) => RecurringService(
    database: ref.watch(databaseProvider),
  ),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    database: ref.watch(databaseProvider),
  ),
);

final transactionListProvider = StreamProvider<List<LedgerTransaction>>((ref) {
  return ref.watch(databaseProvider).watchTransactions();
});

final accountStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(databaseProvider).watchAccounts();
});

final accountListProvider = Provider<List<Account>>((ref) {
  return ref.watch(accountStreamProvider).maybeWhen(
        data: (List<Account> value) => value,
        orElse: () => ref.watch(databaseProvider).accounts,
      );
});

final currencyStreamProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(databaseProvider).watchCurrencies();
});

final selectedBaseCurrencyProvider = StateProvider<String>((ref) => 'CNY');

final localeProvider = StateProvider<Locale>(
  (ref) => const Locale('zh'),
);

final appTitleProvider = Provider<String>((ref) {
  final Locale locale = ref.watch(localeProvider);
  return locale.languageCode == 'en' ? 'Tang Ledger' : '小唐账本';
});

final monthlySummaryProvider = Provider<MonthlySummary>((ref) {
  final String baseCurrency = ref.watch(selectedBaseCurrencyProvider);
  final LedgerDatabase database = ref.watch(databaseProvider);
  final DateTime now = DateTime.now();

  final double income = database
      .computeMonthlyTotal(
        year: now.year,
        month: now.month,
        type: TransactionType.income,
        baseCurrency: baseCurrency,
      )
      .value;

  final double expense = database
      .computeMonthlyTotal(
        year: now.year,
        month: now.month,
        type: TransactionType.expense,
        baseCurrency: baseCurrency,
      )
      .value;

  return MonthlySummary(
    income: income,
    expense: expense,
    currency: baseCurrency,
  );
});

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final LedgerDatabase db = ref.watch(databaseProvider);
  return <String, Category>{
    for (final Category category in db.categories) category.code: category,
  };
});

final currencyOptionsProvider = Provider<List<String>>((ref) {
  final Set<String> codes = ref.watch(currencyStreamProvider).maybeWhen(
        data: (Set<String> value) => value,
        orElse: () => ref.watch(databaseProvider).currencies,
      );
  final List<String> list = codes
      .map((String code) => code.toUpperCase())
      .toSet()
      .toList()
    ..sort();
  return list;
});

final recurringRulesProvider = Provider<List<RecurringRule>>((ref) {
  return ref.watch(databaseProvider).recurringRules;
});

final detailsFilterProvider = StateProvider<DetailsFilter>((ref) {
  return DetailsFilter.initial();
});

final detailsListProvider = FutureProvider.autoDispose<List<LedgerTransaction>>(
  (ref) async {
    final DetailsFilter filter = ref.watch(detailsFilterProvider);
    final LedgerService service = ref.watch(ledgerServiceProvider);
    return service.listTransactions(
      range: filter.range,
      category: filter.categoryCode,
      sort: filter.sort,
    );
  },
);

final ratesBaseProvider = StateProvider<String>((ref) {
  final List<String> options = ref.watch(currencyOptionsProvider);
  if (options.contains('AUD')) {
    return 'AUD';
  }
  if (options.contains('CNY')) {
    return 'CNY';
  }
  return ref.watch(selectedBaseCurrencyProvider);
});

final ratesTargetProvider = StateProvider<String>((ref) => 'CNY');

final ratesRangeProvider = StateProvider<int>((ref) => 7); // days

final ratesDateRangeProvider = Provider<DateRange>((ref) {
  final int days = ref.watch(ratesRangeProvider);
  final DateTime now = DateTime.now();
  return DateRange(
    start:
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days)),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
});

final ratesLatestProvider = FutureProvider.autoDispose<Map<String, double>>(
  (ref) async {
    final String base = ref.watch(ratesBaseProvider);
    final String target = ref.watch(ratesTargetProvider);
    final RateProvider svc = ref.watch(rateProvider);
    final List<String> all = List<String>.from(ref.watch(currencyOptionsProvider));
    all.removeWhere((String code) => code.toUpperCase() == base.toUpperCase());
    if (!all.contains(target)) {
      all.add(target);
    }
    final List<String> symbols = all.isEmpty
        ? <String>[target.toUpperCase()]
        : all;
    return svc.fetchLatestRates(base, symbols);
  },
);

final totalAssetsProvider = FutureProvider<double>((ref) async {
  final LedgerService service = ref.watch(ledgerServiceProvider);
  final String base = ref.watch(selectedBaseCurrencyProvider);
  return service.computeTotalAssets(base);
});

final ratesSeriesProvider = FutureProvider.autoDispose<List<RateSeriesPoint>>(
  (ref) async {
    final String base = ref.watch(ratesBaseProvider);
    final String target = ref.watch(ratesTargetProvider);
    final DateRange range = ref.watch(ratesDateRangeProvider);
    final RateProvider svc = ref.watch(rateProvider);
    return svc.fetchTimeseries(base, target, range.start, range.end);
  },
);

final analyticsRangePresetProvider = StateProvider<AnalyticsRangePreset>(
  (ref) => AnalyticsRangePreset.thisMonth,
);

final analyticsCustomRangeProvider = StateProvider<DateRange>(
  (ref) => _currentMonthRange(),
);

final analyticsRangeProvider = Provider<DateRange>((ref) {
  final AnalyticsRangePreset preset = ref.watch(analyticsRangePresetProvider);
  final DateRange custom = ref.watch(analyticsCustomRangeProvider);
  return _resolveAnalyticsRange(preset, custom);
});

final analyticsSnapshotProvider =
    FutureProvider.autoDispose<AnalyticsSnapshot>((ref) async {
  final KeepAliveLink link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 1), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });
  ref.onDispose(() {
    timer?.cancel();
    link.close();
  });

  final DateRange range = ref.watch(analyticsRangeProvider);
  final String baseCurrency = ref.watch(selectedBaseCurrencyProvider);
  final LedgerService ledger = ref.watch(ledgerServiceProvider);
  final RateProvider rates = ref.watch(rateProvider);
  final Map<String, Category> categoryMap = ref.watch(categoryMapProvider);

  final List<LedgerTransaction> transactions =
      await ledger.listTransactions(range: range);
  transactions.sort(
    (LedgerTransaction a, LedgerTransaction b) => a.date.compareTo(b.date),
  );

  final Map<DateTime, _DailyBucket> buckets = <DateTime, _DailyBucket>{};
  final Map<String, double> incomeByCategory = <String, double>{};
  final Map<String, double> expenseByCategory = <String, double>{};

  for (final LedgerTransaction transaction in transactions) {
    if (!transaction.isIncome && !transaction.isExpense) {
      continue;
    }
    final DateTime day = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final _DailyBucket bucket =
        buckets.putIfAbsent(day, () => _DailyBucket());
    final double amount = await _amountInCurrency(
      transaction: transaction,
      targetCurrency: baseCurrency,
      rates: rates,
    );

    if (transaction.isIncome) {
      bucket.income += amount;
      incomeByCategory.update(
        transaction.categoryCode,
        (double value) => value + amount,
        ifAbsent: () => amount,
      );
    } else {
      bucket.expense += amount;
      expenseByCategory.update(
        transaction.categoryCode,
        (double value) => value + amount,
        ifAbsent: () => amount,
      );
    }
  }

  final List<DateTime> days = _enumerateDays(range);
  final List<DailyFlowPoint> flowPoints = <DailyFlowPoint>[];
  double cumulativeNet = 0;
  final List<double> netTimeline = <double>[];

  for (final DateTime day in days) {
    final _DailyBucket bucket = buckets[day] ?? _DailyBucket();
    final double income = double.parse(bucket.income.toStringAsFixed(2));
    final double expense = double.parse(bucket.expense.toStringAsFixed(2));
    cumulativeNet += income - expense;
    flowPoints.add(
      DailyFlowPoint(date: day, income: income, expense: expense),
    );
    netTimeline.add(double.parse(cumulativeNet.toStringAsFixed(2)));
  }

  final double currentTotal = await ledger.computeTotalAssets(baseCurrency);
  final double startTotal = double.parse(
    (currentTotal - (netTimeline.isNotEmpty ? netTimeline.last : 0))
        .toStringAsFixed(2),
  );

  final List<WealthPoint> wealthTrend = <WealthPoint>[];
  double runningTotal = startTotal;
  for (int i = 0; i < days.length; i++) {
    final DailyFlowPoint flow = flowPoints[i];
    runningTotal += flow.income - flow.expense;
    wealthTrend.add(
      WealthPoint(
        date: days[i],
        total: double.parse(runningTotal.toStringAsFixed(2)),
      ),
    );
  }

  final List<ChartSegment> incomeSegments = incomeByCategory.entries
      .map(
        (MapEntry<String, double> entry) => ChartSegment(
          label: categoryMap[entry.key]?.name ?? entry.key,
          value: double.parse(entry.value.toStringAsFixed(2)),
        ),
      )
      .toList()
    ..sort((ChartSegment a, ChartSegment b) => b.value.compareTo(a.value));

  final List<ChartSegment> expenseSegments = expenseByCategory.entries
      .map(
        (MapEntry<String, double> entry) => ChartSegment(
          label: categoryMap[entry.key]?.name ?? entry.key,
          value: double.parse(entry.value.toStringAsFixed(2)),
        ),
      )
      .toList()
    ..sort((ChartSegment a, ChartSegment b) => b.value.compareTo(a.value));

  return AnalyticsSnapshot(
    range: range,
    dailyFlows: flowPoints,
    wealthTrend: wealthTrend,
    incomeSegments: incomeSegments,
    expenseSegments: expenseSegments,
    currency: baseCurrency,
  );
});

class MonthlySummary {
  MonthlySummary({
    required this.income,
    required this.expense,
    required this.currency,
  });

  final double income;
  final double expense;
  final String currency;
}

class _DailyBucket {
  double income = 0;
  double expense = 0;
}

DateRange _resolveAnalyticsRange(
  AnalyticsRangePreset preset,
  DateRange custom,
) {
  final DateTime now = DateTime.now();
  switch (preset) {
    case AnalyticsRangePreset.thisWeek:
      final DateTime start = now.subtract(Duration(days: now.weekday - 1));
      return DateRange(
        start: DateTime(start.year, start.month, start.day),
        end: _endOfDay(now),
      );
    case AnalyticsRangePreset.thisMonth:
      return _currentMonthRange();
    case AnalyticsRangePreset.thisQuarter:
      final int quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      final DateTime start =
          DateTime(now.year, quarterStartMonth, 1);
      return DateRange(
        start: start,
        end: _endOfDay(now),
      );
    case AnalyticsRangePreset.custom:
      return custom;
  }
}

DateRange _currentMonthRange() {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month, 1);
  return DateRange(
    start: start,
    end: _endOfDay(now),
  );
}

List<DateTime> _enumerateDays(DateRange range) {
  final List<DateTime> days = <DateTime>[];
  DateTime cursor = DateTime(range.start.year, range.start.month, range.start.day);
  final DateTime end = DateTime(range.end.year, range.end.month, range.end.day);
  while (!cursor.isAfter(end)) {
    days.add(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  if (days.isEmpty) {
    days.add(DateTime(range.start.year, range.start.month, range.start.day));
  }
  return days;
}

Future<double> _amountInCurrency({
  required LedgerTransaction transaction,
  required String targetCurrency,
  required RateProvider rates,
}) async {
  final String normalizedTarget = targetCurrency.toUpperCase();
  if (transaction.baseCurrency.toUpperCase() == normalizedTarget) {
    return transaction.baseAmount.value;
  }
  if (transaction.originalAmount.currency.toUpperCase() == normalizedTarget) {
    return transaction.originalAmount.value;
  }
  try {
    return await rates.convert(
      date: transaction.date,
      amount: transaction.originalAmount.value,
      from: transaction.originalAmount.currency,
      to: normalizedTarget,
    );
  } on RateNotFoundException {
    return transaction.baseAmount.value;
  }
}

DateTime _endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59);
}
