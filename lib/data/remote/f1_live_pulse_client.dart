import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/live_timing_model.dart';

class F1LivePulseClient {
  F1LivePulseClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<LiveTimingDriver>> fetch(String apiKey) async {
    final response = await _client
        .get(
          Uri.parse('https://f1-live-pulse.p.rapidapi.com/timingData'),
          headers: {
            'X-RapidAPI-Key': apiKey,
            'X-RapidAPI-Host': 'f1-live-pulse.p.rapidapi.com',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const F1LivePulseException(
        'RapidAPI anahtarı geçersiz olabilir veya F1 Live Pulse ücretsiz planı etkin değildir.',
      );
    }
    if (response.statusCode == 429) {
      throw const F1LivePulseException('Ücretsiz planın istek sınırına ulaşıldı. Daha sonra tekrar dene.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw F1LivePulseException('F1 Live Pulse HTTP ${response.statusCode} yanıtı verdi.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const F1LivePulseException('F1 Live Pulse geçerli JSON döndürmedi.');
    }
    final rows = _findDriverRows(decoded);
    if (rows == null) {
      final keys = decoded is Map ? decoded.keys.take(8).join(', ') : decoded.runtimeType;
      throw F1LivePulseException('Canlı API yanıtı tanınmadı (üst alanlar: $keys).');
    }

    final drivers = rows
        .whereType<Map<String, dynamic>>()
        .map(LiveTimingDriver.fromJson)
        .where((driver) => driver.name != 'Unknown driver' || driver.number != '—')
        .toList()
      ..sort((a, b) {
        if (a.position == 0) return 1;
        if (b.position == 0) return -1;
        return a.position.compareTo(b.position);
      });
    if (drivers.isEmpty && rows.isNotEmpty) {
      throw const F1LivePulseException('Canlı API sürücü verisi döndürdü ancak alanları tanınmadı.');
    }
    return drivers;
  }

  void close() => _client.close();

  List<Object?>? _findDriverRows(Object? value, [int depth = 0]) {
    if (depth > 7) return null;
    if (value is List) {
      if (value.isEmpty) return value.cast<Object?>();
      if (value.any((item) => item is Map)) return value.cast<Object?>();
      for (final item in value) {
        final nested = _findDriverRows(item, depth + 1);
        if (nested != null) return nested;
      }
      return null;
    }
    if (value is! Map) return null;

    final fieldNames = value.keys.map((key) => key.toString().toLowerCase()).toSet();
    if (fieldNames.any(const {'racingnumber', 'drivernumber', 'position', 'lastlaptime', 'bestlaptime'}.contains)) {
      return [value];
    }

    const preferred = {
      'drivers', 'timingdata', 'timing', 'lines', 'positions', 'results', 'data', 'entries',
    };
    for (final entry in value.entries) {
      if (preferred.contains(entry.key.toString().toLowerCase())) {
        final nested = _findDriverRows(entry.value, depth + 1);
        if (nested != null) return nested;
      }
    }

    // Some live timing feeds index their driver objects by racing number.
    final mappedRows = <Object?>[];
    for (final entry in value.entries) {
      if (int.tryParse(entry.key.toString()) != null && entry.value is Map<String, dynamic>) {
        mappedRows.add({...(entry.value as Map<String, dynamic>), 'racingNumber': entry.key.toString()});
      }
    }
    if (mappedRows.isNotEmpty) return mappedRows;

    for (final entry in value.entries) {
      if (entry.value is Map || entry.value is List) {
        final nested = _findDriverRows(entry.value, depth + 1);
        if (nested != null) return nested;
      }
    }

    return null;
  }
}

class F1LivePulseException implements Exception {
  const F1LivePulseException(this.message);
  final String message;
  @override
  String toString() => message;
}
