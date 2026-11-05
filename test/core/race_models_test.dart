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
