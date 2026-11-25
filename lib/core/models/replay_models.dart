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

/// Pist hava ölçümü: [time] saniyesinden itibaren geçerli. Bilinmeyen alanlar null.
class ReplayWeather {
  const ReplayWeather({
    required this.time,
    this.air,
    this.track,
    this.humidity,
    this.wind,
    this.windDirection,
    this.raining,
  });

  final double time;

  /// Hava ve pist sıcaklığı (°C).
  final double? air;
  final double? track;

  /// Bağıl nem (%).
  final int? humidity;

  /// Rüzgâr hızı (km/sa) ve yönü (derece).
  final double? wind;
  final int? windDirection;

  /// Yağış var mı? Bilinmiyorsa null.
  final bool? raining;
}

/// Sıra değişimi: [time] saniyesinden itibaren [position]. sıra.
class ReplayPositionEvent {
  const ReplayPositionEvent(this.time, this.position);

  final double time;
  final int position;
}

/// Bir pilotun tek turu. Süreler saniye; bilinmeyenler null (ör. 1. turun 1. sektörü).
class ReplayLap {
  const ReplayLap({required this.number, this.start, this.duration, this.s1, this.s2, this.s3});

  final int number;

  /// Replay saniyesi cinsinden tur başlangıcı.
  final double? start;
  final double? duration;
  final double? s1;
  final double? s2;
  final double? s3;

  double? get end {
    final begin = start;
    final length = duration;
    return begin != null && length != null ? begin + length : null;
  }

  /// [index]: 0 = S1, 1 = S2, 2 = S3.
  double? sector(int index) => switch (index) {
        0 => s1,
        1 => s2,
        _ => s3,
      };
}

class ReplayStint {
  const ReplayStint({required this.compound, required this.lapStart, this.lapEnd, this.ageAtStart = 0});

  /// SOFT, MEDIUM, HARD, INTERMEDIATE, WET ya da UNKNOWN.
  final String compound;
  final int lapStart;

  /// Son stint için null olabilir.
  final int? lapEnd;
  final int ageAtStart;

  String get letter => switch (compound) {
        'SOFT' => 'S',
        'MEDIUM' => 'M',
        'HARD' => 'H',
        'INTERMEDIATE' => 'I',
        'WET' => 'W',
        _ => '?',
      };

  bool containsLap(int lap) {
    final end = lapEnd;
    return lap >= lapStart && (end == null || lap <= end);
  }

  /// [lap] turundaki lastik yaşı (tur sayısı).
  int ageAt(int lap) => ageAtStart + (lap - lapStart);
}

enum SectorStatus { unknown, upcoming, active, overallBest, personalBest, slower }

/// Belirli bir ana kadar (o an dahil) tamamlanan sektör/tur en iyileri.
class ReplayBests {
  const ReplayBests({required this.sectors, required this.personalSectors, this.lap, this.personalLap});

  /// Tüm pilotların en iyi S1/S2/S3 süresi.
  final List<double?> sectors;

  /// Seçili pilotun en iyi S1/S2/S3 süresi.
  final List<double?> personalSectors;
  final double? lap;
  final double? personalLap;

  static const _epsilon = 0.0005;

  SectorStatus classifySector(int index, double value) => _classify(value, sectors[index], personalSectors[index]);

  SectorStatus classifyLap(double value) => _classify(value, lap, personalLap);

  static SectorStatus _classify(double value, double? overall, double? personal) {
    if (overall != null && value <= overall + _epsilon) return SectorStatus.overallBest;
    if (personal != null && value <= personal + _epsilon) return SectorStatus.personalBest;
    return SectorStatus.slower;
  }
}

