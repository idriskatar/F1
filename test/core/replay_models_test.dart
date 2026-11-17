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
}
