import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('üç kaynağı birleştirir: tarihliler önce, tarihsiz resmi F1 haberleri sonda', () async {
    final result = await FakeFeeds().repository().fetchAll();

    expect(result.items.map((i) => i.title), [
      'Motorsport headline', // 5 Kas 07:30Z
      'Autosport headline', // 4 Kas 10:00Z
      'F1 headline one', // tarihsiz
      'F1 headline two',
    ]);
    expect(result.errors, isEmpty);
    expect(result.cachedSources, isEmpty);
  });

  test('Autosport özetinden "Keep reading" ve HTML temizlenir; UTF-8 bozulmaz', () async {
    final result = await FakeFeeds().repository().fetchAll();

    final autosport = result.items.firstWhere((i) => i.sourceId == 'autosport');
    final motorsport = result.items.firstWhere((i) => i.sourceId == 'motorsport');
    expect(autosport.summary, 'Intro text from Autosport…');
    expect(motorsport.summary, 'Hamilton’s weekend in brief.');
  });

  test('bir kaynak çökerse diğerleri gösterilir ve hata o kaynağa yazılır', () async {
    final feeds = FakeFeeds()..failingHosts.add('www.autosport.com');
    final result = await feeds.repository().fetchAll();

    expect(result.items.map((i) => i.sourceId).toSet(), {'f1', 'motorsport'});
    expect(result.errors.keys, ['autosport']);
    expect(result.errors['autosport'], contains('503'));
  });

  test('kaynak çökünce önceki başarılı çekim önbellekten sunulur', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();
    await repo.fetchAll();

    feeds.failingHosts.add('www.autosport.com');
    final result = await repo.fetchAll(force: true);

    expect(result.items.map((i) => i.title), contains('Autosport headline'));
    expect(result.errors.keys, ['autosport']);
    expect(result.cachedSources, {'autosport'});
  });

  test('tüm kaynaklar çökerse ve önbellek yoksa boş liste + üç hata döner', () async {
    final feeds = FakeFeeds()..offline = true;
    final result = await feeds.repository().fetchAll();

    expect(result.items, isEmpty);
    expect(result.errors.keys.toSet(), {'f1', 'autosport', 'motorsport'});
  });

  test('bozuk önbellek girdisi sorun çıkarmaz; kaynak hatası yine bildirilir', () async {
    final feeds = FakeFeeds();
    final store = MemoryStore();
    store.entries['news-f1'] = 'not json';
    final repo = feeds.repository(store: store);

    feeds.failingHosts.add('www.formula1.com');
    final result = await repo.fetchAll();

    expect(result.errors.keys, ['f1']);
    expect(result.items.any((i) => i.sourceId == 'f1'), isFalse);
  });

  test('taze sonuç yeniden kullanılır; force ağa yeniden gider', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();

    await repo.fetchAll();
    await repo.fetchAll();
    expect(feeds.requestCount, 3);

    await repo.fetchAll(force: true);
    expect(feeds.requestCount, 6);
  });

  test('eşzamanlı çağrılar tek istek turunu paylaşır (Ana sayfa + Haberler)', () async {
    final feeds = FakeFeeds();
    final repo = feeds.repository();

    final results = await Future.wait([repo.fetchAll(), repo.fetchAll()]);

    expect(feeds.requestCount, 3);
    expect(identical(results[0], results[1]), isTrue);
  });
}
