import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('Türkçe iki RSS kaynağını tarih sırasıyla birleştirir', () async {
    final result = await FakeFeeds().repository().fetchAll();

    expect(result.items.map((i) => i.title), [
      'Motorsport Türkiye headline', // 5 Kas 07:30Z
      'TRF1 headline one', // 4 Kas 10:00Z
      'TRF1 headline two', // 3 Kas 10:00Z
    ]);
    expect(result.errors, isEmpty);
    expect(result.cachedSources, isEmpty);
  });

  test('Motorsport Türkiye özetinden "Keep reading" ve HTML temizlenir; UTF-8 bozulmaz', () async {
    final result = await FakeFeeds().repository().fetchAll();

    final trf1 = result.items.firstWhere((i) => i.sourceId == 'trf1');
    final motorsport = result.items.firstWhere((i) => i.sourceId == 'motorsport_tr');
    expect(trf1.summary, 'Short summary & more');
    expect(motorsport.summary, 'Hamilton’s weekend in brief.');
  });

  test('bir kaynak çökerse diğerleri gösterilir ve hata o kaynağa yazılır', () async {
    final feeds = FakeFeeds()..failingHosts.add('trf1.net');
    final result = await feeds.repository().fetchAll();

    expect(result.items.map((i) => i.sourceId).toSet(), {'motorsport_tr'});
    expect(result.errors.keys, ['trf1']);
    expect(result.errors['trf1'], contains('503'));
  });

  test('kaynak çökünce önceki başarılı çekim önbellekten sunulur', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();
    await repo.fetchAll();

    feeds.failingHosts.add('trf1.net');
    final result = await repo.fetchAll(force: true);

    expect(result.items.map((i) => i.title), contains('TRF1 headline one'));
    expect(result.errors.keys, ['trf1']);
    expect(result.cachedSources, {'trf1'});
  });

  test('tüm kaynaklar çökerse ve önbellek yoksa boş liste + iki hata döner', () async {
    final feeds = FakeFeeds()..offline = true;
    final result = await feeds.repository().fetchAll();

    expect(result.items, isEmpty);
    expect(result.errors.keys.toSet(), {'trf1', 'motorsport_tr'});
  });

  test('bozuk önbellek girdisi sorun çıkarmaz; kaynak hatası yine bildirilir', () async {
    final feeds = FakeFeeds();
    final store = MemoryStore();
    store.entries['news-trf1'] = 'not json';
    final repo = feeds.repository(store: store);

    feeds.failingHosts.add('trf1.net');
    final result = await repo.fetchAll();

    expect(result.errors.keys, ['trf1']);
    expect(result.items.any((i) => i.sourceId == 'trf1'), isFalse);
  });

  test('taze sonuç yeniden kullanılır; force ağa yeniden gider', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();

    await repo.fetchAll();
    await repo.fetchAll();
    expect(feeds.requestCount, 2);

    await repo.fetchAll(force: true);
    expect(feeds.requestCount, 4);
  });

  test('eşzamanlı çağrılar tek istek turunu paylaşır (Ana sayfa + Haberler)', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();

    final results = await Future.wait([repo.fetchAll(), repo.fetchAll()]);

    expect(feeds.requestCount, 2);
    expect(identical(results[0], results[1]), isTrue);
  });
}
