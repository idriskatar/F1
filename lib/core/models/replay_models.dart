import 'dart:math' as math;

/// Replay dosya biçimi sürümü. tool/replay/build_replay.py içindeki SCHEMA_VERSION ile aynı olmalı.
const int replaySchemaVersion = 1;

class ReplayFormatException implements Exception {
  const ReplayFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReplayPoint {
  const ReplayPoint(this.x, this.y);
  final double x;
  final double y;
}

/// index.json içindeki tek bir hazır seans.
class ReplayIndexEntry {
  const ReplayIndexEntry({
    required this.year,
    required this.round,
    required this.session,
    required this.name,
    required this.country,
    required this.circuit,
    required this.file,
    required this.bytes,
    required this.duration,
    required this.generatedAt,
  });

  final int year;
  final int round;
  final String session;
  final String name;
  final String country;
  final String circuit;
  final String file;
  final int bytes;
  final double duration;
  final String generatedAt;

  String get sessionLabel => session == 'S' ? 'Sprint' : 'Yarış';

  /// Önbellek dosya adı: veri yeniden üretildiğinde (generatedAt değişince) otomatik yenilenir.
  String get cacheName => '$year-r$round-$session-${generatedAt.replaceAll(RegExp(r'[^0-9]'), '')}';

  factory ReplayIndexEntry.fromJson(Map<String, dynamic> json) => ReplayIndexEntry(
        year: _int(json['year'], 'year'),
        round: _int(json['round'], 'round'),
        session: _string(json['session'], 'R'),
        name: _string(json['name'], 'Yarış'),
        country: _string(json['country']),
        circuit: _string(json['circuit']),
        file: _requiredString(json['file'], 'file'),
        bytes: json['bytes'] is num ? (json['bytes'] as num).round() : 0,
        duration: json['duration'] is num ? (json['duration'] as num).toDouble() : 0.0,
        generatedAt: _string(json['generatedAt']),
      );
}

class ReplayIndex {
  const ReplayIndex(this.sessions, {this.isCached = false});

  final List<ReplayIndexEntry> sessions;

  /// Ağ yokken yerel kopyadan geldiyse true.
  final bool isCached;

  factory ReplayIndex.fromJson(Map<String, dynamic> json, {bool isCached = false}) {
    final raw = json['sessions'];
    if (raw is! List) throw const ReplayFormatException('Replay listesi okunamadı.');
    return ReplayIndex(
      [
        for (final item in raw)
          if (item is Map<String, dynamic>) ReplayIndexEntry.fromJson(item),
      ],
      isCached: isCached,
    );
  }
}

class ReplayEventInfo {
  const ReplayEventInfo({
    required this.year,
    required this.round,
    required this.session,
    required this.name,
    required this.country,
    required this.circuit,
  });

  final int year;
  final int round;
  final String session;
  final String name;
  final String country;
  final String circuit;
}

class ReplayPit {
  const ReplayPit({
    required this.driver,
    required this.lap,
    required this.inTime,
    this.outTime,
    this.pitLaneSeconds,
  });

  final String driver;
  final int lap;
  final double inTime;

  /// Çıkış bilinmiyorsa (ör. pitte yarışı bırakma) null.
  final double? outTime;

  /// Pit şeridinde geçen süre (giriş → çıkış). Lastik değişimindeki duruş süresi değildir.
  final double? pitLaneSeconds;

  bool containsTime(double t) {
    final out = outTime;
    return t >= inTime && (out == null || t <= out);
  }
}

class ReplayDriver {
  const ReplayDriver({
    required this.number,
    required this.code,
    required this.name,
    required this.team,
    required this.colorValue,
    required this.position,
    required this.x,
    required this.y,
    this.speed,
    this.gear,
    this.throttle,
    this.brake,
    this.drs,
  });

  final String number;
  final String code;
  final String name;
  final String team;

  /// 0xFFRRGGBB
  final int colorValue;
  final int? position;

  /// i. örnek = i / hz saniye. Veri yoksa null.
  final List<int?> x;
  final List<int?> y;
  final List<int?>? speed;
  final List<int?>? gear;
  final List<int?>? throttle;
  final List<int?>? brake;
  final List<int?>? drs;

