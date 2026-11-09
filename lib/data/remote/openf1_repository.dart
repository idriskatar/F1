import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/models/session_models.dart';
import '../local/local_store.dart';

/// Loads historical race analysis without requesting the live-data service.
/// Only the three classified podium drivers receive high-volume telemetry and
/// GPS requests; all other sections are limited to compact session summaries.
class OpenF1Repository {
  OpenF1Repository({http.Client? client, LocalStore? store})
      : _client = client ?? http.Client(),
        _store = store ?? LocalStore();

  static const _cacheKey = 'openf1-latest-race-analysis-v2';
  static const _historicalDelay = Duration(minutes: 30);
  static const _freshFor = Duration(minutes: 15);
  static const _minimumRequestGap = Duration(milliseconds: 360);

  final http.Client _client;
  final LocalStore _store;
  CompletedSessionData? _last;
  DateTime? _fetchedAt;
  DateTime? _lastRequestAt;

  Future<CompletedSessionData?> fetchLatest({bool force = false, DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc();
    final cachedMemory = _last;
    final fetchedAt = _fetchedAt;
    if (cachedMemory != null && fetchedAt != null) {
      final age = current.difference(fetchedAt);
      if ((!force && age < _freshFor) || (force && age < const Duration(minutes: 1))) return cachedMemory;
    }

    try {
      final result = await _fetchLatest(current);
      if (result != null) {
        _last = result;
        _fetchedAt = current;
        try {
          await _store.saveJson(_cacheKey, jsonEncode(result.toJson()));
        } catch (_) {
          // A local cache failure must not discard a valid API response.
        }
      } else {
        final persisted = await _readCache();
        if (persisted != null) {
          _last = persisted;
          _fetchedAt = current;
          return persisted.withCacheStatus(true);
        }
      }
      return result;
    } catch (error) {
      final persisted = await _readCache();
      if (persisted != null) {
        _last = persisted;
        _fetchedAt = current;
        return persisted.withCacheStatus(true);
      }
      if (error is OpenF1Exception) rethrow;
      throw const OpenF1Exception('OpenF1 yarış verisine bağlanılamadı.');
    }
  }

  Future<CompletedSessionData?> _fetchLatest(DateTime now) async {
    final cutoff = now.subtract(_historicalDelay);
    OpenF1Exception? authorizationError;
    for (var year = now.year; year >= 2023; year--) {
      final List<Map<String, dynamic>> sessions;
      try {
        sessions = await _getList('/sessions', {
          'year': '$year',
          'date_end<=': cutoff.toIso8601String(),
        });
      } on OpenF1Exception catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          authorizationError = error;
          break;
        }
        rethrow;
      }

      final races = sessions
          .where((session) => session['is_cancelled'] != true)
          .map(_SessionMeta.tryParse)
          .whereType<_SessionMeta>()
          .where((session) => session.dateEnd.isBefore(cutoff) && session.sessionName.toLowerCase() == 'race')
          .toList()
        ..sort((a, b) => b.dateEnd.compareTo(a.dateEnd));

      // A result may be published late. Try earlier race sessions before
      // moving to an older season, never substituting practice or qualifying.
      for (final session in races.take(8)) {
        final List<Map<String, dynamic>> results;
        try {
          results = await _getList('/session_result', {'session_key': '${session.sessionKey}'});
        } on OpenF1Exception catch (error) {
          if (error.statusCode == 404) continue;
          if (error.statusCode == 401 || error.statusCode == 403) {
            authorizationError = error;
            break;
          }
          rethrow;
        }
        if (results.isEmpty) continue;
        final drivers = await _getOptional('/drivers', {'session_key': '${session.sessionKey}'}, 'Sürücü bilgileri');
        final meetings = await _getOptional('/meetings', {'meeting_key': '${session.meetingKey}'}, 'Yarış bilgileri');
        final missing = <String>[];
        final driverByNumber = {
          for (final driver in drivers)
            if (_int(driver['driver_number']) > 0) _int(driver['driver_number']): driver,
        };
        final standings = _standings(results, driverByNumber);
        final podium = standings.where((row) => row.position > 0).take(3).toList();

        final rawLaps = await _getOptional('/laps', {'session_key': '${session.sessionKey}'}, 'Tur kayıtları', missing);
        final laps = rawLaps.map(_lapFromApi).toList()
          ..sort((a, b) {
            final numberOrder = a.driverNumber.compareTo(b.driverNumber);
            return numberOrder != 0 ? numberOrder : a.lapNumber.compareTo(b.lapNumber);
          });
        final rawPits = await _getOptional('/pit', {'session_key': '${session.sessionKey}'}, 'Pit kayıtları', missing);
        final rawStints = await _getOptional('/stints', {'session_key': '${session.sessionKey}'}, 'Lastik stintleri', missing);
        final rawWeather = await _getOptional('/weather', {'session_key': '${session.sessionKey}'}, 'Hava durumu', missing);
        final rawGaps = await _getOptional('/intervals', {'session_key': '${session.sessionKey}'}, 'Sürücü aralıkları', missing);
        final telemetry = <DriverTelemetry>[];
        final traces = <TrackTrace>[];
        final gaps = rawGaps.map(GapSample.fromApi).toList()
          ..sort((a, b) => (a.date ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.date ?? DateTime.fromMillisecondsSinceEpoch(0)));

        for (final driver in podium) {
          final driverInfo = driverByNumber[driver.driverNumber] ?? const <String, dynamic>{};
          final color = _teamColor(driverInfo['team_colour'], driver.position);
          final code = _text(driverInfo['name_acronym'], driver.driverCode);

          final rawTelemetry = await _getOptional(
            '/car_data',
            {'session_key': '${session.sessionKey}', 'driver_number': '${driver.driverNumber}'},
            'Üç pilotun araç telemetrisi',
            missing,
          );
          if (rawTelemetry.isNotEmpty) {
            telemetry.add(_telemetryFromApi(rawTelemetry, driver, code, driver.teamName, color));
          }

          // Fetch location samples for podium drivers only. Keep the opening
          // lap for the cached map geometry instead of storing the full trace.
          final firstLap = laps
              .where((lap) => lap.driverNumber == driver.driverNumber && lap.lapNumber == 1 && lap.dateStart != null && lap.durationSeconds != null)
              .firstOrNull;
          if (firstLap != null) {
            final start = firstLap.dateStart!.toUtc();
            final end = start.add(Duration(milliseconds: (firstLap.durationSeconds! * 1000).round() + 3000));
            final rawLocation = await _getOptional(
              '/location',
              {
                'session_key': '${session.sessionKey}',
                'driver_number': '${driver.driverNumber}',
              },
              'Podyum pilotlarının pist konum izi',
              missing,
            );
            final points = rawLocation
                .where((row) {
                  final date = DateTime.tryParse('${row['date'] ?? ''}')?.toUtc();
                  return date != null && !date.isBefore(start) && !date.isAfter(end);
                })
                .map((row) => TrackPoint(x: _double(row['x']) ?? 0, y: _double(row['y']) ?? 0))
                .where((point) => point.x != 0 || point.y != 0)
                .toList();
            if (points.length > 2) {
              traces.add(TrackTrace(driverNumber: driver.driverNumber, driverCode: code, teamColor: color, points: points));
            }
          } else {
            missing.add('Podyum pilotlarının ilk tur GPS izi');
          }

        }

        return CompletedSessionData(
          meetingName: _text((meetings.firstOrNull ?? const {})['meeting_name'], session.meetingName),
          countryName: session.countryName,
          circuitName: session.circuitName,
          sessionName: session.sessionName,
          dateEnd: session.dateEnd,
          standings: standings,
          updatedAt: DateTime.now().toUtc(),
          sessionKey: session.sessionKey,
          meetingKey: session.meetingKey,
          laps: laps,
          telemetry: telemetry,
          trackTraces: traces,
          gaps: gaps,
          pitStops: rawPits.map(PitStop.fromApi).toList(),
          stints: rawStints.map(TyreStint.fromApi).toList(),
          weather: rawWeather.map(_weatherFromApi).toList(),
          unavailableSections: missing.toSet().toList(),
        );
      }
      if (authorizationError != null) break;
    }
    if (authorizationError != null) {
      throw const OpenF1Exception(
        'OpenF1 tarihsel seans isteğini reddetti (401/403). Yalnızca 2023 ve sonrası tamamlanmış yarış verileri sorgulanır.',
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getOptional(
    String path,
    Map<String, String> parameters,
    String section, [
    List<String>? missing,
  ]) async {
    try {
      final result = await _getList(path, parameters);
      if (result.isEmpty && missing != null) missing.add(section);
      return result;
    } catch (_) {
      missing?.add(section);
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path, Map<String, String> parameters) async {
    try {
      final lastRequest = _lastRequestAt;
      if (lastRequest != null) {
        final remaining = _minimumRequestGap - DateTime.now().difference(lastRequest);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      _lastRequestAt = DateTime.now();
      final response = await _client
          .get(Uri.https('api.openf1.org', '/v1$path', parameters), headers: const {
            'Accept': 'application/json',
            'User-Agent': 'F1Tracker/0.2',
          })
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw OpenF1Exception('OpenF1 HTTP ${response.statusCode} yanıtı verdi.', statusCode: response.statusCode);
      }
      final json = jsonDecode(response.body);
      if (json is! List) throw const OpenF1Exception('OpenF1 yanıt biçimi beklenenden farklı.');
      return json.whereType<Map<String, dynamic>>().toList();
    } on http.ClientException catch (error) {
      throw OpenF1Exception('OpenF1 bağlantısı kurulamadı: ${error.message}');
    } on FormatException {
      throw const OpenF1Exception('OpenF1 geçerli JSON döndürmedi.');
    }
  }

  List<SessionStanding> _standings(List<Map<String, dynamic>> results, Map<int, Map<String, dynamic>> driverByNumber) {
    return results.map((result) {
      final number = _int(result['driver_number']);
      final driver = driverByNumber[number] ?? const <String, dynamic>{};
      return SessionStanding(
        position: _int(result['position']),
        driverNumber: number,
        driverName: _text(driver['full_name'], 'Pilot $number'),
        driverCode: _text(driver['name_acronym'], number == 0 ? '—' : '$number'),
        teamName: _text(driver['team_name'], ''),
        gapToLeader: _gap(result['gap_to_leader']),
        laps: _int(result['number_of_laps']),
        resultSeconds: _lastNumber(result['duration']),
        points: _double(result['points']) ?? 0,
        gridPosition: _int(result['grid_position']),
        dnf: result['dnf'] == true,
        dns: result['dns'] == true,
        dsq: result['dsq'] == true,
      );
    }).toList()
      ..sort((a, b) {
        if (a.position > 0 && b.position > 0) return a.position.compareTo(b.position);
        if (a.position > 0) return -1;
        if (b.position > 0) return 1;
        if (a.dns != b.dns) return a.dns ? 1 : -1;
        return a.driverCode.compareTo(b.driverCode);
      });
  }

  LapRecord _lapFromApi(Map<String, dynamic> row) => LapRecord(
        driverNumber: _int(row['driver_number']),
        lapNumber: _int(row['lap_number']),
        dateStart: DateTime.tryParse('${row['date_start'] ?? ''}')?.toUtc(),
        durationSeconds: _double(row['lap_duration']),
        sector1: _double(row['duration_sector_1']),
        sector2: _double(row['duration_sector_2']),
        sector3: _double(row['duration_sector_3']),
        intermediateSpeed1: _double(row['i1_speed']),
        intermediateSpeed2: _double(row['i2_speed']),
        speedTrap: _double(row['st_speed']),
        pitOut: row['is_pit_out_lap'] == true,
      );

  DriverTelemetry _telemetryFromApi(
    List<Map<String, dynamic>> rows,
    SessionStanding driver,
    String code,
    String team,
    int color,
  ) {
    final movingRows = rows.where((row) => (_double(row['speed']) ?? 0) > 0).toList();
    final speeds = movingRows.map((row) => _double(row['speed'])!).toList();
    final rpms = rows.map((row) => _double(row['rpm'])).whereType<double>().toList();
    final throttles = rows.map((row) => _double(row['throttle'])).whereType<double>().toList();
    final braking = rows.where((row) => (_double(row['brake']) ?? 0) > 0).length;
    final drs = rows.where((row) => (_int(row['drs'])) >= 8).length;
    final sample = _sample(speeds, 180);
    return DriverTelemetry(
      driverNumber: driver.driverNumber,
      driverCode: code,
      teamName: team,
      teamColor: color,
      sampleCount: rows.length,
      maxSpeed: speeds.isEmpty ? null : speeds.reduce((a, b) => a > b ? a : b),
      averageSpeed: speeds.isEmpty ? null : speeds.reduce((a, b) => a + b) / speeds.length,
      maxRpm: rpms.isEmpty ? null : rpms.reduce((a, b) => a > b ? a : b).round(),
      averageThrottle: throttles.isEmpty ? null : throttles.reduce((a, b) => a + b) / throttles.length,
      brakingPercent: rows.isEmpty ? null : braking * 100 / rows.length,
      drsPercent: rows.isEmpty ? null : drs * 100 / rows.length,
      speedSamples: sample,
    );
  }

  WeatherSample _weatherFromApi(Map<String, dynamic> row) => WeatherSample(
        date: DateTime.tryParse('${row['date'] ?? ''}')?.toUtc(),
        airTemperature: _double(row['air_temperature']),
        trackTemperature: _double(row['track_temperature']),
        humidity: _double(row['humidity']),
        pressure: _double(row['pressure']),
        rainfall: row['rainfall'] == null ? null : row['rainfall'] == true || (_double(row['rainfall']) ?? 0) > 0,
        windDirection: row['wind_direction'] == null ? null : _int(row['wind_direction']),
        windSpeed: _double(row['wind_speed']),
      );

  List<double> _sample(List<double> values, int targetCount) {
    if (values.length <= targetCount) return values;
    return [for (var i = 0; i < targetCount; i++) values[(i * (values.length - 1) / (targetCount - 1)).round()]];
  }

  int _teamColor(Object? value, int position) {
    final text = value?.toString().replaceAll('#', '').trim() ?? '';
    final parsed = int.tryParse(text, radix: 16);
    if (parsed != null) return 0xFF000000 | parsed;
    return switch (position) {
      1 => 0xFFE10600,
      2 => 0xFF3671C6,
      _ => 0xFF00D2BE,
    };
  }

  Future<CompletedSessionData?> _readCache() async {
    try {
      final raw = await _store.readJson(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return CompletedSessionData.fromJson(json, isCached: true);
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class OpenF1Exception implements Exception {
  const OpenF1Exception(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class _SessionMeta {
  const _SessionMeta({
    required this.sessionKey,
    required this.meetingKey,
    required this.sessionName,
    required this.meetingName,
    required this.countryName,
    required this.circuitName,
    required this.dateEnd,
  });

  final int sessionKey;
  final int meetingKey;
  final String sessionName;
  final String meetingName;
  final String countryName;
  final String circuitName;
  final DateTime dateEnd;

  static _SessionMeta? tryParse(Map<String, dynamic> json) {
    final key = _int(json['session_key']);
    final meetingKey = _int(json['meeting_key']);
    final dateEnd = DateTime.tryParse('${json['date_end'] ?? ''}')?.toUtc();
    if (key <= 0 || meetingKey <= 0 || dateEnd == null) return null;
    return _SessionMeta(
      sessionKey: key,
      meetingKey: meetingKey,
      sessionName: _text(json['session_name'], 'Seans'),
      meetingName: _text(json['meeting_name'], ''),
      countryName: _text(json['country_name'], ''),
      circuitName: _text(json['circuit_short_name'], _text(json['location'], '')),
      dateEnd: dateEnd,
    );
  }
}

String _text(Object? value, String fallback) => value == null || value.toString().isEmpty ? fallback : value.toString();
int _int(Object? value) => int.tryParse('$value') ?? 0;
double? _double(Object? value) => value is num ? value.toDouble() : double.tryParse('$value');

double? _lastNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is List) {
    for (final item in value.reversed) {
      if (item == null) continue;
      final number = double.tryParse('$item');
      if (number != null) return number;
    }
  }
  return double.tryParse('$value');
}

String _gap(Object? value) {
  final number = _lastNumber(value);
  if (number != null) return number == 0 ? 'Lider' : '+${number.toStringAsFixed(3)} sn';
  if (value is List) {
    for (final item in value.reversed) {
      if (item != null) return item.toString();
    }
    return '—';
  }
  return _text(value, '—');
}