/// 72.5 -> "1:12.500"
String formatLapTime(double seconds) {
  final totalMs = (seconds * 1000).round();
  final minutes = totalMs ~/ 60000;
  final rest = (totalMs % 60000) / 1000;
  return '$minutes:${rest.toStringAsFixed(3).padLeft(6, '0')}';
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
    this.lastName = '',
    this.rpm,
    this.positionLog = const [],
    this.laps = const [],
    this.stints = const [],
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

  /// Soyad (OpenF1 `last_name`); yoksa boş.
  final String lastName;
  final List<int?>? rpm;

  /// Yarış boyunca sıra değişimleri (zamana göre artan). Eski dosyalarda boş.
  final List<ReplayPositionEvent> positionLog;
  final List<ReplayLap> laps;
  final List<ReplayStint> stints;

  /// Kartta büyük yazılacak ad: soyad, yoksa tam adın son sözcüğü, o da yoksa kod.
  String get surname {
    if (lastName.isNotEmpty) return lastName;
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.last.isEmpty ? code : parts.last;
  }

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

  double? rpmAt(double t, double hz) => _lerpAt(rpm, t, hz);

  /// [t] anındaki sıra; sıra geçmişi yoksa ya da pilot henüz sıralanmadıysa null.
  int? rankAt(double t) {
    final log = positionLog;
    if (log.isEmpty || t < log.first.time) return null;
    var low = 0;
    var high = log.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (log[mid].time <= t) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return log[low].position;
  }

  /// [t] anında süren tur (başlangıcı bilinen son tur).
  ReplayLap? currentLapAt(double t) {
    ReplayLap? current;
    for (final lap in laps) {
      final begin = lap.start;
      if (begin == null) continue;
      if (begin > t) break;
      current = lap;
    }
    return current;
  }

  /// [t] anına kadar tamamlanan son tur.
  ReplayLap? lastCompletedLapAt(double t) {
    ReplayLap? last;
    for (final lap in laps) {
      final finish = lap.end;
      if (finish != null && finish <= t && (last == null || lap.number > last.number)) last = lap;
    }
    return last;
  }

  ReplayStint? stintAtLap(int lap) {
    for (final stint in stints) {
      if (stint.containsLap(lap)) return stint;
    }
    return null;
  }

  /// [t] anında takılı lastik. Tur bilgisi henüz yoksa (yarışın ilk anları) 1. tur kabul edilir.
  ReplayStint? stintAt(double t) {
    if (stints.isEmpty) return null;
    final lap = currentLapAt(t)?.number ?? lastCompletedLapAt(t)?.number ?? 1;
    return stintAtLap(lap);
  }

  /// [fromT, toT] aralığındaki hız örnekleri (grafik için). Veri olmayan yerler null.
  List<double?> speedSeries(double fromT, double toT, double hz) {
    final data = speed;
    if (data == null || data.isEmpty) return const [];
    final start = math.max(0, (fromT * hz).ceil());
    final end = math.min(data.length - 1, (toT * hz).floor());
    return [for (var i = start; i <= end; i++) data[i]?.toDouble()];
  }
}

enum ReplayEventKind { safetyCar, virtualSafetyCar, redFlag, penalty }

/// Yarış yönetimi olayı. Safety car, VSC ve kırmızı bayrak [end] ile biten bir dönemdir;
/// ceza tek bir andır ([end] null).
class ReplayEvent {
  const ReplayEvent({required this.time, required this.kind, this.lap, this.message = '', this.end});

  final double time;
  final ReplayEventKind kind;
  final int? lap;

  /// Yarış yönetiminin özgün (İngilizce) mesajı.
  final String message;
  final double? end;

  /// Zaman çubuğunda bant olarak çizilen, süresi olan olay.
  bool get isPeriod => end != null && kind != ReplayEventKind.penalty;

  bool containsTime(double t) {
    final finish = end;
    return isPeriod && finish != null && t >= time && t < finish;
  }

  String get label => switch (kind) {
        ReplayEventKind.safetyCar => 'Safety Car',
        ReplayEventKind.virtualSafetyCar => 'Sanal Safety Car',
        ReplayEventKind.redFlag => 'Kırmızı bayrak',
        ReplayEventKind.penalty => 'Ceza',
      };

