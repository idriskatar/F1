import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/news_models.dart';
import '../local/local_store.dart';

/// Tüm kaynakların birleşik sonucu.
class NewsFeedResult {
  const NewsFeedResult({
    required this.items,
    required this.errors,
    required this.cachedSources,
    required this.updatedAt,
  });

  /// Birleştirilmiş, tarihe göre sıralı haberler.
  final List<NewsItem> items;

  /// Güncellenemeyen kaynaklar: kaynak kimliği → hata mesajı.
  final Map<String, String> errors;

  /// Haberleri önbellekten gelen kaynakların kimlikleri.
  final Set<String> cachedSources;
  final DateTime updatedAt;
}

class NewsRepository {
  NewsRepository({
    http.Client? client,
    LocalStore? store,
    List<NewsSource>? sources,
    Duration freshFor = const Duration(minutes: 2),
  })  : _client = client ?? http.Client(),
        _store = store ?? LocalStore(),
        sources = sources ?? newsSources,
        _freshFor = freshFor;

  final http.Client _client;
  final LocalStore _store;
  final List<NewsSource> sources;
  final Duration _freshFor;

  Future<NewsFeedResult>? _inFlight;
  NewsFeedResult? _last;
  DateTime? _fetchedAt;

  /// Tüm kaynakları çeker. Ana sayfa ve Haberler sekmesi aynı anda çağırsa da
  /// tek istek yapılır; [force] true ise önbelleğe/süreye bakılmaz.
  Future<NewsFeedResult> fetchAll({bool force = false}) async {
    if (!force) {
      final pending = _inFlight;
      if (pending != null) return pending;
      final last = _last;
      final at = _fetchedAt;
      if (last != null && at != null && DateTime.now().difference(at) < _freshFor) return last;
    }
    final future = _fetch();
    _inFlight = future;
    try {
      final result = await future;
      _last = result;
      _fetchedAt = DateTime.now();
      return result;
    } finally {
      _inFlight = null;
    }
  }

  Future<NewsFeedResult> _fetch() async {
    final results = await Future.wait(sources.map(_fetchSource));
    return NewsFeedResult(
      items: mergeNews(results.map((r) => r.items)),
      errors: {for (final r in results) if (r.error != null) r.source.id: r.error!},
      cachedSources: {for (final r in results) if (r.cached) r.source.id},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<_SourceResult> _fetchSource(NewsSource source) async {
    String message;
    try {
      final response = await _client.get(Uri.parse(source.url), headers: const {
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.5',
        // HTTP header values must stay ASCII on all supported mobile clients.
        'User-Agent': 'F1Tracker/0.1',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw NewsFeedException('Sunucu HTTP ${response.statusCode} yanıtı verdi.');
      }
      // Karakter kümesi başlığı eksik olsa da Türkçe/özel karakterler bozulmasın.
      final items = parseFeed(utf8.decode(response.bodyBytes, allowMalformed: true), source);
      try {
        await _store.saveJson('news-${source.id}', jsonEncode({
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'items': [for (final item in items) item.toJson()],
        }));
      } catch (_) {
        // Yerel depo sorunu geçerli canlı yanıtı atmamalı.
      }
      return _SourceResult(source, items, cached: false);
    } on NewsFeedException catch (error) {
      message = error.message;
    } on http.ClientException catch (error) {
      message = 'Bağlanılamadı: ${error.message}';
    } catch (_) {
      message = 'Akış alınamadı.';
    }

    final cached = await _readCache(source);
    return _SourceResult(source, cached ?? const [], cached: cached != null, error: message);
  }

  Future<List<NewsItem>?> _readCache(NewsSource source) async {
    try {
      final raw = await _store.readJson('news-${source.id}');
      if (raw == null) return null;
      final entry = jsonDecode(raw);
      if (entry is! Map<String, dynamic>) return null;
      final list = entry['items'];
      if (list is! List) return null;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) NewsItem.fromJson(item),
      ];
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}

class _SourceResult {
  const _SourceResult(this.source, this.items, {required this.cached, this.error});
  final NewsSource source;
  final List<NewsItem> items;
  final bool cached;
  final String? error;
}
