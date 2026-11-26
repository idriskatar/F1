import 'dart:convert';
import 'dart:io';

import 'package:f1_tracker/core/models/replay_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// tool/replay/sample_data.py ile üretilen, tamamen UYDURMA bir seans.
Map<String, dynamic> loadFixture() =>
    jsonDecode(File('test/fixtures/replay_sample.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late ReplayData data;

  setUp(() => data = ReplayData.fromJson(loadFixture()));

  test('Python çıktısı (sözleşme) Dart modeline doğru okunur', () {
    expect(data.event.name, 'Test Grand Prix');
    expect(data.hz, 2);
    expect(data.duration, 60);
    expect(data.totalLaps, 3);
    expect(data.lapStarts, [0, 20, 40]);
    expect(data.drivers.map((d) => d.code), ['AAA', 'BBB', 'CCC', 'DDD']);
    expect(data.drivers.first.x.length, 121);
    expect(data.trackX.length, data.trackY.length);
    expect(data.trackX.first, data.trackX.last, reason: 'Pist çizgisi kapalı olmalı');
    expect(data.drivers.first.colorValue, 0xFF3671C6);
  });

  test('konum iki örnek arasında doğrusal ara değerlenir', () {
    final a = data.drivers.first;
    final p0 = a.positionAt(0, data.hz)!;
    final p1 = a.positionAt(0.5, data.hz)!;
    final mid = a.positionAt(0.25, data.hz)!;
    expect(p0.x, 3000);
    expect(mid.x, closeTo((p0.x + p1.x) / 2, 0.01));
    expect(mid.y, closeTo((p0.y + p1.y) / 2, 0.01));
  });

  test('veri olmayan anlarda konum null döner (tahmin edilmez)', () {
    final d = data.drivers.last; // DDD: 15. sn civarı veri boşluğu, 40. sn'den sonra veri yok
    expect(d.positionAt(5, data.hz), isNotNull);
    expect(d.positionAt(15, data.hz), isNull);
    expect(d.positionAt(50, data.hz), isNull);
    expect(d.positionAt(-1, data.hz), isNull);
    expect(d.positionAt(9999, data.hz), isNull);
  });

  test('tur sayacı liderin tur başlangıçlarını izler', () {
    expect(data.lapAt(0), 1);
    expect(data.lapAt(19.9), 1);
    expect(data.lapAt(20), 2);
    expect(data.lapAt(45), 3);
    expect(data.lapAt(60), 3);
  });

  test('pit durumu giriş ve çıkış arasında geçerlidir', () {
    expect(data.pits.length, 1);
    expect(data.pits.single.pitLaneSeconds, 5);
    expect(data.inPit('BBB', 37.9), isFalse);
    expect(data.inPit('BBB', 38), isTrue);
    expect(data.inPit('BBB', 43), isTrue);
    expect(data.inPit('BBB', 43.1), isFalse);
    expect(data.inPit('AAA', 40), isFalse);
  });

  test('telemetri kanalları okunur', () {
    final a = data.drivers.first;
    expect(a.hasTelemetry, isTrue);
    expect(a.speedAt(5, data.hz), isNotNull);
    expect(a.gearAt(5, data.hz), inInclusiveRange(1, 8));
    expect(a.throttleAt(5, data.hz), inInclusiveRange(0, 100));
    expect(a.brakeAt(5, data.hz), isA<bool>());
    expect(a.drsAt(5, data.hz), isA<bool>());
    expect(a.speedSeries(0, 5, data.hz).length, 11);
  });

  test('desteklenmeyen sürüm açık bir hatayla reddedilir', () {
    final json = {...loadFixture(), 'version': 99};
    expect(() => ReplayData.fromJson(json), throwsA(isA<ReplayFormatException>()));
  });

  test('eksik zorunlu alanlar hata verir', () {
    final noDrivers = {...loadFixture(), 'drivers': <dynamic>[]};
    expect(() => ReplayData.fromJson(noDrivers), throwsA(isA<ReplayFormatException>()));
    final noTrack = {...loadFixture()}..remove('track');
    expect(() => ReplayData.fromJson(noTrack), throwsA(isA<ReplayFormatException>()));
  });

  test('index.json okunur ve önbellek adı üretim zamanına bağlıdır', () {
    final index = ReplayIndex.fromJson({
      'version': 1,
      'sessions': [
        {
          'year': 2099, 'round': 1, 'session': 'R', 'name': 'Test Grand Prix', 'country': 'Testland',
          'circuit': 'Ovalville', 'file': '2099/r01-R.json.gz', 'bytes': 1234, 'duration': 60.0,
          'generatedAt': '2026-11-15T12:00:00Z',
        },
      ],
    });
    final entry = index.sessions.single;
    expect(entry.sessionLabel, 'Yarış');
    expect(entry.cacheName, '2099-r1-R-20261115120000');
    expect(index.isCached, isFalse);
  });

  test('yeni alanlar: soyad, rpm, sıra geçmişi, turlar ve stintler okunur', () {
    final a = data.drivers.first;
    expect(a.surname, 'Alpha');
    expect(a.rpmAt(5, data.hz), inInclusiveRange(6000, 12000));
    expect(a.positionLog.length, 1);
    expect(a.laps.length, 3);
    expect(a.laps[0].s1, isNull); // 1. turun 1. sektörü boş
    expect(a.laps[1].s1, 5.5);
    expect(data.hasLivePositions, isTrue);
    expect(data.drivers[1].stints.map((s) => s.letter), ['M', 'H']);
  });

  test('sıralama zamana göre değişir', () {
    List<String> codes(double t) => data.orderAt(t).map((d) => d.code).toList();
    expect(codes(10), ['AAA', 'BBB', 'CCC', 'DDD']);
    expect(codes(29.9), ['AAA', 'BBB', 'CCC', 'DDD']);
    expect(codes(30), ['AAA', 'CCC', 'BBB', 'DDD']);
    final bravo = data.drivers[1];
    expect(bravo.rankAt(10), 2);
    expect(bravo.rankAt(45), 3);
    expect(bravo.rankAt(-1), isNull);
  });

  test('eski biçimli dosya (yeni alanlar yok) açılır ve bitiş sırasını gösterir', () {
    final json = loadFixture();
    for (final driver in json['drivers'] as List) {
      (driver as Map<String, dynamic>)
        ..remove('positionLog')
        ..remove('laps')
        ..remove('stints')
        ..remove('rpm')
        ..remove('lastName');
    }
    final old = ReplayData.fromJson(json);
    expect(old.hasLivePositions, isFalse);
    expect(old.orderAt(40).map((d) => d.code).toList(), ['AAA', 'BBB', 'CCC', 'DDD']);
    expect(old.drivers.first.surname, 'A'); // adın son sözcüğü
    expect(old.drivers.first.currentLapAt(10), isNull);
    expect(old.sectorStatesAt(old.drivers.first, 10), everyElement(SectorStatus.unknown));
  });

  test('süren ve tamamlanan tur', () {
    final a = data.drivers.first;
    expect(a.currentLapAt(25)!.number, 2);
    expect(a.lastCompletedLapAt(25)!.number, 1);
    expect(a.lastCompletedLapAt(10), isNull);
    expect(a.currentLapAt(-1), isNull);
  });

  test('sektör en iyileri yalnızca o ana kadar tamamlananlardan hesaplanır', () {
    final a = data.drivers.first;
    expect(data.bestsAt(25, a).sectors[0], isNull); // AAA S1 25.5'te biter, 1. turda S1 boş
    final at26 = data.bestsAt(26, a);
    expect(at26.sectors[0], 5.5);
    expect(at26.personalSectors[0], 5.5);
    expect(at26.lap, 20.0);
    expect(at26.classifyLap(20.0), SectorStatus.overallBest);
    expect(at26.classifyLap(21.0), SectorStatus.slower);
  });

  test('sektör durumları tur ilerledikçe renklenir', () {
    final a = data.drivers.first;
    expect(data.sectorStatesAt(a, 5), [SectorStatus.unknown, SectorStatus.unknown, SectorStatus.unknown]);
    expect(data.sectorStatesAt(a, 25), [SectorStatus.active, SectorStatus.upcoming, SectorStatus.upcoming]);
    expect(data.sectorStatesAt(a, 26), [SectorStatus.overallBest, SectorStatus.active, SectorStatus.upcoming]);
    expect(data.sectorStatesAt(a, 34), [SectorStatus.overallBest, SectorStatus.overallBest, SectorStatus.active]);
  });

  test('lastik: tur numarasına göre bileşen ve yaş', () {
    final bravo = data.drivers[1];
    expect(bravo.stintAtLap(2)!.compound, 'MEDIUM');
    expect(bravo.stintAtLap(2)!.ageAt(2), 1);
    expect(bravo.stintAtLap(3)!.letter, 'H');
    expect(bravo.stintAtLap(3)!.ageAt(3), 0);
    expect(bravo.stintAtLap(0), isNull);
    expect(data.drivers[2].stintAtLap(3)!.ageAt(3), 4); // başlangıç yaşı 2 + 2 tur
  });

  test('tur süresi biçimlenir', () {
    expect(formatLapTime(104.84), '1:44.840');
    expect(formatLapTime(59.5), '0:59.500');
    expect(formatLapTime(5), '0:05.000');
  });

  test('hava ölçümleri okunur ve ana göre seçilir', () {
    final first = data.weatherAt(0)!;
    expect(first.air, 24.0);
    expect(first.track, 38.0);
    expect(first.humidity, 52);
    expect(first.wind, 12.0);
    expect(first.windDirection, 135);
    expect(first.raining, isFalse);
    expect(data.weatherAt(29.9)!.raining, isFalse);
    expect(data.weatherAt(30)!.raining, isTrue);
    expect(data.weatherAt(30)!.air, 24.5);
    expect(data.weatherAt(-5)!.time, 0.0); // ilk ölçümden önce: ilk ölçüm
  });

  test('hava verisi olmayan eski dosya açılır', () {
    final json = loadFixture()..remove('weather');
    final old = ReplayData.fromJson(json);
    expect(old.weather, isEmpty);
    expect(old.weatherAt(10), isNull);
  });

  test('en hızlı tur sahibi o ana kadarki turlardan seçilir', () {
    expect(data.fastestLapHolderAt(10), isNull); // henüz tur bitmedi
    expect(data.fastestLapHolderAt(25), 'AAA'); // 1. turlar bitti; eşitlikte ilk bitiren/ilk pilot
  });

  test('anlık lastik: tur bilgisi yoksa 1. tur kabul edilir', () {
    final bravo = data.drivers[1];
    expect(bravo.stintAt(-1)!.letter, 'M');
    expect(bravo.stintAt(10)!.letter, 'M');
    expect(bravo.stintAt(45)!.letter, 'H');
    expect(data.drivers.first.stintAt(0)!.letter, 'S');
    final json = loadFixture();
    for (final driver in json['drivers'] as List) {
      (driver as Map<String, dynamic>).remove('stints');
    }
    expect(ReplayData.fromJson(json).drivers.first.stintAt(0), isNull);
  });

  test('yarış yönetimi olayları okunur: dönemler ve cezalar', () {
    expect(
      data.events.map((e) => e.kind),
      [ReplayEventKind.penalty, ReplayEventKind.safetyCar, ReplayEventKind.virtualSafetyCar],
    );
    expect(data.events.first.lap, 1);
    expect(data.events.first.end, isNull);
    expect(data.periods.length, 2); // ceza dönem değildir
    expect(data.periodAt(36)!.kind, ReplayEventKind.safetyCar);
    expect(data.periodAt(45), isNull); // bitiş anı dahil değil
    expect(data.periodAt(52)!.badge, 'VSC');
    expect(data.periodAt(12), isNull);
  });

  test('bozuk olay satırları atlanır, alan yoksa liste boş kalır', () {
    final json = loadFixture();
    json['events'] = [
      [5, 'UNKNOWN', 1, 'x', 9],
      'garbage',
      [10],
      [20, 'RED', null, 'RED FLAG', 30],
    ];
    final parsed = ReplayData.fromJson(json);
    expect(parsed.events.length, 1);
    expect(parsed.events.single.kind, ReplayEventKind.redFlag);
    expect(parsed.events.single.lap, isNull);
    expect(parsed.periodAt(25)!.label, 'Kırmızı bayrak');

    json.remove('events');
    final old = ReplayData.fromJson(json);
    expect(old.events, isEmpty);
    expect(old.periodAt(36), isNull);
  });

  test('tur atlama hedefi: ileri sonraki tura, geri önce tur başına sonra önceki tura', () {
    expect(data.lapJumpTarget(0, forward: true), 20);
    expect(data.lapJumpTarget(25, forward: true), 40);
    expect(data.lapJumpTarget(45, forward: true), 60); // son turdan sonra yarış sonu
    expect(data.lapJumpTarget(25, forward: false), 20); // tur başından 3 sn'den fazla geçti
    expect(data.lapJumpTarget(21, forward: false), 0); // tur başına çok yakın: önceki tur
    expect(data.lapJumpTarget(2, forward: false), 0);
    expect(data.lapStartTime(2), 20);
    expect(data.lapStartTime(4), isNull);
  });

  test('fark örnekleri okunur; gapAt son örneği verir, yoksa ya da bayatsa null', () {
    final bbb = data.driverByCode('BBB')!;
    expect(bbb.gaps.length, 5);
    expect(bbb.gapAt(-1), isNull); // henüz örnek yok
    expect(bbb.gapAt(7)!.toLeader, 2.3); // 6. sn örneği
    expect(bbb.gapAt(7)!.text(toLeader: true), '+2.3');
    expect(bbb.gapAt(30)!.text(toLeader: false), '+3.2');
    expect(bbb.gapAt(24 + 121), isNull); // 120 sn'den eski örnek bayat sayılır
    expect(bbb.gapAt(24 + 121, maxAge: 200), isNotNull);

    final ddd = data.driverByCode('DDD')!;
    expect(ddd.gapAt(20)!.lapped, '+1 LAP');
    expect(ddd.gapAt(20)!.toLeader, isNull);
    expect(ddd.gapAt(20)!.text(toLeader: true), '+1 LAP');

    expect(data.driverByCode('AAA')!.gaps, isEmpty); // lider
    expect(data.hasGaps, isTrue);
  });

  test('gapBetween: lider 0 sayılır; tur kaybı ya da bayat örnek varsa null', () {
    final a = data.driverByCode('AAA')!;
    final b = data.driverByCode('BBB')!;
    final c = data.driverByCode('CCC')!;
    final d = data.driverByCode('DDD')!;
    expect(data.gapBetween(a, b, 7), closeTo(2.3, 1e-9));
    expect(data.gapBetween(b, c, 7), closeTo(2.7, 1e-9)); // 5.0 - 2.3
    expect(data.gapBetween(c, b, 7), closeTo(2.7, 1e-9)); // sıra önemsiz
    expect(data.gapBetween(b, d, 20), isNull); // DDD tur kaybetti
  });

  test('bozuk fark satırları atılır, fark alanı yoksa hasGaps false olur', () {
    final json = loadFixture();
    final drivers = json['drivers'] as List;
    (drivers[1] as Map<String, dynamic>)['gaps'] = [
      [5, 3.0, 1.0],
      [1],
      'x',
      ['a', 1.0, 1.0],
    ];
    final parsed = ReplayData.fromJson(json);
    expect(parsed.driverByCode('BBB')!.gaps.length, 1);

    for (final driver in drivers) {
      (driver as Map<String, dynamic>).remove('gaps');
    }
    final old = ReplayData.fromJson(json);
    expect(old.hasGaps, isFalse);
    expect(old.gapBetween(old.drivers[0], old.drivers[1], 7), isNull);
  });
}
