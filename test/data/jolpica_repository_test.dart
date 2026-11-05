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
}
