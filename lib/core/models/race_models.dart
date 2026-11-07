class RaceWeekend {
  const RaceWeekend({required this.name, required this.location, required this.country, required this.dateLabel, required this.sessions, required this.round, this.season = 0, this.circuitName = '', this.raceStart});
  final String name, location, country, dateLabel, circuitName;
  final int round, season;
  final DateTime? raceStart;
  final List<RaceSession> sessions;
  bool get hasSprint => sessions.any((s) => s.name == 'Sprint');
  RaceSession? nextSession([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    for (final s in sessions) { if (s.startUtc != null && !s.startUtc!.isBefore(current)) return s; }
    return null;
  }
  factory RaceWeekend.fromJson(Map<String, dynamic> json) {
    final circuit = _map(json['Circuit']); final location = _map(circuit['Location']);
    final parsed = <RaceSession>[];
    const fields = <(String, String)>[('FirstPractice','Antrenman 1'),('SecondPractice','Antrenman 2'),('ThirdPractice','Antrenman 3'),('SprintQualifying','Sprint Sıralaması'),('Sprint','Sprint'),('Qualifying','Sıralama Turları'),('Race','Yarış')];
    for (final (key, label) in fields) {
      final data = _map(json[key]); final start = _parseUtc(data['date']?.toString(), data['time']?.toString());
      if (start != null) parsed.add(RaceSession(name: label, localTime: MaterialLocalizationsDate.format(start.toLocal()), status: start.isBefore(DateTime.now().toUtc()) ? SessionStatus.completed : SessionStatus.upcoming, startUtc: start));
    }
    if (!parsed.any((s) => s.name == 'Yarış')) {
      final start = _parseUtc(json['date']?.toString(), json['time']?.toString());
      if (start != null) parsed.add(RaceSession(name: 'Yarış', localTime: MaterialLocalizationsDate.format(start.toLocal()), status: start.isBefore(DateTime.now().toUtc()) ? SessionStatus.completed : SessionStatus.upcoming, startUtc: start));
    }
    parsed.sort((a,b) => a.startUtc!.compareTo(b.startUtc!));
    final start = _parseUtc(json['date']?.toString(), json['time']?.toString());
    return RaceWeekend(name: _text(json['raceName'],'Grand Prix'), location: _text(location['locality'],''), country: _text(location['country'],''), circuitName: _text(circuit['circuitName'],''), dateLabel: start == null ? '' : MaterialLocalizationsDate.date(start.toLocal()), round: int.tryParse('${json['round'] ?? ''}') ?? 0, season: int.tryParse('${json['season'] ?? ''}') ?? start?.year ?? 0, raceStart: start, sessions: parsed);
  }
}

RaceWeekend? upcomingRace(Iterable<RaceWeekend> races, DateTime now) {
  final cutoff = now.toUtc().subtract(const Duration(hours: 3));
  final candidates = races.where((r) => r.raceStart != null && !r.raceStart!.isBefore(cutoff)).toList()..sort((a,b) => a.raceStart!.compareTo(b.raceStart!));
  return candidates.isEmpty ? null : candidates.first;
}

class RaceSession {
  const RaceSession({required this.name, required this.localTime, required this.status, this.startUtc});
  final String name, localTime;
  final SessionStatus status;
  final DateTime? startUtc;
}
enum SessionStatus { completed, upcoming, inProgress }

class DriverResult {
  const DriverResult({required this.position, required this.code, required this.team, required this.time, required this.color, this.name='', this.grid=0, this.laps=0, this.points='0', this.fastestLapRank=0, this.fastestLapTime, this.status='—'});
  final int position, color, grid, laps, fastestLapRank;
  final String code, team, time, name, points, status;
  final String? fastestLapTime;
  factory DriverResult.fromJson(Map<String,dynamic> json) {
    final d=_map(json['Driver']); final raw=json['Constructor']; final team=raw is List ? (raw.isEmpty? <String,dynamic>{}:_map(raw.first)) : _map(raw);
    final fastest=_map(json['FastestLap']); final lapTime=_map(fastest['Time']); final status=_text(json['status'],'—');
    final time=_text(_map(json['Time'])['time'],status);
    return DriverResult(position:int.tryParse('${json['position']??''}')??0,code:_text(d['code'],_text(d['familyName'],'—')).toUpperCase(),team:_text(team['name'],'Unknown team'),time:time,color:teamColor(_text(team['constructorId'],'')),name:'${_text(d['givenName'],'')} ${_text(d['familyName'],'')}'.trim(),grid:int.tryParse('${json['grid']??''}')??0,laps:int.tryParse('${json['laps']??''}')??0,points:_text(json['points'],'0'),fastestLapRank:int.tryParse('${fastest['rank']??''}')??0,fastestLapTime:lapTime['time']?.toString(),status:status);
  }
}

class QualifyingResult {
  const QualifyingResult({required this.position,required this.code,required this.name,required this.team,required this.color,required this.q1,required this.q2,required this.q3});
  final int position,color; final String code,name,team,q1,q2,q3;
  String get best => q3.isNotEmpty ? q3 : q2.isNotEmpty ? q2 : q1.isNotEmpty ? q1 : '—';
  factory QualifyingResult.fromJson(Map<String,dynamic> j) { final d=_map(j['Driver']); final c=j['Constructor']; final t=c is List ? (c.isEmpty?<String,dynamic>{}:_map(c.first)):_map(c); return QualifyingResult(position:int.tryParse('${j['position']??''}')??0,code:_text(d['code'],'—').toUpperCase(),name:'${_text(d['givenName'],'')} ${_text(d['familyName'],'')}'.trim(),team:_text(t['name'],'Unknown team'),color:teamColor(_text(t['constructorId'],'')),q1:_text(j['Q1'],''),q2:_text(j['Q2'],''),q3:_text(j['Q3'],'')); }
}

class DriverStanding {
  const DriverStanding({required this.position,required this.name,required this.team,required this.points,required this.wins});
  final int position; final String name,team,points,wins;
  factory DriverStanding.fromJson(Map<String,dynamic> j) { final d=_map(j['Driver']); final teams=j['Constructors'] is List?j['Constructors'] as List:const []; final t=teams.isEmpty?<String,dynamic>{}:_map(teams.first); return DriverStanding(position:int.tryParse('${j['position']??''}')??0,name:'${_text(d['givenName'],'')} ${_text(d['familyName'],'Unknown driver')}'.trim(),team:_text(t['name'],'Unknown team'),points:_text(j['points'],'0'),wins:_text(j['wins'],'0')); }
}
class TeamStanding {
  const TeamStanding({required this.position,required this.name,required this.points,required this.wins}); final int position; final String name,points,wins;
  factory TeamStanding.fromJson(Map<String,dynamic> j) { final t=_map(j['Constructor']); return TeamStanding(position:int.tryParse('${j['position']??''}')??0,name:_text(t['name'],'Unknown team'),points:_text(j['points'],'0'),wins:_text(j['wins'],'0')); }
}
class MaterialLocalizationsDate {
  static String format(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  static String date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  static String dayTime(DateTime d)=>'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')} ${format(d)}';
}
int teamColor(String id)=>switch(id.toLowerCase()) {'red_bull'=>0xFF3671C6,'ferrari'=>0xFFE8002D,'mercedes'=>0xFF27F4D2,'mclaren'=>0xFFFF8000,'aston_martin'=>0xFF229971,'alpine'=>0xFFFF87BC,'williams'=>0xFF64C4FF,'rb'||'alphatauri'=>0xFF6692FF,'sauber'||'kick_sauber'=>0xFF52E252,'haas'=>0xFFB6BABD,_=>0xFF9AA0AA};
Map<String,dynamic> _map(Object? x)=>x is Map<String,dynamic>?x:const {};
String _text(Object? x,String fallback)=>x==null||x.toString().isEmpty?fallback:x.toString();
DateTime? _parseUtc(String? date,String? time) { if(date==null||date.isEmpty)return null; final raw='${date}T${time??'00:00:00'}'; final zoned=RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw)?raw:'${raw}Z'; return DateTime.tryParse(zoned)?.toUtc(); }
