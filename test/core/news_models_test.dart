import 'package:f1_tracker/core/models/news_models.dart';
import 'package:flutter_test/flutter_test.dart';

const source = NewsSource(id: 'x', name: 'Test Source', url: 'https://example.com/rss');

void main() {
  group('parseFeed (RSS)', () {
    const rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>T</title>
<item>
  <title>  First &amp; Best  </title>
  <link>https://example.com/a?utm_source=RSS&amp;utm_medium=referral</link>
  <description><![CDATA[Hello <b>world</b>&hellip; <a class='more' href='https://example.com/a'>Keep reading</a>]]></description>
  <pubDate>Thu, 05 Nov 2026 08:30:00 +0100</pubDate>
</item>
<item><title>No link</title></item>
<item><link>https://example.com/no-title</link></item>
<item><title>Bad scheme</title><link>javascript:alert(1)</link></item>
</channel></rss>''';

    test('başlık, bağlantı, temizlenmiş özet ve UTC tarihi okur; geçersiz öğeleri atlar', () {
      final items = parseFeed(rss, source);

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.title, 'First & Best');
      expect(item.url, 'https://example.com/a?utm_source=RSS&utm_medium=referral');
      expect(item.summary, 'Hello world…');
      expect(item.sourceId, 'x');
      expect(item.sourceName, 'Test Source');
      expect(item.publishedAt, DateTime.utc(2026, 11, 5, 7, 30));
    });

    test('tarihsiz öğeyi publishedAt = null ile alır', () {
      final items = parseFeed(
        '<rss version="2.0"><channel><item><title>T</title><link>https://e.com/1</link></item></channel></rss>',
        source,
      );
      expect(items.single.publishedAt, isNull);
      expect(items.single.summary, isEmpty);
    });

    test('uzun özeti kelime sınırında kısaltır', () {
      final long = List.filled(80, 'word').join(' ');
      final items = parseFeed(
        '<rss version="2.0"><channel><item><title>T</title><link>https://e.com/1</link><description>$long</description></item></channel></rss>',
        source,
      );
      expect(items.single.summary.length, lessThanOrEqualTo(221));
      expect(items.single.summary, endsWith('…'));
    });

    test('limit uygular', () {
      final many = List.generate(
        40,
        (i) => '<item><title>T$i</title><link>https://e.com/$i</link></item>',
      ).join();
      final items = parseFeed('<rss version="2.0"><channel>$many</channel></rss>', source, limit: 5);
      expect(items, hasLength(5));
    });

    test('BOM ve baştaki boşlukla gelen akışı da okur', () {
      final items = parseFeed(
        '\uFEFF\n<?xml version="1.0"?><rss version="2.0"><channel><item><title>T</title><link>https://e.com/1</link></item></channel></rss>',
        source,
      );
      expect(items, hasLength(1));
    });
  });

  group('parseFeed (Atom)', () {
    test('entry, alternate bağlantı, özet ve ISO tarihi okur', () {
      const atom = '''<feed xmlns="http://www.w3.org/2005/Atom">
<entry><title>Atom title</title>
<link rel="self" href="https://example.com/self"/>
<link rel="alternate" href="https://example.com/atom/1"/>
<summary>Atom summary</summary>
<updated>2026-11-04T10:00:00Z</updated></entry></feed>''';
      final item = parseFeed(atom, source).single;

      expect(item.title, 'Atom title');
      expect(item.url, 'https://example.com/atom/1');
      expect(item.summary, 'Atom summary');
      expect(item.publishedAt, DateTime.utc(2026, 11, 4, 10));
    });
  });

  group('parseFeed (hatalar)', () {
    test('XML olmayan yanıt NewsFeedException fırlatır', () {
      expect(() => parseFeed('not xml at all', source), throwsA(isA<NewsFeedException>()));
    });

    test('200 dönen HTML sayfasını akış saymaz', () {
      expect(
        () => parseFeed('<html><body>Just a moment...</body></html>', source),
        throwsA(isA<NewsFeedException>()),
      );
    });
  });

  group('parseFeedDate', () {
    test('RFC 822 saat dilimlerini UTC\'ye çevirir', () {
      expect(parseFeedDate('Thu, 05 Nov 2026 08:30:00 +0100'), DateTime.utc(2026, 11, 5, 7, 30));
      expect(parseFeedDate('Sat, 28 Jan 2017 05:45:00 GMT'), DateTime.utc(2017, 1, 28, 5, 45));
      expect(parseFeedDate('Wed, 04 Nov 2026 10:00:00 -0500'), DateTime.utc(2026, 11, 4, 15));
      expect(parseFeedDate('Wed, 04 Nov 2026 10:00 EST'), DateTime.utc(2026, 11, 4, 15));
    });

    test('ISO 8601 tarihlerini okur', () {
      expect(parseFeedDate('2026-11-04T10:00:00+03:00'), DateTime.utc(2026, 11, 4, 7));
      expect(parseFeedDate('2026-11-04T10:00:00Z'), DateTime.utc(2026, 11, 4, 10));
    });

    test('çözülemeyen değerde null döner', () {
      expect(parseFeedDate(null), isNull);
      expect(parseFeedDate(''), isNull);
      expect(parseFeedDate('garbage'), isNull);
    });
  });

  group('plainText', () {
    test('etiketleri siler, varlıkları çözer, boşlukları sadeleştirir', () {
      expect(
        plainText('<p>A &amp; B</p><script>x()</script><p>C&nbsp;D &#8217;s &#x2019;</p>'),
        'A & B C D ’s ’',
      );
    });

    test('&amp;lt; gibi çift kodlanmış metni tek kat çözer', () {
      expect(plainText('1 &amp;lt; 2'), '1 &lt; 2');
    });
  });

  group('mergeNews', () {
    NewsItem item(String url, {DateTime? at, String source = 'x'}) => NewsItem(
          title: url, summary: '', url: url, sourceId: source, sourceName: source, publishedAt: at,
        );

    test('aynı bağlantıyı tek kez alır', () {
      final merged = mergeNews([
        [item('https://e.com/1', at: DateTime.utc(2026, 1, 1))],
        [item('https://e.com/1', at: DateTime.utc(2026, 1, 1)), item('https://e.com/2', at: DateTime.utc(2026, 1, 2))],
      ]);
      expect(merged.map((i) => i.url), ['https://e.com/2', 'https://e.com/1']);
    });

    test('tarihliler yeniden eskiye; tarihsizler akış sırasıyla sonda', () {
      final merged = mergeNews([
        [item('u1'), item('u2')],
        [item('d-old', at: DateTime.utc(2026, 1, 1)), item('d-new', at: DateTime.utc(2026, 1, 5))],
      ]);
      expect(merged.map((i) => i.url), ['d-new', 'd-old', 'u1', 'u2']);
    });

    test('NewsItem JSON gidiş-dönüşünde veri kaybetmez', () {
      final original = item('https://e.com/1', at: DateTime.utc(2026, 1, 1, 12));
      final copy = NewsItem.fromJson(original.toJson());
      expect(copy.url, original.url);
      expect(copy.publishedAt, original.publishedAt);
      expect(copy.sourceName, original.sourceName);
    });
  });

  test('yapılandırılmış Türkçe kaynaklar https ve benzersiz kimliklidir', () {
    expect(newsSources.map((s) => s.id).toSet(), hasLength(newsSources.length));
    expect(newsSources.every((s) => s.url.startsWith('https://')), isTrue);
    expect(newsSources.map((s) => s.name), ['TRF1.net', 'Motorsport.com Türkiye']);
  });
}
