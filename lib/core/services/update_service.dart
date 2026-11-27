import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart';

/// GitHub'daki en son Release'i temsil eder.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, required this.notes});
  final String version;
  final String url;
  final String notes;
}

/// GitHub Releases API'sinden daha yeni bir sürüm varsa bilgisini döndürür.
/// Ağ hatası veya API değişikliğinde `null` döner; uygulama normal çalışmaya devam eder.
Future<UpdateInfo?> checkForUpdate({http.Client? client}) async {
  try {
    final response = await (client ?? http.Client()).get(
      Uri.parse(latestReleaseApiUrl),
      headers: const {'Accept': 'application/vnd.github+json', 'User-Agent': 'f1-tracker'},
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '').trim() ?? '';
    if (tag.isEmpty || !_isNewer(tag, appVersion)) return null;
    return UpdateInfo(
      version: tag,
      url: (data['html_url'] as String?) ?? releasesPageUrl,
      notes: (data['body'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  }
}

/// `1.10.0` > `1.9.0` gibi sayısal sürüm karşılaştırması yapar.
bool _isNewer(String candidate, String current) {
  List<int> parts(String value) => value
      .split(RegExp(r'[.+-]'))
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final a = parts(candidate);
  final b = parts(current);
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av > bv) return true;
    if (av < bv) return false;
  }
  return false;
}
