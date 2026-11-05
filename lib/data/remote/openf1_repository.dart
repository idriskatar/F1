import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/session_models.dart';
import '../local/local_store.dart';

class OpenF1Repository {
  OpenF1Repository({http.Client? client, LocalStore? store})
      : _client = client ?? http.Client(),
        _store = store ?? LocalStore();

  static const _cacheKey = 'openf1-latest-completed-session';
  static const _historicalDelay = Duration(minutes: 30);
  static const _freshFor = Duration(minutes: 15);

  final http.Client _client;
  final LocalStore _store;
  CompletedSessionData? _last;
  DateTime? _fetchedAt;

  Future<CompletedSessionData?> fetchLatest({bool force = false, DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc();
    final cachedMemory = _last;
    final fetchedAt = _fetchedAt;
    if (!force && cachedMemory != null && fetchedAt != null && current.difference(fetchedAt) < _freshFor) {
      return cachedMemory;
    }

    try {
      final result = await _fetchLatest(current);
      if (result != null) {
        _last = result;
        _fetchedAt = current;
        try {
          await _store.saveJson(_cacheKey, jsonEncode(result.toJson()));
        } catch (_) {
          // A local cache failure should not discard a valid API response.
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
      throw const OpenF1Exception('OpenF1 seans verisine bağlanılamadı.');
    }
  }

  Future<CompletedSessionData?> _fetchLatest(DateTime now) async {
    final cutoff = now.subtract(_historicalDelay);
    for (var year = now.year; year >= 2023; year--) {
      final sessions = await _getList('/sessions', {'year': '$year'});
      final completed = sessions
          .where((session) => session['is_cancelled'] != true)
          .map(_SessionMeta.tryParse)
          .whereType<_SessionMeta>()
          .where((session) => session.dateEnd.isBefore(cutoff))
          .toList()
        ..sort((a, b) => b.dateEnd.compareTo(a.dateEnd));

      // A result may not yet be published for a session; fall back to the
      // previous completed session in that case.
      for (final session in completed.take(8)) {
        final List<Map<String, dynamic>> results;
        try {
          results = await _getList('/session_result', {'session_key': '${session.sessionKey}'});
        } on OpenF1Exception catch (error) {
          if (error.message.contains('HTTP 404')) continue;
          rethrow;
        }
        if (results.isEmpty) continue;
        final details = await Future.wait<List<Map<String, dynamic>>>([
          _getListOrEmpty('/drivers', {'session_key': '${session.sessionKey}'}),
          _getListOrEmpty('/meetings', {'meeting_key': '${session.meetingKey}'}),
        ]);
        return _combine(session, results, details[0], details[1].isEmpty ? null : details[1].first);
      }
      if (completed.isNotEmpty) continue;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getList(String path, Map<String, String> parameters) async {
    try {
      final response = await _client
          .get(Uri.https('api.openf1.org', '/v1$path', parameters), headers: const {
            'Accept': 'application/json',
            'User-Agent': 'F1Tracker/0.1',
          })
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw OpenF1Exception('OpenF1 HTTP ${response.statusCode} yanıtı verdi.');
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

  Future<List<Map<String, dynamic>>> _getListOrEmpty(String path, Map<String, String> parameters) async {
    try {
      return await _getList(path, parameters);
    } catch (_) {
      return const [];
    }
  }

  CompletedSessionData _combine(
    _SessionMeta session,
    List<Map<String, dynamic>> results,
    List<Map<String, dynamic>> drivers,
    Map<String, dynamic>? meeting,
  ) {
    final driverByNumber = <int, Map<String, dynamic>>{
      for (final driver in drivers)
        if (_int(driver['driver_number']) > 0) _int(driver['driver_number']): driver,
    };
    final standings = results.map((result) {
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
      );
    }).where((standing) => standing.position > 0).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return CompletedSessionData(
      meetingName: _text((meeting ?? const <String, dynamic>{})['meeting_name'], session.meetingName),
      countryName: session.countryName,
      circuitName: session.circuitName,
      sessionName: session.sessionName,
      dateEnd: session.dateEnd,
      standings: standings,
      updatedAt: DateTime.now().toUtc(),
    );
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

class OpenF1Exception implements Exception {
  const OpenF1Exception(this.message);
  final String message;
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