  /// Yarış başlığındaki rozet için kısa ad.
  String get badge => switch (kind) {
        ReplayEventKind.safetyCar => 'SC',
        ReplayEventKind.virtualSafetyCar => 'VSC',
        ReplayEventKind.redFlag => 'KIRMIZI BAYRAK',
        ReplayEventKind.penalty => 'CEZA',
      };
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
    this.weather = const [],
    this.events = const [],
  })  : pitsByDriver = _groupPits(pits),
        periods = [
          for (final event in events)
            if (event.isPeriod) event,
        ],
        hasLivePositions = drivers.any((d) => d.positionLog.isNotEmpty),
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

  /// Pist hava ölçümleri (zamana göre artan). Eski dosyalarda boş.
  final List<ReplayWeather> weather;

  /// Yarış yönetimi olayları (zamana göre artan). Eski dosyalarda boş.
  final List<ReplayEvent> events;

  /// [events] içinden süresi olanlar (safety car, VSC, kırmızı bayrak).
  final List<ReplayEvent> periods;
  final Map<String, List<ReplayPit>> pitsByDriver;

  /// Dosyada sıra geçmişi varsa true; yoksa sıralama listesi bitiş sırasını gösterir.
  final bool hasLivePositions;
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

  /// [lap] turunun başladığı an (sn); tur bilinmiyorsa null.
  double? lapStartTime(int lap) => lap >= 1 && lap <= lapStarts.length ? lapStarts[lap - 1] : null;

  /// Geri/ileri tur atlama hedefi. Geri giderken tur başından 3 sn'den fazla geçtiyse
  /// önce o turun başına döner; ileri giderken son turdan sonra yarış sonuna gider.
  double lapJumpTarget(double t, {required bool forward}) {
    if (lapStarts.isEmpty) return forward ? duration : 0.0;
    final current = lapAt(t);
    if (forward) {
      return lapStartTime(current + 1) ?? duration;
    }
    final begin = lapStartTime(current) ?? 0.0;
    if (t - begin > 3.0 || current <= 1) return begin;
    return lapStartTime(current - 1) ?? 0.0;
  }

  /// [t] anında süren safety car / VSC / kırmızı bayrak dönemi; yoksa null.
  ReplayEvent? periodAt(double t) {
    for (final period in periods) {
      if (period.containsTime(t)) return period;
    }
    return null;
  }

  bool inPit(String code, double t) {
    final list = pitsByDriver[code];
    if (list == null) return false;
    for (final pit in list) {
      if (pit.containsTime(t)) return true;
    }
    return false;
  }


  /// [t] anında geçerli hava ölçümü (t ilk ölçümden önceyse ilk ölçüm); ölçüm yoksa null.
  ReplayWeather? weatherAt(double t) {
    if (weather.isEmpty) return null;
    var low = 0;
    var high = weather.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (weather[mid].time <= t) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return weather[low];
  }

  /// [t] anına kadar tamamlanan en hızlı turun sahibi (eşitlikte turu önce bitiren); tur yoksa null.
  String? fastestLapHolderAt(double t) {
    String? holder;
    var best = double.infinity;
    var bestEnd = double.infinity;
    for (final d in drivers) {
      for (final lap in d.laps) {
        final finish = lap.end;
        final length = lap.duration;
        if (finish == null || length == null || finish > t) continue;
        final faster = length < best - 0.0005;
        final tiedButEarlier = (length - best).abs() <= 0.0005 && finish < bestEnd;
        if (faster || tiedButEarlier) {
          best = length;
          bestEnd = finish;
          holder = d.code;
        }
      }
    }
    return holder;
  }

  /// [t] anındaki sıralama. Sıra geçmişi yoksa bitiş sırası (dosyadaki pilot sırası) döner.
  List<ReplayDriver> orderAt(double t) {
    final list = List<ReplayDriver>.of(drivers);
    if (!hasLivePositions) return list;
    list.sort((a, b) {
      final ra = a.rankAt(t);
      final rb = b.rankAt(t);
      if (ra != null && rb != null && ra != rb) return ra.compareTo(rb);
      if (ra == null && rb != null) return 1;
      if (ra != null && rb == null) return -1;
      final byResult = (a.position ?? 999).compareTo(b.position ?? 999);
      return byResult != 0 ? byResult : a.code.compareTo(b.code);
    });
    return list;
  }

  /// [t] anına (dahil) kadar tamamlanan sektör ve tur en iyileri.
  ReplayBests bestsAt(double t, ReplayDriver driver) {
    final overall = <double?>[null, null, null];
    final personal = <double?>[null, null, null];
    double? overallLap;
    double? personalLap;
    for (final d in drivers) {
      final mine = d.code == driver.code;
      for (final lap in d.laps) {
        final begin = lap.start;
        if (begin == null || begin > t) continue;
        var cumulative = 0.0;
        for (var i = 0; i < 3; i++) {
          final value = lap.sector(i);
          if (value == null) break; // sonraki sektörlerin bitiş anı hesaplanamaz
          cumulative += value;
          if (begin + cumulative > t) break;
          overall[i] = _smaller(overall[i], value);
          if (mine) personal[i] = _smaller(personal[i], value);
        }
        final finish = lap.end;
        final length = lap.duration;
        if (finish != null && length != null && finish <= t) {
          overallLap = _smaller(overallLap, length);
          if (mine) personalLap = _smaller(personalLap, length);
        }
      }
    }
    return ReplayBests(sectors: overall, personalSectors: personal, lap: overallLap, personalLap: personalLap);
  }

  /// [driver]ın süren turunda S1/S2/S3 durumları. Süre bilgisi eksik sektörler `unknown` olur.
  List<SectorStatus> sectorStatesAt(ReplayDriver driver, double t) {
    final lap = driver.currentLapAt(t);
    final begin = lap?.start;
    if (lap == null || begin == null) {
      return const [SectorStatus.unknown, SectorStatus.unknown, SectorStatus.unknown];
    }
    final bests = bestsAt(t, driver);
    final elapsed = t - begin;
    final states = <SectorStatus>[];
    var cumulative = 0.0;
    var known = true;
    var activeAssigned = false;
    for (var i = 0; i < 3; i++) {
      final value = lap.sector(i);
      if (value == null || !known) {
        known = false;
        states.add(SectorStatus.unknown);
        continue;
      }
      cumulative += value;
      if (elapsed >= cumulative) {
        states.add(bests.classifySector(i, value));
      } else if (!activeAssigned) {
        states.add(SectorStatus.active);
        activeAssigned = true;
      } else {
        states.add(SectorStatus.upcoming);
      }
    }
    return states;
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
      weather: _parseRows(json['weather'], _weatherFromJson)..sort((a, b) => a.time.compareTo(b.time)),
      events: _parseRows(json['events'], _replayEventFromJson)..sort((a, b) => a.time.compareTo(b.time)),
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
      lastName: _string(json['lastName']),
      rpm: _optionalIntList(json['rpm']),
      positionLog: _parseRows(json['positionLog'], _eventFromJson),
      laps: _parseRows(json['laps'], _lapFromJson),
      stints: _parseRows(json['stints'], _stintFromJson),
    );

