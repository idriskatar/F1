class RaceWeekend {
  const RaceWeekend({
    required this.name,
    required this.location,
    required this.country,
    required this.dateLabel,
    required this.sessions,
    required this.round,
    this.raceStart,
    this.season = 0,
    this.circuitName = '',
  });

  final String name;
  final String location;
  final String country;
  final String dateLabel;
  final int round;
  final List<RaceSession> sessions;

  /// Yarışın UTC başlangıç zamanı; API vermediyse null.
  final DateTime? raceStart;

  /// Sezon yılı ve pist adı (tur detay sorguları için); bilinmiyorsa 0 / boş.
  final int season;
  final String circuitName;

  /// Sprint seansı olan hafta sonu mu?
  bool get hasSprint => sessions.any((s) => s.name == 'Sprint');

  /// [now] anından sonra başlayacak ilk seans (seanslar zamana göre sıralıdır).
  RaceSession? nextSession(DateTime now) {
    final nowUtc = now.toUtc();
    for (final session in sessions) {
      final start = session.startUtc;
      if (start != null && start.isAfter(nowUtc)) return session;
    }
    return null;
  }

  /// Returns the currently scheduled broadcast session, excluding practice.
  /// Jolpica provides start times but no end times, so short broadcast windows
  /// are estimated from the published session type.
  RaceSession? activeBroadcastSession(DateTime now) {
    final nowUtc = now.toUtc();
    for (final session in sessions) {
      final start = session.startUtc;
      final duration = switch (session.name) {
        'Sıralama Turları' || 'Sprint Sıralaması' || 'Sprint' => const Duration(minutes: 90),
        'Yarış' => const Duration(hours: 3),
        _ => null,
      };
      if (start != null && duration != null && !nowUtc.isBefore(start) && nowUtc.isBefore(start.add(duration))) {
        return session;
      }
    }
    return null;
  }

  factory RaceWeekend.fromJson(Map<String, dynamic> json) {
    final circuit = _map(json['Circuit']);
    final location = _map(circuit['Location']);
    final round = int.tryParse('${json['round'] ?? ''}') ?? 0;
    final sessions = <RaceSession>[];
    const sessionFields = <(String, String)>[
      ('FirstPractice', 'Antrenman 1'),
      ('SecondPractice', 'Antrenman 2'),
      ('ThirdPractice', 'Antrenman 3'),
      ('SprintQualifying', 'Sprint Sıralaması'),
      ('Sprint', 'Sprint'),
      ('Qualifying', 'Sıralama Turları'),
      ('Race', 'Yarış'),
    ];
    for (final (field, label) in sessionFields) {
      final session = _map(json[field]);
      final date = session['date']?.toString();
      if (date == null || date.isEmpty) continue;
      final time = session['time']?.toString();
      final utc = _parseUtc(date, time);
      if (utc == null) continue;
      sessions.add(RaceSession(
        name: label,
        localTime: MaterialLocalizationsDate.format(utc.toLocal()),
        status: utc.isBefore(DateTime.now().toUtc())
            ? SessionStatus.completed
            : SessionStatus.upcoming,
        startUtc: utc,
      ));
    }
    // Jolpica yarışın tarih/saatini üst düzey `date`/`time` alanlarında verir;
    // ayrı bir `Race` nesnesi yoktur.
    final raceDate = _parseUtc(json['date']?.toString(), json['time']?.toString());
    if (raceDate != null && !sessions.any((s) => s.name == 'Yarış')) {
      sessions.add(RaceSession(
        name: 'Yarış',
        localTime: MaterialLocalizationsDate.format(raceDate.toLocal()),
        status: raceDate.isBefore(DateTime.now().toUtc())
            ? SessionStatus.completed
            : SessionStatus.upcoming,
        startUtc: raceDate,
      ));
    }
    sessions.sort((a, b) => a.startUtc!.compareTo(b.startUtc!));
    return RaceWeekend(
      name: _text(json['raceName'], 'Grand Prix'),
      location: _text(location['locality'], _text(circuit['circuitName'], '')),
      country: _text(location['country'], ''),
      dateLabel: raceDate == null ? '' : MaterialLocalizationsDate.date(raceDate.toLocal()),
      round: round,
      sessions: sessions,
      raceStart: raceDate,
      season: int.tryParse('${json['season'] ?? ''}') ?? 0,
      circuitName: _text(circuit['circuitName'], ''),
    );
  }
}

class RaceSession {
  const RaceSession({required this.name, required this.localTime, required this.status, this.startUtc});
  final String name;
  final String localTime;
  final SessionStatus status;
  final DateTime? startUtc;
}

enum SessionStatus { completed, upcoming, inProgress }

class DriverResult {
  const DriverResult({
    required this.position,
    required this.code,
    required this.team,
    required this.time,
    required this.color,
    this.name = '',
    this.grid = 0,
    this.laps = 0,
    this.points = '',
    this.status = '',
    this.fastestLapTime,
    this.fastestLapRank = 0,
  });
  final int position;
  final String code;
  final String team;

  /// Bitiş süresi/farkı; süre yoksa durum metni (örn. "+1 Lap", "Engine").
  final String time;
  final int color;
  final String name;
  final int grid;
  final int laps;
  final String points;
  final String status;
  final String? fastestLapTime;

  /// En hızlı tur sıralaması (1 = yarışın en hızlı turu); bilinmiyorsa 0.
  final int fastestLapRank;

