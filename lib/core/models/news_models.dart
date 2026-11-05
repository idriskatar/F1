import 'package:xml/xml.dart';

/// Haber kaynağı (RSS/Atom akışı).
class NewsSource {
  const NewsSource({required this.id, required this.name, required this.url});
  final String id;
  final String name;
  final String url;
}

/// Uygulamanın kullandığı Türkçe, herkese açık RSS akışları.
const newsSources = <NewsSource>[
  NewsSource(id: 'trf1', name: 'TRF1.net', url: 'https://trf1.net/feed/'),
  NewsSource(id: 'motorsport_tr', name: 'Motorsport.com Türkiye', url: 'https://tr.motorsport.com/rss/f1/news/'),
];

/// Tek bir haber: yalnızca başlık, kısa özet ve kaynağa bağlantı tutulur.
class NewsItem {
  const NewsItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.sourceId,
    required this.sourceName,
    this.publishedAt,
  });

  final String title;
  final String summary;
  final String url;
  final String sourceId;
  final String sourceName;

  /// UTC yayın zamanı; akış tarih vermiyorsa null.
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'url': url,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: '${json['title'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        url: '${json['url'] ?? ''}',
        sourceId: '${json['sourceId'] ?? ''}',
        sourceName: '${json['sourceName'] ?? ''}',
        publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}')?.toUtc(),
      );
}

class NewsFeedException implements Exception {
  const NewsFeedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// RSS 2.0, RSS 1.0 (RDF) ve Atom akışlarını [NewsItem] listesine çevirir.
///
/// Başlığı ya da http(s) bağlantısı olmayan öğeler atlanır. Akış değilse
/// (örn. 200 dönen bir HTML hata sayfası) [NewsFeedException] fırlatır.
List<NewsItem> parseFeed(String body, NewsSource source, {int limit = 25}) {
  final XmlDocument document;
  try {
    // BOM ve baştaki boşluk, XML bildiriminden önce gelirse ayrıştırıcıyı bozar.
    document = XmlDocument.parse(body.replaceFirst(RegExp('^\uFEFF'), '').trim());
  } on XmlException {
    throw const NewsFeedException('Yanıt geçerli bir RSS akışı değil.');
  }
  final root = document.rootElement.name.local.toLowerCase();
  if (root != 'rss' && root != 'rdf' && root != 'feed') {
    throw const NewsFeedException('Yanıt geçerli bir RSS akışı değil.');
  }

  final items = <NewsItem>[];
  final nodes = root == 'feed' ? document.findAllElements('entry') : document.findAllElements('item');
  for (final node in nodes) {
    final title = plainText(_childText(node, 'title'));
    final url = root == 'feed' ? _atomLink(node) : _rssLink(node);
    if (title.isEmpty || url == null) continue;

    final rawSummary = root == 'feed'
        ? (_childText(node, 'summary').isNotEmpty ? _childText(node, 'summary') : _childText(node, 'content'))
        : _childText(node, 'description');
    final rawDate = root == 'feed'
        ? (_childText(node, 'published').isNotEmpty ? _childText(node, 'published') : _childText(node, 'updated'))
        : (_childText(node, 'pubDate').isNotEmpty ? _childText(node, 'pubDate') : _childText(node, 'dc:date'));

    items.add(NewsItem(
      title: title,
      summary: _shorten(_stripReadMore(plainText(rawSummary)), 220),
      url: url,
      sourceId: source.id,
      sourceName: source.name,
      publishedAt: parseFeedDate(rawDate),
    ));
    if (items.length >= limit) break;
  }
  return items;
}

String _childText(XmlElement node, String name) => node.getElement(name)?.innerText.trim() ?? '';

String? _rssLink(XmlElement node) {
  var link = _childText(node, 'link');
  if (link.isEmpty) {
    final guid = node.getElement('guid');
    if (guid != null && guid.getAttribute('isPermaLink') != 'false') link = guid.innerText.trim();
  }
  return _safeUrl(link);
}

String? _atomLink(XmlElement node) {
  String? fallback;
  for (final link in node.findElements('link')) {
    final href = link.getAttribute('href');
    if (href == null) continue;
    final rel = link.getAttribute('rel');
    if (rel == null || rel == 'alternate') return _safeUrl(href);
    fallback ??= href;
  }
  return _safeUrl(fallback ?? '');
}

/// Yalnızca http/https bağlantılarını kabul eder.
String? _safeUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri.toString();
}