  /// [t] anındaki konum; iki örnek arası doğrusal ara değer. Veri yoksa null.
  ReplayPoint? positionAt(double t, double hz) {
    final pos = t * hz;
    final i = pos.floor();
    if (i < 0 || i >= x.length || i >= y.length) return null;
    final a = x[i];
    final b = y[i];
    if (a == null || b == null) return null;
    if (i + 1 < x.length && i + 1 < y.length) {
      final a2 = x[i + 1];
      final b2 = y[i + 1];
      if (a2 != null && b2 != null) {
        final f = pos - i;
        return ReplayPoint(a + (a2 - a) * f, b + (b2 - b) * f);
      }
    }
    return ReplayPoint(a.toDouble(), b.toDouble());
  }

  double? speedAt(double t, double hz) => _lerpAt(speed, t, hz);
  double? throttleAt(double t, double hz) => _lerpAt(throttle, t, hz);
  int? gearAt(double t, double hz) => _stepAt(gear, t, hz);

  bool? brakeAt(double t, double hz) {
    final v = _stepAt(brake, t, hz);
    return v == null ? null : v > 0;
  }

  bool? drsAt(double t, double hz) {
    final v = _stepAt(drs, t, hz);
    return v == null ? null : v > 0;
  }

  bool get hasTelemetry => speed != null;

  /// [fromT, toT] aralığındaki hız örnekleri (grafik için). Veri olmayan yerler null.
  List<double?> speedSeries(double fromT, double toT, double hz) {
    final data = speed;
    if (data == null || data.isEmpty) return const [];
    final start = math.max(0, (fromT * hz).ceil());
    final end = math.min(data.length - 1, (toT * hz).floor());
    return [for (var i = start; i <= end; i++) data[i]?.toDouble()];
  }
}

class ReplayData {
  ReplayData({
    required this.event,
    required this.hz,
    required this.duration,
    required this.totalLaps,
    required this.lapStarts,
    required this.trackX,
    required this.trackY,
    required this.drivers,
    required this.pits,
  })  : pitsByDriver = _groupPits(pits),
        minX = _extent(trackX, true),
        maxX = _extent(trackX, false),
        minY = _extent(trackY, true),
        maxY = _extent(trackY, false);

  final ReplayEventInfo event;

  /// Örnekleme sıklığı (örnek/sn).
  final double hz;

  /// Replay süresi (sn); t = 0 yarışın başlangıcı.
  final double duration;
  final int totalLaps;

  /// Liderin tur başlangıçları (sn), tur sayacı için.
  final List<double> lapStarts;
  final List<double> trackX;
  final List<double> trackY;
  final List<ReplayDriver> drivers;
  final List<ReplayPit> pits;
  final Map<String, List<ReplayPit>> pitsByDriver;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  ReplayDriver? driverByCode(String? code) {
    if (code == null) return null;
    for (final driver in drivers) {
      if (driver.code == code) return driver;
    }
    return null;
  }

  int lapAt(double t) {
    if (totalLaps <= 0) return 0;
    var lap = 1;
    for (var i = 0; i < lapStarts.length; i++) {
      if (lapStarts[i] <= t) {
        lap = i + 1;
      } else {
        break;
      }
    }
    return math.min(lap, totalLaps);
  }

  bool inPit(String code, double t) {
    final list = pitsByDriver[code];
    if (list == null) return false;
    for (final pit in list) {
      if (pit.containsTime(t)) return true;
    }
    return false;
  }

  factory ReplayData.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! num || version.toInt() != replaySchemaVersion) {
      throw const ReplayFormatException('Bu replay dosyasının biçimi uygulamanın sürümüyle uyumlu değil. Uygulamayı güncelleyin.');
    }
    final hz = _double(json['hz'], 'hz');
    final duration = _double(json['duration'], 'duration');
    if (hz <= 0 || duration <= 0) throw const ReplayFormatException('Replay süresi geçersiz.');

    final ev = json['event'];
    if (ev is! Map<String, dynamic>) throw const ReplayFormatException('Replay olay bilgisi eksik.');
    final track = json['track'];
    if (track is! Map<String, dynamic>) throw const ReplayFormatException('Pist çizgisi eksik.');
    final trackXs = _intList(track['x'], 'track.x');
    final trackYs = _intList(track['y'], 'track.y');
    final n = math.min(trackXs.length, trackYs.length);
    if (n < 3) throw const ReplayFormatException('Pist çizgisi çok kısa.');

    final rawDrivers = json['drivers'];
    if (rawDrivers is! List) throw const ReplayFormatException('Pilot verisi eksik.');
    final drivers = [
      for (final item in rawDrivers)
        if (item is Map<String, dynamic>) _driverFromJson(item),
    ];
    if (drivers.isEmpty) throw const ReplayFormatException('Replay dosyasında pilot yok.');

