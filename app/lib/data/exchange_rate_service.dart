import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ExchangeRateUnavailableException implements Exception {
  ExchangeRateUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ExchangeRateData {
  ExchangeRateData({
    required this.rates,
    required this.source,
    required this.fetchedAt,
  });

  final Map<String, double> rates;
  final String source;
  final DateTime fetchedAt;
}

class ExchangeRateService {
  ExchangeRateService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  String? _lastSuccessfulBaseUrl;
  bool _sourceLoaded = false;

  static const List<String> _defaultApis = <String>[
    'https://open.er-api.com/v6/latest',
    'https://api.frankfurter.app/latest',
  ];

  static const String _prefsKey = 'exchange_rate_last_source';

  Future<ExchangeRateData> fetchLatestRates({
    required String base,
    required List<String> symbols,
  }) async {
    final List<String> targets = await _orderedApis();
    Map<String, double>? rates;
    String? source;

    for (final String api in targets) {
      try {
        final Uri uri = _buildLatestUri(api, base, symbols);
        if (kDebugMode) {
          debugPrint('[ExchangeRateService] GET $uri');
        }
        final http.Response response =
            await _client.get(uri).timeout(const Duration(seconds: 5));
        if (kDebugMode) {
          debugPrint(
            '[ExchangeRateService] <- ${response.statusCode} from $api',
          );
        }
        if (response.statusCode != 200) {
          continue;
        }
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        rates = _extractLatest(data, api, symbols);
        if (rates == null || rates.isEmpty) {
          if (kDebugMode) {
            debugPrint('[ExchangeRateService] no rates in response from $api');
          }
          continue;
        }
        source = api;
        await _saveLastSource(api);
        break;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[ExchangeRateService] $api failed: $error');
        }
        continue;
      }
    }

    if (rates == null || source == null) {
      throw ExchangeRateUnavailableException('无法获取 $base 的实时汇率');
    }

    return ExchangeRateData(
      rates: rates,
      source: source,
      fetchedAt: DateTime.now(),
    );
  }

  Future<Map<DateTime, double>> fetchTimeSeries({
    required String base,
    required String symbol,
    required DateRange range,
  }) async {
    final String start = _formatDate(range.start);
    final String end = _formatDate(range.end);
    final Uri uri = Uri.parse(
      'https://api.frankfurter.app/$start..$end?from=$base&to=$symbol',
    );

    if (kDebugMode) {
      debugPrint('[ExchangeRateService] GET $uri');
    }

    try {
      final http.Response response =
          await _client.get(uri).timeout(const Duration(seconds: 5));
      if (kDebugMode) {
        debugPrint(
          '[ExchangeRateService] <- ${response.statusCode} from frankfurter.app',
        );
      }
      if (response.statusCode != 200) {
        throw ExchangeRateUnavailableException(
            '历史汇率接口返回 ${response.statusCode}');
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      if (rates == null) {
        throw ExchangeRateUnavailableException('历史汇率数据为空');
      }
      final Map<DateTime, double> parsed = <DateTime, double>{};
      rates.forEach((String day, dynamic value) {
        if (value is Map<String, dynamic>) {
          final dynamic raw = value[symbol] ?? value[symbol.toUpperCase()];
          if (raw is num) {
            parsed[DateTime.parse(day)] = raw.toDouble();
          }
        }
      });
      if (parsed.isEmpty) {
        throw ExchangeRateUnavailableException('历史汇率解析失败');
      }
      return parsed;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[ExchangeRateService] frankfurter timeseries failed: $error');
      }
      rethrow;
    }
  }

  Future<ExchangeRateData> fetchSingleRate({
    required String base,
    required String quote,
  }) {
    return fetchLatestRates(base: base, symbols: <String>[quote]);
  }

  String? get lastSource => _lastSuccessfulBaseUrl;

  Future<List<String>> _orderedApis() async {
    await _ensureLastSourceLoaded();
    final List<String> targets = <String>[..._defaultApis];
    if (_lastSuccessfulBaseUrl != null &&
        targets.remove(_lastSuccessfulBaseUrl)) {
      targets.insert(0, _lastSuccessfulBaseUrl!);
    }
    return targets;
  }

  Future<void> _ensureLastSourceLoaded() async {
    if (_sourceLoaded) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _lastSuccessfulBaseUrl = prefs.getString(_prefsKey);
    _sourceLoaded = true;
  }

  Future<void> _saveLastSource(String api) async {
    _lastSuccessfulBaseUrl = api;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, api);
  }

  Uri _buildLatestUri(String api, String base, List<String> symbols) {
    final String upperBase = base.toUpperCase();
    final String joined = symbols.map((String e) => e.toUpperCase()).join(',');
    if (api.contains('open.er-api.com')) {
      return Uri.parse('$api/$upperBase');
    }
    if (api.contains('frankfurter.app')) {
      return Uri.parse('$api?from=$upperBase&to=$joined');
    }
    throw ExchangeRateUnavailableException('Unsupported API: $api');
  }

  Map<String, double>? _extractLatest(
    Map<String, dynamic> data,
    String api,
    List<String> symbols,
  ) {
    final Map<String, double> result = <String, double>{};
    for (final String symbol in symbols) {
      final String key = symbol.toUpperCase();
      final double? rate = _extractRate(data, api, key);
      if (rate != null) {
        result[key] = rate;
      }
    }
    return result.isEmpty ? null : result;
  }

  double? _extractRate(
    Map<String, dynamic> data,
    String api,
    String quote,
  ) {
    if (api.contains('open.er-api.com')) {
      if (data['result'] == 'success') {
        final Map<String, dynamic>? rates =
            data['rates'] as Map<String, dynamic>?;
        final dynamic value = rates?[quote];
        if (value is num) {
          return value.toDouble();
        }
      }
      return null;
    }
    if (api.contains('frankfurter.app')) {
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      final dynamic value = rates?[quote];
      if (value is num) {
        return value.toDouble();
      }
      return null;
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _client.close();
  }
}
