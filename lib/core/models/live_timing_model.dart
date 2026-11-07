class LiveTimingDriver {
  const LiveTimingDriver({
    required this.position,
    required this.racingNumber,
    required this.code,
    required this.name,
    required this.team,
    required this.teamColor,
    required this.bestLapTime,
    required this.compound,
    required this.retired,
    required this.inPit,
    required this.stopped,
  });

  final int position;
  final String racingNumber;
  final String code;
  final String name;
  final String team;
  final int teamColor;
  final String bestLapTime;
  final String compound;
  final bool retired;
  final bool inPit;
  final bool stopped;

  factory LiveTimingDriver.fromJson(Map<String, dynamic> json) {
    final driver = _map(_value(json, const ['driver', 'Driver']));
    final pos = _value(json, const ['position', 'Position']);
    final number = _value(json, const ['racingNumber', 'RacingNumber', 'number']);
    final teamColor = _string(_value(driver, const ['TeamColour', 'teamColour', 'teamColor']));
    return LiveTimingDriver(
      position: int.tryParse(_string(pos)) ?? 0,
      racingNumber: _string(number, '—'),
      code: _string(_value(driver, const ['Tla', 'tla', 'code']), '—').toUpperCase(),
      name: _string(_value(driver, const ['FullName', 'fullName', 'BroadcastName']), 'Unknown driver'),
      team: _string(_value(driver, const ['TeamName', 'teamName']), 'Unknown team'),
      teamColor: _parseColor(teamColor),
      bestLapTime: _string(_value(json, const ['bestLapTime', 'BestLapTime']), '—'),
      compound: _string(_value(json, const ['compound', 'Compound']), '—').toUpperCase(),
      retired: _bool(_value(json, const ['retired', 'Retired'])),
      inPit: _bool(_value(json, const ['inPit', 'InPit'])),
      stopped: _bool(_value(json, const ['stopped', 'Stopped'])),
    );
  }
}

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic> ? value : const {};

Object? _value(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key)) return map[key];
  }
  return null;
}

String _string(Object? value, [String fallback = '']) =>
    value == null || value.toString().isEmpty ? fallback : value.toString();

bool _bool(Object? value) => value == true || value == 1 || value == 'true';

int _parseColor(String value) {
  final normalized = value.replaceFirst('#', '').trim();
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return 0xFF8D95A3;
  return normalized.length <= 6 ? 0xFF000000 | parsed : parsed;
}
