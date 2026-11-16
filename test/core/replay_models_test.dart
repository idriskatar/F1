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
}
