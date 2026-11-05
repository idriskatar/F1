import 'dart:convert';

import 'package:f1_tracker/data/local/local_store.dart';
import 'package:f1_tracker/data/remote/jolpica_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testlerde kullanılan SABİT "şimdi": 5 Kasım 2026 12:00 UTC.
final testNow = DateTime.utc(2026, 11, 5, 12);

/// SQLite yerine bellekte çalışan önbellek.
class MemoryStore extends LocalStore {
  final Map<String, String> entries = {};

  @override
  Future<void> saveJson(String key, String payload) async => entries[key] = payload;

  @override
  Future<String?> readJson(String key) async => entries[key];
}

Map<String, dynamic> envelope(Map<String, dynamic> body) => {
      'MRData': {'series': 'f1', ...body},
    };

/// Tamamen UYDURMA takvim kaydı; gerçek bir yarış verisi değildir.
Map<String, dynamic> raceJson({
  required int round,
  required String name,
  required String date,
  String time = '14:00:00Z',
  Map<String, String> sessions = const {},
}) =>
    {
      'season': date.substring(0, 4),
      'round': '$round',
      'raceName': name,
      'Circuit': {
        'circuitName': 'Test Circuit',
        'Location': {'locality': 'Testville', 'country': 'Testland'},
      },
      'date': date,
      'time': time,
      for (final e in sessions.entries) e.key: {'date': e.value.split(' ')[0], 'time': e.value.split(' ')[1]},
    };

Map<String, dynamic> calendarBody(List<Map<String, dynamic>> races) => envelope({
      'RaceTable': {'Races': races},
    });

/// 2026 takvimi: biri geçmiş, biri [testNow]'dan sonra.
final calendar2026 = calendarBody([
  raceJson(round: 1, name: 'Past Grand Prix', date: '2026-03-15'),
  raceJson(
    round: 22,
    name: 'Test Grand Prix',
    date: '2026-11-08',
    sessions: {
      'FirstPractice': '2026-11-06 11:30:00Z',
      'Qualifying': '2026-11-07 15:00:00Z',
    },
  ),
]);

final allPast2026 = calendarBody([
  raceJson(round: 1, name: 'Past Grand Prix', date: '2026-03-15'),
]);

final calendar2027 = calendarBody([
  raceJson(round: 1, name: 'Opening Grand Prix', date: '2027-03-14'),
]);

final emptyCalendar = calendarBody(const []);

final lastResults = envelope({
  'RaceTable': {
    'Races': [
      {
        'raceName': 'Past Grand Prix',
        'Results': [
          {
            'position': '1',
            'points': '25',
            'status': 'Finished',
            'Driver': {'code': 'AAA', 'givenName': 'Alex', 'familyName': 'Tester'},
            'Constructor': {'constructorId': 'ferrari', 'name': 'Test Team One'},
            'Time': {'time': '1:30:00.000'},
          },
          {
            'position': '2',
            'points': '18',
            'status': 'Finished',
            'Driver': {'code': 'BBB', 'givenName': 'Bea', 'familyName': 'Sample'},
            'Constructor': {'constructorId': 'mclaren', 'name': 'Test Team Two'},
            'Time': {'time': '+1.234'},
          },
        ],
      },
    ],
  },
});

final driverStandings = envelope({
  'StandingsTable': {
    'StandingsLists': [
      {
        'DriverStandings': [
          {
            'position': '1',
            'points': '301',
            'wins': '9',
            'Driver': {'givenName': 'Alex', 'familyName': 'Tester'},
            'Constructors': [
              {'name': 'Test Team One'},
            ],
          },
          {
            'position': '2',
            'points': '288',
            'wins': '5',
            'Driver': {'givenName': 'Bea', 'familyName': 'Sample'},
            'Constructors': [
              {'name': 'Test Team Two'},
            ],
          },
        ],
      },
    ],
  },
});

final teamStandings = envelope({
  'StandingsTable': {
    'StandingsLists': [
      {
        'ConstructorStandings': [
          {
            'position': '1',
            'points': '577',
            'wins': '10',
            'Constructor': {'name': 'Test Team One'},
          },
        ],
      },
    ],
  },
});

/// Yol sonuna göre JSON döndüren sahte HTTP istemcisi.
///
/// [calendars] yıl → takvim gövdesi eşlemesidir. [offline] true yapılırsa her
/// istek bağlantı hatası verir; [status] 200 dışındaysa o kodla yanıtlar.
class FakeJolpica {
  FakeJolpica({Map<int, Map<String, dynamic>>? calendars})
      : calendars = calendars ?? {2026: calendar2026, 2027: calendar2027};

  final Map<int, Map<String, dynamic>> calendars;
  bool offline = false;
  int status = 200;
  int requestCount = 0;

  late final http.Client client = MockClient((request) async {
    requestCount++;
    if (offline) throw http.ClientException('offline');
    if (status != 200) return http.Response('error', status);

    final path = request.url.path;
    Map<String, dynamic>? body;
    if (path.endsWith('/last/results.json')) {
      body = lastResults;
    } else if (path.endsWith('driverStandings.json')) {
      body = driverStandings;
    } else if (path.endsWith('constructorStandings.json')) {
      body = teamStandings;
    } else {
      final match = RegExp(r'/(\d{4})\.json$').firstMatch(path);
      if (match != null) body = calendars[int.parse(match.group(1)!)] ?? emptyCalendar;
    }
    if (body == null) return http.Response('not found', 404);
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  });

  JolpicaRepository repository({MemoryStore? store}) =>
      JolpicaRepository(client: client, store: store ?? MemoryStore());
}
