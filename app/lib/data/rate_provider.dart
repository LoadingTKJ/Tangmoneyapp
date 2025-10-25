import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'db.dart';
import 'models.dart';

class RateProvider {
  RateProvider({required this.database, this.pivotCurrency = 'CNY'}) {
    final DateTime today = DateTime.now();
    seedRate(today, 'AUD', 'CNY', 4.77);
    seedRate(today, 'USD', 'CNY', 7.15);
    seedRate(today, 'HKD', 'CNY', 0.92);
  }

  final LedgerDatabase database;
  final String pivotCurrency;

  final Map<String, _CachedLatest> _latestCache = <String, _CachedLatest>{};

  Future<double> getRate({
    required DateTime date,
    required String from,
    required String to,
    bool allowPivot = true,
  }) async {
    final String normalizedFrom = from.toUpperCase();
    final String normalizedTo = to.toUpperCase();

    if (normalizedFrom == normalizedTo) {
      return 1;
    }

    final DateTime day = DateTime(date.year, date.month, date.day);
    final String key = _cacheKey(day, normalizedFrom, normalizedTo);

    final RateQuote? stored = database.findLatestRate(
      normalizedFrom,
      normalizedTo,
      date: day,
    );
    if (stored != null) {
      return stored.rate;
    }

    final _CachedLatest? cached = _latestCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.rates[normalizedTo]!;
    }

    try {
      await fetchLatestRates(normalizedFrom, <String>[normalizedTo]);
    } catch (_) {
      // ignore and attempt pivot fallback
    }

    final RateQuote? refreshed = database.findLatestRate(
      normalizedFrom,
      normalizedTo,
      date: day,
    );
    if (refreshed != null) {
      return refreshed.rate;
    }

    if (allowPivot) {
      final String pivot = pivotCurrency.toUpperCase();
      if (normalizedFrom != pivot && normalizedTo != pivot) {
        try {
          final double fromToPivot = await getRate(
            date: date,
            from: normalizedFrom,
            to: pivot,
            allowPivot: false,
          );
          final double pivotToTarget = await getRate(
            date: date,
            from: pivot,
            to: normalizedTo,
            allowPivot: false,
          );
          final double combined =
              double.parse((fromToPivot * pivotToTarget).toStringAsFixed(6));
          database.upsertRateQuote(
            RateQuote(
              date: day,
              fromCurrency: normalizedFrom,
              toCurrency: normalizedTo,
              rate: combined,
              provider: 'pivot-cache',
              fetchedAt: DateTime.now(),
            ),
          );
          return combined;
        } on RateNotFoundException {
          // fall through
        }
      }
    }

