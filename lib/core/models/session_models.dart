class CompletedSessionData {
  const CompletedSessionData({
    required this.meetingName,
    required this.countryName,
    required this.circuitName,
    required this.sessionName,
    required this.dateEnd,
    required this.standings,
    required this.updatedAt,
    this.isCached = false,
  });

  final String meetingName;
  final String countryName;
  final String circuitName;
  final String sessionName;
  final DateTime dateEnd;
  final List<SessionStanding> standings;
  final DateTime updatedAt;
  final bool isCached;

  CompletedSessionData withCacheStatus(bool value) => CompletedSessionData(
        meetingName: meetingName,
        countryName: countryName,
        circuitName: circuitName,
        sessionName: sessionName,
        dateEnd: dateEnd,
        standings: standings,
        updatedAt: updatedAt,
        isCached: value,
      );

  Map<String, dynamic> toJson() => {
        'meetingName': meetingName,
        'countryName': countryName,
        'circuitName': circuitName,
        'sessionName': sessionName,
        'dateEnd': dateEnd.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'standings': standings.map((row) => row.toJson()).toList(),
      };

  factory CompletedSessionData.fromJson(Map<String, dynamic> json, {bool isCached = false}) => CompletedSessionData(
        meetingName: '${json['meetingName'] ?? ''}',
        countryName: '${json['countryName'] ?? ''}',
        circuitName: '${json['circuitName'] ?? ''}',
        sessionName: '${json['sessionName'] ?? ''}',
        dateEnd: DateTime.tryParse('${json['dateEnd'] ?? ''}')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        standings: [
          for (final value in json['standings'] is List ? json['standings'] as List : const [])
            if (value is Map<String, dynamic>) SessionStanding.fromJson(value),
        ],
        isCached: isCached,
      );
}

class SessionStanding {
  const SessionStanding({
    required this.position,
    required this.driverNumber,
    required this.driverName,
    required this.driverCode,
    required this.teamName,
    required this.gapToLeader,
    required this.laps,
    this.resultSeconds,
  });

  final int position;
  final int driverNumber;
  final String driverName;
  final String driverCode;
  final String teamName;
  final String gapToLeader;
  final int laps;
  final double? resultSeconds;

  Map<String, dynamic> toJson() => {
        'position': position,
        'driverNumber': driverNumber,
        'driverName': driverName,
        'driverCode': driverCode,
        'teamName': teamName,
        'gapToLeader': gapToLeader,
        'laps': laps,
        'resultSeconds': resultSeconds,
      };

  factory SessionStanding.fromJson(Map<String, dynamic> json) => SessionStanding(
        position: _int(json['position']),
        driverNumber: _int(json['driverNumber']),
        driverName: '${json['driverName'] ?? ''}',
        driverCode: '${json['driverCode'] ?? ''}',
        teamName: '${json['teamName'] ?? ''}',
        gapToLeader: '${json['gapToLeader'] ?? ''}',
        laps: _int(json['laps']),
        resultSeconds: _double(json['resultSeconds']),
      );
}

int _int(Object? value) => int.tryParse('$value') ?? 0;
double? _double(Object? value) => value is num ? value.toDouble() : double.tryParse('$value');
