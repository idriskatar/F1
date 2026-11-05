import 'dart:convert';

import 'package:f1_tracker/data/local/local_store.dart';
import 'package:f1_tracker/data/remote/jolpica_repository.dart';
import 'package:f1_tracker/data/remote/news_repository.dart';
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

Map<String, dynamic> resultsBody(String raceName) => envelope({
      'RaceTable': {
        'Races': [
          {
            'raceName': raceName,
            'Results': [
              {
                'position': '1',
                'points': '25',
                'grid': '2',
                'laps': '57',
                'status': 'Finished',
                'Driver': {'code': 'AAA', 'givenName': 'Alex', 'familyName': 'Tester'},
                'Constructor': {'constructorId': 'ferrari', 'name': 'Test Team One'},
                'Time': {'time': '1:30:00.000'},
                'FastestLap': {
                  'rank': '1',
                  'Time': {'time': '1:23.456'},
                },
              },
              {
                'position': '2',
                'points': '18',
                'grid': '1',
                'laps': '56',
                'status': '+1 Lap',
                'Driver': {'code': 'BBB', 'givenName': 'Bea', 'familyName': 'Sample'},
                'Constructor': {'constructorId': 'mclaren', 'name': 'Test Team Two'},
              },
            ],
          },
        ],
      },
    });

final lastResults = resultsBody('Past Grand Prix');

final qualifyingBody = envelope({
  'RaceTable': {
    'Races': [
      {
        'raceName': 'Past Grand Prix',
        'QualifyingResults': [
          {
            'position': '1',
            'Driver': {'code': 'CQ', 'givenName': 'Cara', 'familyName': 'Qualifier'},
            'Constructor': {'constructorId': 'ferrari', 'name': 'Test Team One'},
            'Q1': '1:25.100',
            'Q2': '1:24.500',
            'Q3': '1:23.900',
          },
          {
            'position': '2',
            'Driver': {'code': 'DP', 'givenName': 'Dan', 'familyName': 'Poleman'},
            'Constructor': {'constructorId': 'mclaren', 'name': 'Test Team Two'},
            'Q1': '1:25.300',
            'Q2': '1:24.800',
          },
        ],
      },
    ],
  },
});

final sprintBody = envelope({
  'RaceTable': {
    'Races': [
      {
        'raceName': 'Past Grand Prix',
        'SprintResults': [
          {
            'position': '1',
            'points': '8',
            'grid': '3',
            'laps': '19',
            'status': 'Finished',
            'Driver': {'code': 'ES', 'givenName': 'Eli', 'familyName': 'Sprinter'},
            'Constructor': {'constructorId': 'mercedes', 'name': 'Test Team Three'},
            'Time': {'time': '30:00.000'},
          },
        ],
      },
    ],
  },
});

/// Henüz yapılmamış tur: Jolpica boş `Races` listesi döndürür.
final emptyRaceTable = envelope({
  'RaceTable': {'Races': []},
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
  final List<String> paths = [];

  late final http.Client client = MockClient((request) async {
    requestCount++;
    paths.add(request.url.path);
    if (offline) throw http.ClientException('offline');
    if (status != 200) return http.Response('error', status);

    final path = request.url.path;
    Map<String, dynamic>? body;
    final round = RegExp(r'/(\d{4})/(\d+)/(results|qualifying|sprint)\.json$').firstMatch(path);
    if (path.endsWith('/last/results.json')) {
      body = lastResults;
    } else if (round != null) {
      // Yalnızca 1. tur "yapılmış" sayılır; diğer turlar boş döner.
      final done = round.group(2) == '1';
      body = !done
          ? emptyRaceTable
          : switch (round.group(3)!) {
              'results' => lastResults,
              'qualifying' => qualifyingBody,
              _ => sprintBody,
            };
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


// ---------------------------------------------------------------------------
// RSS
// ---------------------------------------------------------------------------

const f1FeedUrl = 'https://www.formula1.com/en/latest/all.xml';

/// Resmi F1 akışı gibi: öğelerde yayın tarihi YOK.
const f1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Formula 1</title>
<item><title>F1 headline one</title><link>https://www.formula1.com/en/latest/article/one</link><description>Short summary &amp; more</description></item>
<item><title>F1 headline two</title><link>https://www.formula1.com/en/latest/article/two</link><description>Second summary</description></item>
</channel></rss>''';

/// Autosport gibi: CDATA içinde HTML, "Keep reading" bağlantısı, RFC 822 tarih.
const autosportXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Autosport</title>
<item>
<title>Autosport headline</title>
<link>https://www.autosport.com/f1/news/a/1/?utm_source=RSS</link>
<description><![CDATA[Intro text from Autosport&hellip; <a class='more' href='https://www.autosport.com/f1/news/a/1/'>Keep reading</a>]]></description>
<pubDate>Wed, 04 Nov 2026 10:00:00 +0000</pubDate>
</item>
</channel></rss>''';

/// Motorsport.com gibi: +0100 saat dilimli tarih ve UTF-8 özel karakter.
const motorsportXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Motorsport.com</title>
<item>
<title>Motorsport headline</title>
<link>https://www.motorsport.com/f1/news/m/1/?utm_source=RSS</link>
<description><![CDATA[Hamilton’s weekend in brief. <a href='https://www.motorsport.com/f1/news/m/1/'>Keep reading</a>]]></description>
<pubDate>Thu, 05 Nov 2026 08:30:00 +0100</pubDate>
</item>
</channel></rss>''';

/// Konuma göre RSS döndüren sahte HTTP istemcisi.
class FakeFeeds {
  /// Bu ana makinelere (örn. `www.autosport.com`) gelen istekler HTTP 503 alır.
  final Set<String> failingHosts = {};
  bool offline = false;
  int requestCount = 0;

  late final http.Client client = MockClient((request) async {
    requestCount++;
    if (offline) throw http.ClientException('offline');
    final host = request.url.host;
    if (failingHosts.contains(host)) return http.Response('unavailable', 503);
    final xml = switch (host) {
      'www.formula1.com' => f1Xml,
      'www.autosport.com' => autosportXml,
      'www.motorsport.com' => motorsportXml,
      _ => null,
    };
    if (xml == null) return http.Response('not found', 404);
    return http.Response(xml, 200, headers: {'content-type': 'application/rss+xml; charset=utf-8'});
  });

  NewsRepository repository({MemoryStore? store, Duration? freshFor}) => NewsRepository(
        client: client,
        store: store ?? MemoryStore(),
        freshFor: freshFor ?? const Duration(minutes: 2),
      );
}
