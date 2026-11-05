class RaceWeekend {
  const RaceWeekend({
    required this.name,
    required this.location,
    required this.country,
    required this.dateLabel,
    required this.sessions,
    required this.round,
    this.raceStart,
  });

  final String name;
  final String location;
  final String country;
  final String dateLabel;
  final int round;
  final List<RaceSession> sessions;

  /// Yarışın UTC başlangıç zamanı; API vermediyse null.
  final DateTime? raceStart;

  /// [now] anından sonra başlayacak ilk seans (seanslar zamana göre sıralıdır).
  RaceSession? nextSession(DateTime now) {
    final nowUtc = now.toUtc();
    for (final session in sessions) {
      final start = session.startUtc;
      if (start != null && start.isAfter(nowUtc)) return session;
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
  const DriverResult({required this.position, required this.code, required this.team, required this.time, required this.color});
  final int position;
  final String code;
  final String team;
  final String time;
  final int color;

  factory DriverResult.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['Driver']);
    // Jolpica/Ergast sonuç kayıtlarında `Constructor` bir nesnedir; yine de
    // liste olarak gelirse ilk öğeyi kullan.
    final rawTeam = json['Constructor'];
    final team = rawTeam is List
        ? (rawTeam.isEmpty ? <String, dynamic>{} : _map(rawTeam.first))
        : _map(rawTeam);
    final timeData = _map(json['Time']);
    final status = json['status']?.toString();
    final time = _text(timeData['time'], _text(json['points'], status ?? '—'));
    return DriverResult(
      position: int.tryParse('${json['position'] ?? ''}') ?? 0,
      code: _text(driver['code'], _text(driver['familyName'], '—')).toUpperCase(),
      team: _text(team['name'], 'Unknown team'),
      time: time,
      color: teamColor(_text(team['constructorId'], '')),
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
String _text(Object? value, String fallback) => value == null || value.toString().isEmpty ? fallback : value.toString();

DateTime? _parseUtc(String? date, String? time) {
  if (date == null || date.isEmpty) return null;
  final raw = '${date}T${time ?? '00:00:00'}';
  final withZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw) ? raw : '${raw}Z';
  return DateTime.tryParse(withZone)?.toUtc();
}