String _stripReadMore(String text) =>
    text.replaceAll(RegExp(r'\s*(Keep reading|Read more|Devamını oku)\s*$', caseSensitive: false), '').trim();

String _shorten(String text, int max) {
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > max * 0.6 ? cut.substring(0, space) : cut).trimRight()}…';
}

/// HTML parçasını düz metne çevirir (etiketleri siler, yaygın varlıkları çözer).
String plainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ')
      .replaceAll(RegExp(r'<\s*br\s*/?>|</\s*(p|div|li|h\d)\s*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  const named = {
    '&nbsp;': ' ', '&quot;': '"', '&apos;': "'", '&#39;': "'", '&lt;': '<', '&gt;': '>',
    '&hellip;': '…', '&rsquo;': '’', '&lsquo;': '‘', '&rdquo;': '”', '&ldquo;': '“',
    '&ndash;': '–', '&mdash;': '—',
  };
  named.forEach((entity, value) => text = text.replaceAll(entity, value));
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => _codePoint(int.tryParse(m[1]!)) ?? m[0]!);
  text = text.replaceAllMapped(RegExp(r'&#[xX]([0-9a-fA-F]+);'), (m) => _codePoint(int.tryParse(m[1]!, radix: 16)) ?? m[0]!);
  // `&amp;` en son çözülür; böylece "&amp;lt;" yanlışlıkla "<" olmaz.
  text = text.replaceAll('&amp;', '&');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _codePoint(int? value) =>
    value == null || value <= 0 || value > 0x10FFFF ? null : String.fromCharCode(value);

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _zoneHours = {
  'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5, 'MST': -7, 'MDT': -6, 'PST': -8, 'PDT': -7,
};

/// RFC 822 (RSS) ve ISO 8601 (Atom) tarihlerini UTC'ye çevirir; çözemezse null.
DateTime? parseFeedDate(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso.toUtc();

  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]+|[+-]\d{4})?',
  ).firstMatch(text);
  if (match == null) return null;
  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(match.group(3)!);
  if (year < 100) year += year < 50 ? 2000 : 1900;

  var offset = Duration.zero;
  final zone = match.group(7);
  if (zone != null) {
    if (RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
      final sign = zone.startsWith('-') ? -1 : 1;
      offset = Duration(hours: sign * int.parse(zone.substring(1, 3)), minutes: sign * int.parse(zone.substring(3, 5)));
    } else {
      offset = Duration(hours: _zoneHours[zone.toUpperCase()] ?? 0);
    }
  }
  return DateTime.utc(
    year, month, int.parse(match.group(1)!), int.parse(match.group(4)!), int.parse(match.group(5)!),
    int.tryParse(match.group(6) ?? '') ?? 0,
  ).subtract(offset);
}

/// Birden çok kaynağın haberlerini birleştirir: aynı bağlantıyı tek kez alır,
/// tarihlileri yeniden eskiye sıralar, tarihsizleri akış sırasıyla sona koyar.
List<NewsItem> mergeNews(Iterable<List<NewsItem>> feeds) {
  final seen = <String>{};
  final indexed = <(int, NewsItem)>[];
  var index = 0;
  for (final feed in feeds) {
    for (final item in feed) {
      if (seen.add(item.url)) indexed.add((index++, item));
    }
  }
  indexed.sort((a, b) {
    final da = a.$2.publishedAt;
    final db = b.$2.publishedAt;
    if (da != null && db != null) {
      final byDate = db.compareTo(da);
      if (byDate != 0) return byDate;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
