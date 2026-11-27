import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/models/replay_models.dart';
import '../local/app_dirs.dart';

class ReplayException implements Exception {
  const ReplayException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ham baytları (gzip ya da düz JSON) [ReplayData]'ya çevirir. `compute` ile ayrı isolate'ta çalışabilmesi için
/// üst düzey bir fonksiyondur.
ReplayData decodeReplayBytes(Uint8List bytes) {
  var data = bytes;
  if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    data = Uint8List.fromList(gzip.decode(bytes));
  }
  final decoded = jsonDecode(utf8.decode(data));
  if (decoded is! Map<String, dynamic>) throw const ReplayFormatException('Replay dosyası beklenen biçimde değil.');
  return ReplayData.fromJson(decoded);
}

/// GitHub'daki data/replay/ klasöründen (Actions'ın ürettiği) replay dosyalarını indirir.
///
/// Büyük dosyalar SQLite yerine dosya olarak saklanır: Android'de bir SQLite satırı ~2 MB'ı aşınca okunamaz.
class ReplayRepository {
  ReplayRepository({
    http.Client? client,
    String? baseUrl,
    Future<Directory> Function()? cacheDirectory,
    bool useIsolate = true,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl,
        _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
        // Adlandırılmış parametreler alt çizgiyle başlayamadığı için `this._useIsolate` yazılamaz.
        // ignore: prefer_initializing_formals
        _useIsolate = useIsolate;

  static const defaultBaseUrl = 'https://raw.githubusercontent.com/idriskatar/F1/main/data/replay';
  static const _indexFile = 'index.json';

  final http.Client _client;
  final String _baseUrl;
  final Future<Directory> Function() _cacheDirectory;
  final bool _useIsolate;

  static Future<Directory> _defaultCacheDirectory() async {
    final base = await appDataSubdirectory('replay_cache');
    return Directory(base);
  }

  Future<ReplayIndex> fetchIndex() async {
    Object? failure;
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/$_indexFile')).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw ReplayException('Replay listesi alınamadı (HTTP ${response.statusCode}).');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const ReplayFormatException('Replay listesi okunamadı.');
      final index = ReplayIndex.fromJson(decoded);
      await _writeFile(_indexFile, response.bodyBytes);
      return index;
    } catch (error) {
      failure = error;
    }

    final cached = await _readFile(_indexFile);
    if (cached != null) {
      try {
        final decoded = jsonDecode(utf8.decode(cached));
        if (decoded is Map<String, dynamic>) return ReplayIndex.fromJson(decoded, isCached: true);
      } catch (_) {
        // Bozuk yerel kopya yok sayılır; asıl hata aşağıda bildirilir.
      }
    }
    if (failure is ReplayException) throw failure;
    if (failure is ReplayFormatException) throw ReplayException(failure.message);
    throw const ReplayException('Replay listesine bağlanılamadı. İnternet bağlantısını kontrol edin.');
  }

  Future<ReplayData> fetchSession(ReplayIndexEntry entry) async {
    final fileName = '${entry.cacheName}.json.gz';
    final cached = await _readFile(fileName);
    if (cached != null) {
      try {
        return await _decode(cached);
      } catch (_) {
        // Bozuk önbellek: yeniden indirilir.
      }
    }

    final Uint8List bytes;
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/${entry.file}')).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        throw ReplayException('Replay dosyası indirilemedi (HTTP ${response.statusCode}).');
      }
      bytes = response.bodyBytes;
    } on ReplayException {
      rethrow;
    } catch (_) {
      throw const ReplayException('Replay dosyası indirilemedi. İnternet bağlantısını kontrol edin.');
    }

    final data = await _decode(bytes);
    await _writeFile(fileName, bytes);
    await _deleteStale(entry, fileName);
    return data;
  }

  Future<ReplayData> _decode(Uint8List bytes) async {
    try {
      return _useIsolate ? await compute(decodeReplayBytes, bytes) : decodeReplayBytes(bytes);
    } on ReplayFormatException catch (error) {
      throw ReplayException(error.message);
    } catch (_) {
      throw const ReplayException('Replay dosyası okunamadı.');
    }
  }

  Future<Uint8List?> _readFile(String name) async {
    try {
      final file = File(p.join((await _cacheDirectory()).path, name));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeFile(String name, List<int> bytes) async {
    try {
      final dir = await _cacheDirectory();
      await dir.create(recursive: true);
      await File(p.join(dir.path, name)).writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Önbellek yazılamıyorsa canlı veri yine de kullanılır.
    }
  }

  Future<void> _deleteStale(ReplayIndexEntry entry, String keep) async {
    try {
      final dir = await _cacheDirectory();
      final prefix = '${entry.year}-r${entry.round}-${entry.session}-';
      await for (final item in dir.list()) {
        final name = p.basename(item.path);
        if (item is File && name.startsWith(prefix) && name != keep) await item.delete();
      }
    } catch (_) {
      // Eski dosya temizliği başarısız olabilir; kritik değil.
    }
  }

  void close() => _client.close();
}
