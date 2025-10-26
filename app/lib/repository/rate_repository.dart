import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../services/rate_service.dart';

enum RateSnapshotStatus { loading, data, error }

class RateSnapshot<T> {
  const RateSnapshot._({
    required this.status,
    this.data,
    this.fromCache = false,
    this.message,
  });

  final RateSnapshotStatus status;
  final T? data;
  final bool fromCache;
  final String? message;

  const RateSnapshot.loading() : this._(status: RateSnapshotStatus.loading);

  const RateSnapshot.data({
    required T data,
    bool fromCache = false,
    String? message,
  }) : this._(
          status: RateSnapshotStatus.data,
          data: data,
          fromCache: fromCache,
          message: message,
        );

  const RateSnapshot.error(String message)
      : this._(
          status: RateSnapshotStatus.error,
          message: message,
        );

  bool get isLoading => status == RateSnapshotStatus.loading;
  bool get hasError => status == RateSnapshotStatus.error;
  bool get hasData => status == RateSnapshotStatus.data && data != null;
}

class RateRepository {
  RateRepository({
    required RateService service,
    required Box<String> latestBox,
    required Box<String> seriesBox,
  })  : _service = service,
        _latestBox = latestBox,
        _seriesBox = seriesBox;

  final RateService _service;
  final Box<String> _latestBox;
  final Box<String> _seriesBox;

  static String _latestKey(String base, String target) =>
      'latest:${base.toUpperCase()}-${target.toUpperCase()}';

  static String _seriesKey(
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) =>
      'series:${base.toUpperCase()}-${target.toUpperCase()}:${start.toIso8601String()}-${end.toIso8601String()}';

  Future<RateLatest?> _readLatest(String base, String target) async {
    final String? raw = _latestBox.get(_latestKey(base, target));
    if (raw == null) {
      return null;
    }
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return RateLatest.fromJson(json);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[RateRepository] latest cache decode error: $error');
      }
      return null;
    }
  }

  Future<void> _writeLatest(RateLatest latest) async {
    await _latestBox.put(
      _latestKey(latest.base, latest.target),
      jsonEncode(latest.toJson()),
    );
  }

  Future<RateSeries?> _readSeries(
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) async {
    final String? raw = _seriesBox.get(_seriesKey(base, target, start, end));
    if (raw == null) {
      return null;
    }
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return RateSeries.fromJson(json);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[RateRepository] series cache decode error: $error');
      }
      return null;
    }
  }

  Future<void> _writeSeries(
      RateSeries series, DateTime start, DateTime end) async {
    await _seriesBox.put(
      _seriesKey(series.base, series.target, start, end),
      jsonEncode(series.toJson()),
    );
  }

  Stream<RateSnapshot<RateLatest>> watchLatest(
    String base,
    String target,
  ) async* {
    final RateLatest? cached = await _readLatest(base, target);
    if (cached != null) {
      yield RateSnapshot<RateLatest>.data(
        data: cached,
        fromCache: true,
      );
    } else {
      yield const RateSnapshot<RateLatest>.loading();
    }
    try {
      final RateLatest latest =
          await _service.getLatest(base: base, target: target);
      await _writeLatest(latest);
      yield RateSnapshot<RateLatest>.data(data: latest, fromCache: false);
    } catch (error) {
      final String message = _shortMessage(error);
      if (cached != null) {
        yield RateSnapshot<RateLatest>.data(
          data: cached,
          fromCache: true,
          message: message,
        );
      } else {
        yield RateSnapshot<RateLatest>.error(message);
      }
    }
  }

  Stream<RateSnapshot<RateSeries>> watchSeries(
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) async* {
    final RateSeries? cached = await _readSeries(base, target, start, end);
    if (cached != null) {
      yield RateSnapshot<RateSeries>.data(
        data: cached,
        fromCache: true,
      );
    } else {
      yield const RateSnapshot<RateSeries>.loading();
    }
    try {
      final RateSeries series = await _service.getSeries(
        base: base,
        target: target,
        start: start,
        end: end,
      );
      await _writeSeries(series, start, end);
      yield RateSnapshot<RateSeries>.data(data: series, fromCache: false);
    } catch (error) {
      final String message = _shortMessage(error);
      if (cached != null) {
        yield RateSnapshot<RateSeries>.data(
          data: cached,
          fromCache: true,
          message: message,
        );
      } else {
        yield RateSnapshot<RateSeries>.error(message);
      }
    }
  }

  Future<RateLatest> getLatestForConversion(
    String base,
    String target,
  ) async {
    try {
      final RateLatest latest =
          await _service.getLatest(base: base, target: target);
      await _writeLatest(latest);
      return latest;
    } catch (error) {
      final RateLatest? cached = await _readLatest(base, target);
      if (cached != null) {
        return cached;
      }
      throw RateServiceException(_shortMessage(error));
    }
  }

  Future<RateSeries> getSeriesForConversion(
    String base,
    String target,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final RateSeries series = await _service.getSeries(
        base: base,
        target: target,
        start: start,
        end: end,
      );
      await _writeSeries(series, start, end);
      return series;
    } catch (error) {
      final RateSeries? cached = await _readSeries(base, target, start, end);
      if (cached != null) {
        return cached;
      }
      throw RateServiceException(_shortMessage(error));
    }
  }

  String _shortMessage(Object error) {
    if (error is RateServiceException) {
      return error.message;
    }
    return error.toString();
  }
}
