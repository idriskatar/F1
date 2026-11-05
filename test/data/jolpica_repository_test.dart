import 'package:f1_tracker/data/remote/jolpica_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('nextRace mevcut sezondaki sıradaki yarışı bulur', () async {
    final api = FakeJolpica();
    final data = await api.repository().nextRace(now: testNow);

    expect(data.race?.name, 'Test Grand Prix');
    expect(data.isCached, isFalse);
  });

  test('nextRace mevcut sezon bittiyse gelecek sezon takvimine bakar', () async {
    final api = FakeJolpica(calendars: {2026: allPast2026, 2027: calendar2027});
    final data = await api.repository().nextRace(now: testNow);

    expect(data.race?.name, 'Opening Grand Prix');
  });

  test('nextRace yeni sezon takvimi yoksa null döner', () async {
    final api = FakeJolpica(calendars: {2026: allPast2026});
    final data = await api.repository().nextRace(now: testNow);

    expect(data.race, isNull);
  });

  test('canlı yanıt kaydedilir; bağlantı kopunca önbellekten döner', () async {
    final api = FakeJolpica();
    final store = MemoryStore();
    final repo = api.repository(store: store);

    await repo.nextRace(now: testNow);
    expect(store.entries.keys, contains('calendar-2026'));

    api.offline = true;
    final cached = await repo.nextRace(now: testNow);
    expect(cached.race?.name, 'Test Grand Prix');
    expect(cached.isCached, isTrue);
  });

  test('önbellek yokken HTTP hatası JolpicaException fırlatır', () async {
    final api = FakeJolpica()..status = 500;

    await expectLater(
      api.repository().nextRace(now: testNow),
      throwsA(isA<JolpicaException>().having((e) => e.message, 'message', contains('500'))),
    );
  });

  test('latestResults yarış adını label olarak taşır', () async {
    final data = await FakeJolpica().repository().latestResults();

    expect(data.label, 'Past Grand Prix');
    expect(data.items.first.code, 'AAA');
    expect(data.items, hasLength(2));
  });

  test('puan durumu sorguları satırları sırayla döndürür', () async {
    final repo = FakeJolpica().repository();

    final drivers = await repo.driverStandings(season: 2026);
    final teams = await repo.teamStandings(season: 2026);

    expect(drivers.items.map((d) => d.points), ['301', '288']);
    expect(teams.items.single.name, 'Test Team One');
  });

  group('tur detayı', () {
    test('raceResults doğru uca gider ve zengin alanları döndürür', () async {
      final api = FakeJolpica();
      final data = await api.repository().raceResults(2026, 1);

      expect(api.paths, contains('/ergast/f1/2026/1/results.json'));
      expect(data.label, 'Past Grand Prix');
      expect(data.items.first.name, 'Alex Tester');
      expect(data.items.last.time, '+1 Lap');
    });

    test('yapılmamış turda items boş döner (hata değil)', () async {
      final data = await FakeJolpica().repository().raceResults(2026, 22);
      expect(data.items, isEmpty);
    });

    test('qualifying ve sprintResults ilgili alanları ayrıştırır', () async {
      final api = FakeJolpica();
      final repo = api.repository();

      final quali = await repo.qualifying(2026, 1);
      final sprint = await repo.sprintResults(2026, 1);

      expect(api.paths, containsAll(['/ergast/f1/2026/1/qualifying.json', '/ergast/f1/2026/1/sprint.json']));
      expect(quali.items.map((q) => q.best), ['1:23.900', '1:24.800']);
      expect(sprint.items.single.name, 'Eli Sprinter');
    });

    test('driverStandingsAfter / teamStandingsAfter tura özel uçları kullanır', () async {
      final api = FakeJolpica();
      final repo = api.repository();

      final drivers = await repo.driverStandingsAfter(2026, 7);
      final teams = await repo.teamStandingsAfter(2026, 7);

      expect(api.paths, containsAll(['/ergast/f1/2026/7/driverStandings.json', '/ergast/f1/2026/7/constructorStandings.json']));
      expect(drivers.items.first.points, '301');
      expect(teams.items.single.points, '577');
    });

    test('tur sonuçları önbelleğe yazılır; bağlantı kopunca önbellekten döner', () async {
      final api = FakeJolpica();
      final repo = api.repository();
      await repo.raceResults(2026, 1);

      api.offline = true;
      final cached = await repo.raceResults(2026, 1);

      expect(cached.isCached, isTrue);
      expect(cached.items, hasLength(2));
    });
  });
}
