import 'package:f1_tracker/core/models/race_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

RaceWeekend weekend(String date, {String time = '14:00:00Z', Map<String, String> sessions = const {}}) =>
    RaceWeekend.fromJson(raceJson(round: 1, name: 'GP $date', date: date, time: time, sessions: sessions));

void main() {
  group('RaceWeekend.fromJson', () {
    test('yarış zamanını UTC olarak okur ve Yarış seansını ekler', () {
      final race = weekend('2026-11-08');

      expect(race.raceStart, DateTime.utc(2026, 11, 8, 14));
      expect(race.sessions.map((s) => s.name), contains('Yarış'));
      expect(race.location, 'Testville');
      expect(race.country, 'Testland');
      expect(race.round, 1);
    });

    test('seansları kronolojik sıraya dizer (sprint hafta sonu dahil)', () {
      final race = weekend('2026-11-08', sessions: {
        'Qualifying': '2026-11-07 15:00:00Z',
        'Sprint': '2026-11-07 11:00:00Z',
        'SprintQualifying': '2026-11-06 15:30:00Z',
        'FirstPractice': '2026-11-06 11:30:00Z',
      });

      expect(race.sessions.map((s) => s.name), [
        'Antrenman 1',
        'Sprint Sıralaması',
        'Sprint',
        'Sıralama Turları',
        'Yarış',
      ]);
    });

    test('saat alanı yoksa gece yarısı UTC varsayar', () {
      final race = RaceWeekend.fromJson({
        'round': '3',
        'raceName': 'No Time GP',
        'date': '2026-05-03',
      });
      expect(race.raceStart, DateTime.utc(2026, 5, 3));
    });

    test('eksik/bozuk alanlarda hata fırlatmaz', () {
      final race = RaceWeekend.fromJson({'Circuit': 'bozuk', 'round': 'x'});

      expect(race.name, 'Grand Prix');
      expect(race.round, 0);
      expect(race.raceStart, isNull);
      expect(race.sessions, isEmpty);
    });
  });

  group('upcomingRace', () {
    final races = [
      weekend('2026-03-15'),
      weekend('2026-12-06'), // sırasız verildiğini test etmek için araya
      weekend('2026-11-08'),
    ];

    test('şimdiden sonraki en yakın yarışı seçer (liste sırasından bağımsız)', () {
      expect(upcomingRace(races, testNow)?.raceStart, DateTime.utc(2026, 11, 8, 14));
    });

    test('tüm yarışlar geçmişse null döner', () {
      expect(upcomingRace(races, DateTime.utc(2027, 1, 1)), isNull);
    });

    test('yarış başladıktan sonra 3 saat boyunca hâlâ güncel sayılır', () {
      final during = DateTime.utc(2026, 11, 8, 16, 30);
      final after = DateTime.utc(2026, 11, 8, 17, 30);

      expect(upcomingRace(races, during)?.raceStart, DateTime.utc(2026, 11, 8, 14));
      expect(upcomingRace(races, after)?.raceStart, DateTime.utc(2026, 12, 6, 14));
    });

    test('raceStart olmayan kayıtları atlar', () {
      final noDate = RaceWeekend.fromJson({'raceName': 'TBD'});
      expect(upcomingRace([noDate], testNow), isNull);
    });
  });

  group('RaceWeekend.nextSession', () {
    final race = weekend('2026-11-08', sessions: {
      'FirstPractice': '2026-11-06 11:30:00Z',
      'Qualifying': '2026-11-07 15:00:00Z',
    });

    test('ilk başlamamış seansı döndürür', () {
      expect(race.nextSession(testNow)?.name, 'Antrenman 1');
      expect(race.nextSession(DateTime.utc(2026, 11, 7, 16))?.name, 'Yarış');
    });

    test('tüm seanslar bittiyse null döner', () {
      expect(race.nextSession(DateTime.utc(2026, 11, 9)), isNull);
    });
  });

  group('Puan durumu ve sonuç modelleri', () {
    test('DriverStanding eksik alanlarda varsayılan değer kullanır', () {
      final s = DriverStanding.fromJson(const {});
      expect(s.name, 'Unknown driver');
      expect(s.points, '0');
      expect(s.team, 'Unknown team');
    });

    test('DriverResult takım rengini constructorId ile eşler', () {
      final r = DriverResult.fromJson({
        'position': '1',
        'Driver': {'code': 'abc'},
        'Constructor': {'constructorId': 'ferrari', 'name': 'Ferrari'},
        'Time': {'time': '1:00:00.000'},
      });
      expect(r.code, 'ABC');
      expect(r.color, 0xFFE8002D);
      expect(r.time, '1:00:00.000');
    });

    test('DriverResult Constructor liste olarak gelirse de çalışır', () {
      final r = DriverResult.fromJson({
        'position': '2',
        'Driver': {'code': 'xyz'},
        'Constructor': [
          {'constructorId': 'mclaren', 'name': 'McLaren'},
        ],
      });
      expect(r.team, 'McLaren');
      expect(r.color, 0xFFFF8000);
    });

    test('DriverResult grid, tur, en hızlı tur ve isim alanlarını okur', () {
      final r = DriverResult.fromJson((lastResults['MRData'] as Map)['RaceTable']['Races'][0]['Results'][0] as Map<String, dynamic>);
      expect(r.name, 'Alex Tester');
      expect(r.grid, 2);
      expect(r.laps, 57);
      expect(r.points, '25');
      expect(r.fastestLapRank, 1);
      expect(r.fastestLapTime, '1:23.456');
    });

    test('DriverResult süre yoksa durum metnini gösterir (puanı değil)', () {
      final r = DriverResult.fromJson({
        'position': '15',
        'points': '0',
        'status': '+1 Lap',
        'Driver': {'code': 'zzz'},
      });
      expect(r.time, '+1 Lap');
      expect(r.status, '+1 Lap');
      expect(r.fastestLapTime, isNull);
    });

    test('QualifyingResult en iyi dereceyi son tur sırasıyla seçer', () {
      final q3 = QualifyingResult.fromJson({
        'position': '1',
        'Driver': {'code': 'cq', 'givenName': 'Cara', 'familyName': 'Qualifier'},
        'Constructor': {'constructorId': 'ferrari', 'name': 'T'},
        'Q1': '1:25.1', 'Q2': '1:24.5', 'Q3': '1:23.9',
      });
      final q1Only = QualifyingResult.fromJson({'position': '20', 'Q1': '1:29.0'});
      final none = QualifyingResult.fromJson(const {});

      expect(q3.best, '1:23.9');
      expect(q3.name, 'Cara Qualifier');
      expect(q3.color, 0xFFE8002D);
      expect(q1Only.best, '1:29.0');
      expect(none.best, '—');
    });

    test('RaceWeekend sezon, pist adı ve sprint bilgisini taşır', () {
      final sprint = RaceWeekend.fromJson(raceJson(
        round: 2, name: 'Sprint GP', date: '2026-04-05', sessions: {'Sprint': '2026-04-04 11:00:00Z'},
      ));
      final normal = weekend('2026-11-08');

      expect(sprint.season, 2026);
      expect(sprint.circuitName, 'Test Circuit');
      expect(sprint.hasSprint, isTrue);
      expect(normal.hasSprint, isFalse);
    });

    test('TeamStanding yanıtı ayrıştırır', () {
      final t = TeamStanding.fromJson({
        'position': '2',
        'points': '10',
        'wins': '1',
        'Constructor': {'name': 'Test Team'},
      });
      expect((t.position, t.name, t.points, t.wins), (2, 'Test Team', '10', '1'));
    });
  });
}