    throw RateNotFoundException(
      '缺少 $normalizedFrom → $normalizedTo 的汇率，请手动录入。',
    );
  }

  Future<void> setManualRate({
    required DateTime date,
    required String from,
    required String to,
    required double rate,
  }) async {
    final DateTime day = DateTime(date.year, date.month, date.day);
    database.upsertRateQuote(
      RateQuote(
        date: day,
        fromCurrency: from.toUpperCase(),
        toCurrency: to.toUpperCase(),
        rate: double.parse(rate.toStringAsFixed(6)),
        provider: 'manual',
        fetchedAt: DateTime.now(),
      ),
    );
  }

  void seedRate(DateTime date, String from, String to, double rate) {
    database.upsertRateQuote(
      RateQuote(
        date: DateTime(date.year, date.month, date.day),
        fromCurrency: from.toUpperCase(),
        toCurrency: to.toUpperCase(),
        rate: double.parse(rate.toStringAsFixed(6)),
        provider: 'seed',
        fetchedAt: DateTime.now(),
      ),
    );
  }

  Future<double> convert({
    required DateTime date,
    required double amount,
    required String from,
    required String to,
  }) async {
    final double rate = await getRate(
      date: date,
      from: from,
      to: to,
    );
    return double.parse((amount * rate).toStringAsFixed(2));
  }

  Future<Map<String, double>> fetchLatestRates(
    String base,
    List<String> symbols,
  ) async {
    final String cacheKey =
        '${base.toUpperCase()}-${symbols.map((e) => e.toUpperCase()).join(',')}';
    final _CachedLatest? cached = _latestCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.rates;
    }

    final Map<String, double>? primary = await _requestLatest(
      uri: Uri.https('api.exchangerate.host', '/latest', <String, String>{
        'base': base,
        'symbols': symbols.map((String e) => e.toUpperCase()).join(','),
      }),
      provider: 'exchangerate.host',
    );

    final Map<String, double> rates = primary ??
        (await _requestLatest(
          uri: Uri.https('api.frankfurter.dev', '/latest', <String, String>{
            'from': base,
            'to': symbols.map((String e) => e.toUpperCase()).join(','),
          }),
          provider: 'frankfurter',
        )) ??
        <String, double>{};

    if (rates.isEmpty) {
      throw RateNotFoundException('无法获取 $base 的最新汇率');
    }

    final DateTime now = DateTime.now();
    for (final MapEntry<String, double> entry in rates.entries) {
      database.upsertRateQuote(
        RateQuote(
          date: DateTime(now.year, now.month, now.day),
          fromCurrency: base.toUpperCase(),
          toCurrency: entry.key.toUpperCase(),
          rate: entry.value,
          provider: 'remote',
          fetchedAt: now,
        ),
      );
    }

    _latestCache[cacheKey] = _CachedLatest(
      rates: rates,
      fetchedAt: now,
    );

    return rates;
  }

  DateTime? lastUpdated(String base, List<String> symbols) {
    final String cacheKey =
        '${base.toUpperCase()}-${symbols.map((String e) => e.toUpperCase()).join(',')}';
    return _latestCache[cacheKey]?.fetchedAt;
  }

  Future<List<RateSeriesPoint>> fetchTimeseries(
    String base,
    String symbol,
    DateTime start,
    DateTime end,
  ) async {
    final DateRange range = DateRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
    );
    final List<RateSeriesPoint> cached = database.findSeries(
      from: base.toUpperCase(),
      to: symbol.toUpperCase(),
      range: range,
    );
    if (cached.isNotEmpty &&
        cached.length >= range.end.difference(range.start).inDays ~/ 2) {
      return cached;
    }

    final Map<DateTime, double>? primary = await _requestSeries(
      uri: Uri.https('api.exchangerate.host', '/timeseries', <String, String>{
        'base': base,
        'symbols': symbol,
        'start_date': _formatDate(range.start),
        'end_date': _formatDate(range.end),
      }),
      provider: 'exchangerate.host',
      symbol: symbol,
    );

    final Map<DateTime, double> data = primary ??
        (await _requestSeries(
          uri: Uri.parse(
              'https://api.frankfurter.dev/${_formatDate(range.start)}..${_formatDate(range.end)}'),
          provider: 'frankfurter',
          symbol: symbol,
          base: base,
        )) ??
        <DateTime, double>{};

    if (data.isEmpty) {
      return cached;
    }

    data.forEach((DateTime date, double rate) {
      database.upsertRateQuote(
        RateQuote(
          date: DateTime(date.year, date.month, date.day),
          fromCurrency: base.toUpperCase(),
          toCurrency: symbol.toUpperCase(),
          rate: rate,
          provider: 'remote',
          fetchedAt: DateTime.now(),
        ),
      );
    });

    return data.entries
        .map((MapEntry<DateTime, double> entry) => RateSeriesPoint(
              date: entry.key,
              rate: entry.value,
            ))
        .toList()
      ..sort(
          (RateSeriesPoint a, RateSeriesPoint b) => a.date.compareTo(b.date));
  }

  Future<Map<String, double>?> _requestLatest({
    required Uri uri,
    required String provider,
  }) async {
    try {
      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic>? rates =
            (data['rates'] ?? data['Rates']) as Map<String, dynamic>?;
        if (rates == null) {
          return null;
        }
        return rates.map((String key, dynamic value) =>
            MapEntry(key.toUpperCase(), (value as num).toDouble()));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<DateTime, double>?> _requestSeries({
    required Uri uri,
    required String provider,
    required String symbol,
    String? base,
  }) async {
    try {
      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      if (rates == null) {
        return null;
      }
      final Map<DateTime, double> parsed = <DateTime, double>{};
      rates.forEach((String day, dynamic value) {
        final Map<String, dynamic> entry = value as Map<String, dynamic>;
        final num raw = (entry[symbol] ??
            entry[symbol.toUpperCase()] ??
            entry.values.first) as num;
        final double rate = raw.toDouble();
        parsed[DateTime.parse(day)] = rate;
      });
      return parsed;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _cacheKey(DateTime day, String from, String to) {
    return '${day.toIso8601String()}-$from-$to';
  }
}

class RateNotFoundException implements Exception {
  RateNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _CachedLatest {
  _CachedLatest({required this.rates, required this.fetchedAt});

  final Map<String, double> rates;
  final DateTime fetchedAt;

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 30);
}
