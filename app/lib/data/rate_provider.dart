import 'dart:async';

import '../repository/rate_repository.dart';
import '../services/rate_service.dart';
import 'db.dart';
import 'models.dart';

class RateProvider {
  RateProvider({
    required this.database,
    required this.repository,
    this.defaultBaseCurrency = 'CNY',
  });

  final LedgerDatabase database;
  final RateRepository repository;
  final String defaultBaseCurrency;

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

    final RateQuote? stored = database.findLatestRate(
      normalizedFrom,
      normalizedTo,
      date: DateTime(date.year, date.month, date.day),
    );
    if (stored != null) {
      return stored.rate;
    }

    try {
      final RateLatest latest = await repository.getLatestForConversion(
        normalizedFrom,
        normalizedTo,
      );
      _storeQuote(latest, date);
      return latest.rate;
    } catch (_) {
      if (!allowPivot) {
        rethrow;
      }
    }

    if (allowPivot) {
      final String pivot = defaultBaseCurrency.toUpperCase();
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
              date: DateTime(date.year, date.month, date.day),
              fromCurrency: normalizedFrom,
              toCurrency: normalizedTo,
              rate: combined,
              provider: 'pivot-cache',
              fetchedAt: DateTime.now(),
            ),
          );
          return combined;
        } catch (_) {
          // fall through to error below
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

  Future<List<RateSeriesPoint>> fetchTimeseries(
    String base,
    String symbol,
    DateTime start,
    DateTime end,
  ) async {
    final RateSeries series = await repository.getSeriesForConversion(
      base,
      symbol,
      start,
      end,
    );
    return series.points
        .map(
          (RatePoint point) => RateSeriesPoint(
            date: point.date,
            rate: point.rate,
          ),
        )
        .toList();
  }

  void _storeQuote(RateLatest latest, DateTime requestedDate) {
    final DateTime day = DateTime(
      requestedDate.year,
      requestedDate.month,
      requestedDate.day,
    );
    database.upsertRateQuote(
      RateQuote(
        date: day,
        fromCurrency: latest.base,
        toCurrency: latest.target,
        rate: latest.rate,
        provider: latest.source,
        fetchedAt: latest.fetchedAt,
      ),
    );
  }
}

class RateNotFoundException implements Exception {
  RateNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}
