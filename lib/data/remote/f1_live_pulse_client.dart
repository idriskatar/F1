import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/models/live_timing_model.dart';

class RapidApiKeyStore {
  RapidApiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'rapidapi_f1_live_pulse_key';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _keyName);
  Future<void> save(String key) => _storage.write(key: _keyName, value: key.trim());
  Future<void> delete() => _storage.delete(key: _keyName);
}

class F1LivePulseClient {
  F1LivePulseClient({http.Client? client}) : _client = client ?? http.Client();

  static const _url = 'https://f1-live-pulse.p.rapidapi.com/timingData';
  static const _host = 'f1-live-pulse.p.rapidapi.com';
  final http.Client _client;

  Future<List<LiveTimingDriver>> fetchTimingData(String apiKey) async {
    final response = await _client.get(
      Uri.parse(_url),
      headers: {
        'X-RapidAPI-Key': apiKey,
        'X-RapidAPI-Host': _host,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const F1LivePulseException('API anahtarı geçersiz veya RapidAPI aboneliği etkin değil.');
    }
    if (response.statusCode == 429) {
      throw const F1LivePulseException('Ücretsiz planın istek sınırına ulaşıldı. Bir süre sonra tekrar dene.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw F1LivePulseException('F1 Live Pulse HTTP ${response.statusCode} yanıtı verdi.');
    }

    final decoded = jsonDecode(response.body);
    final rows = _driverRows(decoded);
    if (rows == null) {
      throw const F1LivePulseException('F1 Live Pulse yanıtında sürücü listesi bulunamadı.');
    }
    final drivers = rows
        .whereType<Map<String, dynamic>>()
        .map(LiveTimingDriver.fromJson)
        .toList()
      ..sort((a, b) {
        if (a.position == 0) return 1;
        if (b.position == 0) return -1;
        return a.position.compareTo(b.position);
      });
    return drivers;
  }

  void close() => _client.close();
}

List<Object?>? _driverRows(Object? value) {
  if (value is List) return value.cast<Object?>();
  if (value is! Map<String, dynamic>) return null;
  final direct = value['drivers'] ?? value['Drivers'];
  if (direct is List) return direct.cast<Object?>();
  final data = value['data'] ?? value['Data'];
  if (data is List) return data.cast<Object?>();
  if (data is Map<String, dynamic>) {
    final nested = data['drivers'] ?? data['Drivers'];
    if (nested is List) return nested.cast<Object?>();
  }
  return null;
}

class F1LivePulseException implements Exception {
  const F1LivePulseException(this.message);
  final String message;
  @override
  String toString() => message;
}