  factory DriverResult.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['Driver']);
    final team = _teamMap(json['Constructor']);
    final timeData = _map(json['Time']);
    final status = _text(json['status'], '');
    final fastest = _map(json['FastestLap']);
    final fastestTime = _text(_map(fastest['Time'])['time'], '');
    final code = _text(driver['code'], _text(driver['familyName'], '—')).toUpperCase();
    return DriverResult(
      position: int.tryParse('${json['position'] ?? ''}') ?? 0,
      code: code,
      team: _text(team['name'], 'Unknown team'),
      time: _text(timeData['time'], status.isEmpty ? '—' : status),
      color: teamColor(_text(team['constructorId'], '')),
      name: _driverName(driver),
      grid: int.tryParse('${json['grid'] ?? ''}') ?? 0,
      laps: int.tryParse('${json['laps'] ?? ''}') ?? 0,
      points: _text(json['points'], ''),
      status: status,
      fastestLapTime: fastestTime.isEmpty ? null : fastestTime,
      fastestLapRank: int.tryParse('${fastest['rank'] ?? ''}') ?? 0,
    );
  }
}

class QualifyingResult {
  const QualifyingResult({
    required this.position,
    required this.code,
    required this.name,
    required this.team,
    required this.color,
    this.q1 = '',
    this.q2 = '',
    this.q3 = '',
  });
  final int position;
  final String code;
  final String name;
  final String team;
  final int color;
  final String q1;
  final String q2;
  final String q3;

  /// Pilotun ulaştığı son turdaki derecesi.
  String get best => q3.isNotEmpty ? q3 : (q2.isNotEmpty ? q2 : (q1.isNotEmpty ? q1 : '—'));

  factory QualifyingResult.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['Driver']);
    final team = _teamMap(json['Constructor']);
    return QualifyingResult(
      position: int.tryParse('${json['position'] ?? ''}') ?? 0,
      code: _text(driver['code'], _text(driver['familyName'], '—')).toUpperCase(),
      name: _driverName(driver),
      team: _text(team['name'], 'Unknown team'),
      color: teamColor(_text(team['constructorId'], '')),
      q1: _text(json['Q1'], ''),
      q2: _text(json['Q2'], ''),
      q3: _text(json['Q3'], ''),
    );
  }
}

class DriverStanding {
  const DriverStanding({required this.position, required this.name, required this.team, required this.points, required this.wins});
  final int position;
  final String name;
  final String team;
  final String points;
  final String wins;

  factory DriverStanding.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['Driver']);
    final teams = json['Constructors'] is List ? json['Constructors'] as List : const [];
    final team = teams.isEmpty ? <String, dynamic>{} : _map(teams.first);
    return DriverStanding(
      position: int.tryParse('${json['position'] ?? ''}') ?? 0,
      name: '${_text(driver['givenName'], '')} ${_text(driver['familyName'], 'Unknown driver')}'.trim(),
      team: _text(team['name'], 'Unknown team'),
      points: _text(json['points'], '0'),
      wins: _text(json['wins'], '0'),
    );
  }
}

class TeamStanding {
  const TeamStanding({required this.position, required this.name, required this.points, required this.wins});
  final int position;
  final String name;
  final String points;
  final String wins;

  factory TeamStanding.fromJson(Map<String, dynamic> json) {
    final team = _map(json['Constructor']);
    return TeamStanding(
      position: int.tryParse('${json['position'] ?? ''}') ?? 0,
      name: _text(team['name'], 'Unknown team'),
      points: _text(json['points'], '0'),
      wins: _text(json['wins'], '0'),
    );
  }
}

class MaterialLocalizationsDate {
  static String format(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  static String dayTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} ${format(value)}';
  static String date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

/// [now] anında henüz bitmemiş ilk yarış hafta sonunu döndürür. Yarış başladıktan
/// sonra [raceWindow] süresince hâlâ "sıradaki/güncel" sayılır.
RaceWeekend? upcomingRace(
  List<RaceWeekend> races,
  DateTime now, {
  Duration raceWindow = const Duration(hours: 3),
}) {
  final nowUtc = now.toUtc();
  RaceWeekend? best;
  for (final race in races) {
    final start = race.raceStart;
    if (start == null) continue;
    if (!start.add(raceWindow).isAfter(nowUtc)) continue;
    if (best == null || start.isBefore(best.raceStart!)) best = race;
  }
  return best;
}

int teamColor(String id) => switch (id.toLowerCase()) {
  'red_bull' => 0xFF3671C6,
  'ferrari' => 0xFFE8002D,
  'mercedes' => 0xFF27F4D2,
  'mclaren' => 0xFFFF8000,
  'aston_martin' => 0xFF229971,
  'alpine' => 0xFFFF87BC,
  'williams' => 0xFF64C4FF,
  'rb' || 'alphatauri' => 0xFF6692FF,
  'sauber' || 'kick_sauber' => 0xFF52E252,
  'haas' => 0xFFB6BABD,
  _ => 0xFF9AA0AA,
};

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic> ? value : const {};

/// Jolpica/Ergast sonuç kayıtlarında `Constructor` bir nesnedir; yine de liste
/// olarak gelirse ilk öğeyi kullan.
Map<String, dynamic> _teamMap(Object? raw) =>
    raw is List ? (raw.isEmpty ? const {} : _map(raw.first)) : _map(raw);

String _driverName(Map<String, dynamic> driver) =>
    '${_text(driver['givenName'], '')} ${_text(driver['familyName'], '')}'.trim();
String _text(Object? value, String fallback) => value == null || value.toString().isEmpty ? fallback : value.toString();

DateTime? _parseUtc(String? date, String? time) {
  if (date == null || date.isEmpty) return null;
  final raw = '${date}T${time ?? '00:00:00'}';
  final withZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw) ? raw : '${raw}Z';
  return DateTime.tryParse(withZone)?.toUtc();
}