ReplayWeather? _weatherFromJson(Object? row) {
  if (row is! List || row.length < 2) return null;
  final time = row[0];
  if (time is! num) return null;
  double? at(int i) {
    if (i >= row.length) return null;
    final value = row[i];
    return value is num ? value.toDouble() : null;
  }

  final rain = at(6);
  return ReplayWeather(
    time: time.toDouble(),
    air: at(1),
    track: at(2),
    humidity: at(3)?.round(),
    wind: at(4),
    windDirection: at(5)?.round(),
    raining: rain == null ? null : rain > 0,
  );
}

ReplayEvent? _replayEventFromJson(Object? row) {
  if (row is! List || row.length < 2) return null;
  final time = row[0];
  final kind = switch (row[1]) {
    'SC' => ReplayEventKind.safetyCar,
    'VSC' => ReplayEventKind.virtualSafetyCar,
    'RED' => ReplayEventKind.redFlag,
    'PENALTY' => ReplayEventKind.penalty,
    _ => null,
  };
  if (time is! num || kind == null) return null;
  final lap = row.length > 2 ? row[2] : null;
  final message = row.length > 3 ? row[3] : null;
  final end = row.length > 4 ? row[4] : null;
  return ReplayEvent(
    time: time.toDouble(),
    kind: kind,
    lap: lap is num ? lap.round() : null,
    message: message is String ? message : '',
    end: end is num ? end.toDouble() : null,
  );
}

ReplayPositionEvent? _eventFromJson(Object? row) {
  if (row is! List || row.length < 2) return null;
  final time = row[0];
  final position = row[1];
  if (time is! num || position is! num) return null;
  return ReplayPositionEvent(time.toDouble(), position.round());
}

ReplayLap? _lapFromJson(Object? row) {
  if (row is! List || row.length < 6) return null;
  final number = row[0];
  if (number is! num) return null;
  double? at(int i) {
    final value = row[i];
    return value is num ? value.toDouble() : null;
  }

  return ReplayLap(number: number.round(), start: at(1), duration: at(2), s1: at(3), s2: at(4), s3: at(5));
}

ReplayStint? _stintFromJson(Object? row) {
  if (row is! List || row.length < 3) return null;
  final compound = row[0];
  final first = row[1];
  if (compound is! String || first is! num) return null;
  final last = row[2];
  final age = row.length > 3 ? row[3] : null;
  return ReplayStint(
    compound: compound.toUpperCase(),
    lapStart: first.round(),
    lapEnd: last is num ? last.round() : null,
    ageAtStart: age is num ? age.round() : 0,
  );
}

List<T> _parseRows<T>(Object? raw, T? Function(Object? row) parse) {
  if (raw is! List) return <T>[];
  final out = <T>[];
  for (final row in raw) {
    final item = parse(row);
    if (item != null) out.add(item);
  }
  return out;
}

double _smaller(double? current, double candidate) => current == null || candidate < current ? candidate : current;

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