    final rawPits = json['pits'];
    final pits = [
      if (rawPits is List)
        for (final item in rawPits)
          if (item is Map<String, dynamic>) _pitFromJson(item),
    ]..sort((a, b) => a.inTime.compareTo(b.inTime));

    final rawStarts = json['lapStarts'];
    return ReplayData(
      event: ReplayEventInfo(
        year: _int(ev['year'], 'event.year'),
        round: _int(ev['round'], 'event.round'),
        session: _string(ev['session'], 'R'),
        name: _string(ev['name'], 'Yarış'),
        country: _string(ev['country']),
        circuit: _string(ev['circuit']),
      ),
      hz: hz,
      duration: duration,
      totalLaps: json['totalLaps'] is num ? (json['totalLaps'] as num).round() : 0,
      lapStarts: [
        if (rawStarts is List)
          for (final v in rawStarts)
            if (v is num) v.toDouble(),
      ],
      trackX: [for (var i = 0; i < n; i++) trackXs[i]?.toDouble() ?? 0.0],
      trackY: [for (var i = 0; i < n; i++) trackYs[i]?.toDouble() ?? 0.0],
      drivers: drivers,
      pits: pits,
    );
  }
}

ReplayDriver _driverFromJson(Map<String, dynamic> json) => ReplayDriver(
      number: _string(json['number']),
      code: _requiredString(json['code'], 'driver.code'),
      name: _string(json['name']),
      team: _string(json['team']),
      colorValue: _parseColor(_string(json['color'])),
      position: json['position'] is num ? (json['position'] as num).round() : null,
      x: _intList(json['x'], 'driver.x'),
      y: _intList(json['y'], 'driver.y'),
      speed: _optionalIntList(json['speed']),
      gear: _optionalIntList(json['gear']),
      throttle: _optionalIntList(json['throttle']),
      brake: _optionalIntList(json['brake']),
      drs: _optionalIntList(json['drs']),
    );

ReplayPit _pitFromJson(Map<String, dynamic> json) => ReplayPit(
      driver: _requiredString(json['driver'], 'pit.driver'),
      lap: json['lap'] is num ? (json['lap'] as num).round() : 0,
      inTime: _double(json['in'], 'pit.in'),
      outTime: json['out'] is num ? (json['out'] as num).toDouble() : null,
      pitLaneSeconds: json['pitLane'] is num ? (json['pitLane'] as num).toDouble() : null,
    );

Map<String, List<ReplayPit>> _groupPits(List<ReplayPit> pits) {
  final map = <String, List<ReplayPit>>{};
  for (final pit in pits) {
    (map[pit.driver] ??= []).add(pit);
  }
  return map;
}

double _extent(List<double> values, bool min) {
  if (values.isEmpty) return min ? 0 : 1;
  var result = values.first;
  for (final v in values) {
    if (min ? v < result : v > result) result = v;
  }
  return result;
}

double? _lerpAt(List<int?>? data, double t, double hz) {
  if (data == null) return null;
  final pos = t * hz;
  final i = pos.floor();
  if (i < 0 || i >= data.length) return null;
  final a = data[i];
  if (a == null) return null;
  if (i + 1 < data.length) {
    final b = data[i + 1];
    if (b != null) return a + (b - a) * (pos - i);
  }
  return a.toDouble();
}

int? _stepAt(List<int?>? data, double t, double hz) {
  if (data == null) return null;
  final i = (t * hz).floor();
  if (i < 0 || i >= data.length) return null;
  return data[i];
}

int _parseColor(String hex) {
  final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
  return value == null ? 0xFF9AA0A6 : (0xFF000000 | value);
}

int _int(Object? value, String field) {
  if (value is num) return value.round();
  throw ReplayFormatException('Replay verisinde "$field" alanı eksik.');
}

double _double(Object? value, String field) {
  if (value is num) return value.toDouble();
  throw ReplayFormatException('Replay verisinde "$field" alanı eksik.');
}

String _string(Object? value, [String fallback = '']) => value is String && value.isNotEmpty ? value : fallback;

String _requiredString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw ReplayFormatException('Replay verisinde "$field" alanı eksik.');
}

List<int?> _intList(Object? value, String field) {
  if (value is! List) throw ReplayFormatException('Replay verisinde "$field" listesi eksik.');
  return List<int?>.generate(value.length, (i) {
    final item = value[i];
    return item is num ? item.round() : null;
  }, growable: false);
}

List<int?>? _optionalIntList(Object? value) => value is List ? _intList(value, '') : null;
