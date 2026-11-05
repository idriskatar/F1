import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/race_models.dart';
import '../local/local_store.dart';

class JolpicaData<T> {
  const JolpicaData({required this.items, required this.isCached, required this.updatedAt, this.label});
  final List<T> items;
  final bool isCached;
  final DateTime updatedAt;

  /// Verinin başlığı (örn. son yarışın adı); yoksa null.
  final String? label;
}

class NextRaceData {
  const NextRaceData({required this.race, required this.isCached, required this.updatedAt});

  /// Sıradaki yarış; sezon bittiyse ve yeni takvim yoksa null.
  final RaceWeekend? race;
  final bool isCached;
  final DateTime updatedAt;
}

class JolpicaRepository {
  JolpicaRepository({http.Client? client, LocalStore? store})
      : _client = client ?? http.Client(), _store = store ?? LocalStore();

  static const _baseUrl = 'https://api.jolpi.ca/ergast/f1';
  final http.Client _client;
  final LocalStore _store;

  Future<JolpicaData<RaceWeekend>> calendar({int? season}) async {
    final year = season ?? DateTime.now().year;
    final payload = await _load('calendar-$year', '$year.json?limit=100');
    final races = _raceTable(payload.json)['Races'];
    return JolpicaData(
      items: _list(races).map((item) => RaceWeekend.fromJson(_asMap(item))).toList(),
      isCached: payload.isCached,
      updatedAt: payload.updatedAt,
    );
  }

  /// Takvimden sıradaki yarışı bulur. Mevcut sezonda yarış kalmadıysa bir
  /// sonraki sezonun takvimini dener; o da yoksa `race` null döner.
  Future<NextRaceData> nextRace({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc();
    final thisYear = await calendar(season: current.year);
    var race = upcomingRace(thisYear.items, current);
    var source = thisYear;
    if (race == null) {
      try {
        final nextYear = await calendar(season: current.year + 1);
        race = upcomingRace(nextYear.items, current);
        if (race != null) source = nextYear;
      } catch (_) {
        // Gelecek sezon takvimi henüz yayımlanmamış olabilir.
      }
    }
    return NextRaceData(race: race, isCached: source.isCached, updatedAt: source.updatedAt);
  }

  Future<JolpicaData<DriverResult>> latestResults() async {
    final payload = await _load('latest-results', 'current/last/results.json?limit=100');
    final races = _list(_raceTable(payload.json)['Races']);
    final results = races.isEmpty ? const [] : _list(_asMap(races.first)['Results']);
    final raceName = races.isEmpty ? null : _asMap(races.first)['raceName']?.toString();
    return JolpicaData(
      items: results.map((item) => DriverResult.fromJson(_asMap(item))).toList(),
      isCached: payload.isCached,
      updatedAt: payload.updatedAt,
      label: raceName,
    );
  }

  Future<JolpicaData<DriverStanding>> driverStandings({int? season}) async {
    final year = season ?? DateTime.now().year;
    final payload = await _load('driver-standings-$year', '$year/driverStandings.json?limit=100');
    final list = _standingList(payload.json, 'DriverStandings');
    return JolpicaData(items: list.map(DriverStanding.fromJson).toList(), isCached: payload.isCached, updatedAt: payload.updatedAt);
  }

  Future<JolpicaData<TeamStanding>> teamStandings({int? season}) async {
    final year = season ?? DateTime.now().year;
    final payload = await _load('team-standings-$year', '$year/constructorStandings.json?limit=100');
    final list = _standingList(payload.json, 'ConstructorStandings');
    return JolpicaData(items: list.map(TeamStanding.fromJson).toList(), isCached: payload.isCached, updatedAt: payload.updatedAt);
  }

  Future<_Payload> _load(String key, String path) async {
    Object? networkError;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/$path'), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw JolpicaException('Jolpica sunucusu HTTP ${response.statusCode} yanıtı verdi.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['MRData'] is! Map<String, dynamic>) {
        throw const JolpicaException('Jolpica yanıt biçimi beklenenden farklı.');
      }
      final now = DateTime.now().toUtc();
      try {
        await _store.saveJson(key, jsonEncode({'savedAt': now.toIso8601String(), 'data': decoded}));
      } catch (_) {
        // A local database issue must not discard a valid live API response.
      }
      return _Payload(decoded, false, now);
    } catch (error) {
      networkError = error;
    }

    try {
      final cached = await _store.readJson(key);
      if (cached != null) {
        final entry = jsonDecode(cached) as Map<String, dynamic>;
        final data = entry['data'];
        if (data is Map<String, dynamic>) {
          return _Payload(data, true, DateTime.tryParse('${entry['savedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0));
        }
      }
    } catch (_) {
      // Corrupt cache is ignored; the original network error is reported below.
    }
    if (networkError is JolpicaException) throw networkError;
    if (networkError is http.ClientException) {
      throw JolpicaException('Jolpica verisine bağlanılamadı: ${networkError.message}');
    }
    throw const JolpicaException('Jolpica verisi alınamadı. İnternet bağlantısını kontrol edip yeniden deneyin.');
  }

  void close() => _client.close();
}

class JolpicaException implements Exception {
  const JolpicaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Payload {
  const _Payload(this.json, this.isCached, this.updatedAt);
  final Map<String, dynamic> json;
  final bool isCached;
  final DateTime updatedAt;
}

Map<String, dynamic> _raceTable(Map<String, dynamic> response) =>
    _asMap(_asMap(response['MRData'])['RaceTable']);

List<Map<String, dynamic>> _standingList(Map<String, dynamic> response, String field) {
  final table = _asMap(_asMap(response['MRData'])['StandingsTable']);
  final lists = _list(table['StandingsLists']);
  if (lists.isEmpty) return const [];
  return _list(_asMap(lists.first)[field]).map(_asMap).toList();
}

Map<String, dynamic> _asMap(Object? value) => value is Map<String, dynamic> ? value : const {};
List<Object?> _list(Object? value) => value is List ? value.cast<Object?>() : const [];
