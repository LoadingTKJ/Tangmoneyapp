import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatePoint {
  RatePoint({required this.date, required this.rate});

  final DateTime date;
  final double rate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toUtc().toIso8601String(),
        'rate': rate,
      };

  factory RatePoint.fromJson(Map<String, dynamic> json) {
    return RatePoint(
      date: DateTime.parse(json['date'] as String).toLocal(),
      rate: (json['rate'] as num).toDouble(),
    );
  }
}

class RateLatest {
  RateLatest({
    required this.base,
    required this.target,
    required this.rate,
    required this.fetchedAt,
    required this.source,
  });

  final String base;
  final String target;
  final double rate;
  final DateTime fetchedAt;
  final String source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'base': base,
        'target': target,
        'rate': rate,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'source': source,
      };

  factory RateLatest.fromJson(Map<String, dynamic> json) {
    return RateLatest(
      base: json['base'] as String,
      target: json['target'] as String,
      rate: (json['rate'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String).toLocal(),
      source: json['source'] as String,
    );
  }
}

class RateSeries {
  RateSeries({
    required this.base,
    required this.target,
    required this.points,
    required this.fetchedAt,
    required this.source,
  });

  final String base;
  final String target;
  final List<RatePoint> points;
  final DateTime fetchedAt;
  final String source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'base': base,
        'target': target,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'source': source,
        'points': points.map((RatePoint point) => point.toJson()).toList(),
      };

  factory RateSeries.fromJson(Map<String, dynamic> json) {
    return RateSeries(
      base: json['base'] as String,
      target: json['target'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String).toLocal(),
      source: json['source'] as String,
      points: (json['points'] as List<dynamic>)
          .map((dynamic e) => RatePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract class RateService {
  Future<RateLatest> getLatest({
    required String base,
    required String target,
  });

  Future<RateSeries> getSeries({
    required String base,
    required String target,
    required DateTime start,
    required DateTime end,
  });
}

class RateServiceException implements Exception {
  RateServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LiveRateService implements RateService {
  LiveRateService({required Dio dio, List<String>? fallbacks})
      : _dio = dio,
        _fallbacks = fallbacks ?? const <String>[];

  final Dio _dio;
  final List<String> _fallbacks;
  String? _lastSource;
  bool _loadedPrefs = false;

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://open.er-api.com/v6');
  static const String _prefsKey = 'rate_service_last_source';

  Future<void> _ensurePrefsLoaded() async {
    if (_loadedPrefs) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _lastSource = prefs.getString(_prefsKey);
    _loadedPrefs = true;
  }

  Future<void> _saveLastSource(String source) async {
    _lastSource = source;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, source);
  }

  List<String> _buildEndpoints() {
    final List<String> ordered = <String>[
      _normalize(_envBaseUrl),
      'https://open.er-api.com/v6',
      'https://api.frankfurter.app',
      ..._fallbacks.map(_normalize),
    ].where((String url) => url.isNotEmpty).toList();

    final LinkedHashSet<String> dedup = LinkedHashSet<String>.from(ordered);
    final List<String> list = dedup.toList();

    if (_lastSource != null && list.remove(_lastSource)) {
      list.insert(0, _lastSource!);
    }
    return list;
  }

  @override
  Future<RateLatest> getLatest({
    required String base,
    required String target,
  }) async {
    await _ensurePrefsLoaded();
    final List<String> endpoints = _buildEndpoints();
    RateServiceException? lastError;
    for (final String endpoint in endpoints) {
      try {
        final RateLatest latest = await _fetchLatest(endpoint, base, target);
        await _saveLastSource(endpoint);
        return latest;
      } catch (error, stack) {
        lastError = RateServiceException(error.toString());
        if (kDebugMode) {
          debugPrint('[RateService] latest failed ($endpoint): $error\n$stack');
        }
        continue;
      }
    }
    throw lastError ?? RateServiceException('无法获取 $base → $target 的汇率');
  }

  @override
  Future<RateSeries> getSeries({
    required String base,
    required String target,
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensurePrefsLoaded();
    final List<String> endpoints = _buildEndpoints();
    RateServiceException? lastError;
    for (final String endpoint in endpoints) {
      try {
        final RateSeries series =
            await _fetchSeries(endpoint, base, target, start, end);
        await _saveLastSource(endpoint);
        return series;
      } catch (error, stack) {
        lastError = RateServiceException(error.toString());
        if (kDebugMode) {
          debugPrint('[RateService] series failed ($endpoint): $error\n$stack');
        }
        continue;
      }
    }
    throw lastError ?? RateServiceException('无法获取 $base → $target 的历史汇率');
  }

  Future<RateLatest> _fetchLatest(
    String endpoint,
    String base,
    String target,
  ) async {
    final Uri uri = _buildLatestUri(endpoint, base, target);
    if (kDebugMode) {
      debugPrint('[RateService] GET $uri');
    }
    final Response<dynamic> response =
        await _dio.getUri(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.data == null) {
      throw RateServiceException('HTTP ${response.statusCode}');
    }
    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data as String) as Map<String, dynamic>;
    final double? rate = _extractRate(data, endpoint, target.toUpperCase());
    if (rate == null) {
      throw RateServiceException('响应缺少汇率');
    }
    return RateLatest(
      base: base.toUpperCase(),
      target: target.toUpperCase(),
      rate: rate,
      fetchedAt: _extractFetchedAt(data, endpoint),
      source: _normalize(endpoint),
    );
  }

  Future<RateSeries> _fetchSeries(
    String endpoint,
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) async {
    final Uri uri = _buildSeriesUri(endpoint, base, target, start, end);
    if (kDebugMode) {
      debugPrint('[RateService] GET $uri');
    }
    final Response<dynamic> response =
        await _dio.getUri(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.data == null) {
      throw RateServiceException('HTTP ${response.statusCode}');
    }
    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data as String) as Map<String, dynamic>;
    final Map<DateTime, double>? parsed =
        _extractSeries(data, endpoint, target.toUpperCase());
    if (parsed == null || parsed.isEmpty) {
      throw RateServiceException('历史汇率数据为空');
    }
    final List<RatePoint> points = parsed.entries
        .map((MapEntry<DateTime, double> e) =>
            RatePoint(date: e.key, rate: e.value))
        .toList()
      ..sort((RatePoint a, RatePoint b) => a.date.compareTo(b.date));
    return RateSeries(
      base: base.toUpperCase(),
      target: target.toUpperCase(),
      points: points,
      fetchedAt: DateTime.now(),
      source: _normalize(endpoint),
    );
  }

  Uri _buildLatestUri(String endpoint, String base, String target) {
    final Uri baseUri = Uri.parse(endpoint);
    final String host = baseUri.host;
    final String prefix = baseUri.path.isEmpty ? '' : baseUri.path;
    if (host.contains('frankfurter')) {
      return Uri.https(
        host,
        _join(prefix, 'latest'),
        <String, String>{
          'from': base.toUpperCase(),
          'to': target.toUpperCase(),
        },
      );
    }
    if (host.contains('open.er-api.com')) {
      String path = prefix;
      if (!path.toLowerCase().endsWith('latest')) {
        path = _join(path, 'latest');
      }
      path = _join(path, base.toUpperCase());
      return Uri.https(host, path);
    }
    if (host.contains('exchangerate.host')) {
      return Uri.https(
        host,
        _join(prefix, 'latest'),
        <String, String>{
          'base': base.toUpperCase(),
          'symbols': target.toUpperCase(),
        },
      );
    }
    throw RateServiceException('Unsupported API: $endpoint');
  }

  Uri _buildSeriesUri(
    String endpoint,
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) {
    final Uri baseUri = Uri.parse(endpoint);
    final String host = baseUri.host;
    final String prefix = baseUri.path.isEmpty ? '' : baseUri.path;
    final String startStr = _formatDate(start);
    final String endStr = _formatDate(end);
    if (host.contains('frankfurter')) {
      return Uri.https(
        host,
        _join(prefix, '$startStr..$endStr'),
        <String, String>{
          'from': base.toUpperCase(),
          'to': target.toUpperCase(),
        },
      );
    }
    if (host.contains('open.er-api.com')) {
      throw RateServiceException('API($endpoint) 不支持历史汇率查询');
    }
    if (host.contains('exchangerate.host')) {
      return Uri.https(
        host,
        _join(prefix, 'timeseries'),
        <String, String>{
          'base': base.toUpperCase(),
          'symbols': target.toUpperCase(),
          'start_date': startStr,
          'end_date': endStr,
        },
      );
    }
    throw RateServiceException('Unsupported API: $endpoint');
  }

  double? _extractRate(
    Map<String, dynamic> data,
    String endpoint,
    String target,
  ) {
    final String host = Uri.parse(endpoint).host;
    if (host.contains('frankfurter')) {
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      final dynamic raw = rates?[target];
      if (raw is num) {
        return raw.toDouble();
      }
      return null;
    }
    if (host.contains('open.er-api.com')) {
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      final dynamic raw = rates?[target] ?? rates?[target.toUpperCase()];
      if (raw is num) {
        return raw.toDouble();
      }
      return null;
    }
    if (host.contains('exchangerate.host')) {
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      final dynamic raw = rates?[target];
      if (raw is num) {
        return raw.toDouble();
      }
      return null;
    }
    return null;
  }

  Map<DateTime, double>? _extractSeries(
    Map<String, dynamic> data,
    String endpoint,
    String target,
  ) {
    final String host = Uri.parse(endpoint).host;
    final Map<DateTime, double> parsed = <DateTime, double>{};
    if (host.contains('frankfurter') || host.contains('exchangerate.host')) {
      final Map<String, dynamic>? rates =
          data['rates'] as Map<String, dynamic>?;
      if (rates == null) {
        return null;
      }
      rates.forEach((String day, dynamic value) {
        if (value is Map<String, dynamic>) {
          final dynamic raw = value[target] ?? value[target.toUpperCase()];
          if (raw is num) {
            parsed[DateTime.parse(day).toLocal()] = raw.toDouble();
          }
        }
      });
      return parsed;
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _extractFetchedAt(Map<String, dynamic> data, String endpoint) {
    final String host = Uri.parse(endpoint).host;
    if (host.contains('open.er-api.com')) {
      final String? raw = data['time_last_update_utc'] as String?;
      if (raw != null) {
        final DateTime? iso = DateTime.tryParse(raw);
        if (iso != null) {
          return iso.toLocal();
        }
        try {
          final DateFormat fmt = DateFormat('E, dd MMM yyyy HH:mm:ss', 'en_US');
          final String sanitized =
              raw.replaceAll(RegExp(r'\s+[A-Z]{3}$'), '').replaceAll(
                    RegExp(r'\s+[+-]\d{4}$'),
                    '',
                  );
          return fmt.parseUtc(sanitized).toLocal();
        } catch (_) {
          // ignore parse error, fallback below
        }
      }
    }
    if (host.contains('frankfurter')) {
      final String? rawDate = data['date'] as String?;
      if (rawDate != null) {
        try {
          return DateTime.parse('${rawDate}T00:00:00Z').toLocal();
        } catch (_) {
          // ignore parse error, fallback below
        }
      }
    }
    return DateTime.now();
  }

  String _normalize(String url) {
    final Uri uri = Uri.parse(url);
    if (uri.scheme.isEmpty) {
      return 'https://${uri.path}';
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  String _join(String prefix, String path) {
    final String normalizedPrefix =
        prefix.endsWith('/') ? prefix.substring(0, prefix.length - 1) : prefix;
    final String normalizedPath =
        path.startsWith('/') ? path.substring(1) : path;
    if (normalizedPrefix.isEmpty) {
      return '/$normalizedPath';
    }
    return '$normalizedPrefix/$normalizedPath';
  }
}
