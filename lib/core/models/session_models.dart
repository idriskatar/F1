class CompletedSessionData {
  const CompletedSessionData({
    required this.meetingName,
    required this.countryName,
    required this.circuitName,
    required this.sessionName,
    required this.dateEnd,
    required this.standings,
    required this.updatedAt,
    this.sessionKey = 0,
    this.meetingKey = 0,
    this.isCached = false,
    this.laps = const [],
    this.telemetry = const [],
    this.trackTraces = const [],
    this.gaps = const [],
    this.pitStops = const [],
    this.stints = const [],
    this.weather = const [],
    this.unavailableSections = const [],
  });

  final String meetingName;
  final String countryName;
  final String circuitName;
  final String sessionName;
  final DateTime dateEnd;
  final List<SessionStanding> standings;
  final DateTime updatedAt;
  final int sessionKey;
  final int meetingKey;
  final bool isCached;
  final List<LapRecord> laps;
  final List<DriverTelemetry> telemetry;
  final List<TrackTrace> trackTraces;
  final List<GapSample> gaps;
  final List<PitStop> pitStops;
  final List<TyreStint> stints;
  final List<WeatherSample> weather;
  final List<String> unavailableSections;

  List<SessionStanding> get podium => standings.where((row) => row.position > 0).take(3).toList();

  List<LapRecord> lapsFor(int driverNumber) =>
      laps.where((lap) => lap.driverNumber == driverNumber && lap.durationSeconds != null).toList();

  List<GapSample> gapsFor(int driverNumber) => gaps.where((gap) => gap.driverNumber == driverNumber).toList();

  List<PitStop> pitStopsFor(int driverNumber) => pitStops.where((pit) => pit.driverNumber == driverNumber).toList();

  List<TyreStint> stintsFor(int driverNumber) => stints.where((stint) => stint.driverNumber == driverNumber).toList();

  CompletedSessionData withCacheStatus(bool value) => CompletedSessionData(
        meetingName: meetingName,
        countryName: countryName,
        circuitName: circuitName,
        sessionName: sessionName,
        dateEnd: dateEnd,
        standings: standings,
        updatedAt: updatedAt,
        sessionKey: sessionKey,
        meetingKey: meetingKey,
        isCached: value,
        laps: laps,
        telemetry: telemetry,
        trackTraces: trackTraces,
        gaps: gaps,
        pitStops: pitStops,
        stints: stints,
        weather: weather,
        unavailableSections: unavailableSections,
      );

  Map<String, dynamic> toJson() => {
        'meetingName': meetingName,
        'countryName': countryName,
        'circuitName': circuitName,
        'sessionName': sessionName,
        'dateEnd': dateEnd.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sessionKey': sessionKey,
        'meetingKey': meetingKey,
        'standings': standings.map((row) => row.toJson()).toList(),
        'laps': laps.map((row) => row.toJson()).toList(),
        'telemetry': telemetry.map((row) => row.toJson()).toList(),
        'trackTraces': trackTraces.map((row) => row.toJson()).toList(),
        'gaps': gaps.map((row) => row.toJson()).toList(),
        'pitStops': pitStops.map((row) => row.toJson()).toList(),
        'stints': stints.map((row) => row.toJson()).toList(),
        'weather': weather.map((row) => row.toJson()).toList(),
        'unavailableSections': unavailableSections,
      };

  factory CompletedSessionData.fromJson(Map<String, dynamic> json, {bool isCached = false}) => CompletedSessionData(
        meetingName: '${json['meetingName'] ?? ''}',
        countryName: '${json['countryName'] ?? ''}',
        circuitName: '${json['circuitName'] ?? ''}',
        sessionName: '${json['sessionName'] ?? ''}',
        dateEnd: _date(json['dateEnd']),
        updatedAt: _date(json['updatedAt']),
        sessionKey: _int(json['sessionKey']),
        meetingKey: _int(json['meetingKey']),
        standings: _readList(json['standings'], SessionStanding.fromJson),
        laps: _readList(json['laps'], LapRecord.fromJson),
        telemetry: _readList(json['telemetry'], DriverTelemetry.fromJson),
        trackTraces: _readList(json['trackTraces'], TrackTrace.fromJson),
        gaps: _readList(json['gaps'], GapSample.fromJson),
        pitStops: _readList(json['pitStops'], PitStop.fromJson),
        stints: _readList(json['stints'], TyreStint.fromJson),
        weather: _readList(json['weather'], WeatherSample.fromJson),
        unavailableSections: [for (final value in json['unavailableSections'] is List ? json['unavailableSections'] as List : const []) '$value'],
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
    this.points = 0,
    this.gridPosition = 0,
    this.dnf = false,
    this.dns = false,
    this.dsq = false,
  });

  final int position;
  final int driverNumber;
  final String driverName;
  final String driverCode;
  final String teamName;
  final String gapToLeader;
  final int laps;
  final double? resultSeconds;
  final double points;
  final int gridPosition;
  final bool dnf;
  final bool dns;
  final bool dsq;

  Map<String, dynamic> toJson() => {
        'position': position,
        'driverNumber': driverNumber,
        'driverName': driverName,
        'driverCode': driverCode,
        'teamName': teamName,
        'gapToLeader': gapToLeader,
        'laps': laps,
        'resultSeconds': resultSeconds,
        'points': points,
        'gridPosition': gridPosition,
        'dnf': dnf,
        'dns': dns,
        'dsq': dsq,
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
        points: _double(json['points']) ?? 0,
        gridPosition: _int(json['gridPosition']),
        dnf: json['dnf'] == true,
        dns: json['dns'] == true,
        dsq: json['dsq'] == true,
      );
}

class LapRecord {
  const LapRecord({
    required this.driverNumber,
    required this.lapNumber,
    required this.dateStart,
    this.durationSeconds,
    this.sector1,
    this.sector2,
    this.sector3,
    this.intermediateSpeed1,
    this.intermediateSpeed2,
    this.speedTrap,
    this.pitOut = false,
  });

  final int driverNumber;
  final int lapNumber;
  final DateTime? dateStart;
  final double? durationSeconds;
  final double? sector1;
  final double? sector2;
  final double? sector3;
  final double? intermediateSpeed1;
  final double? intermediateSpeed2;
  final double? speedTrap;
  final bool pitOut;

  Map<String, dynamic> toJson() => {
        'driverNumber': driverNumber,
        'lapNumber': lapNumber,
        'dateStart': dateStart?.toIso8601String(),
        'durationSeconds': durationSeconds,
        'sector1': sector1,
        'sector2': sector2,
        'sector3': sector3,
        'intermediateSpeed1': intermediateSpeed1,
        'intermediateSpeed2': intermediateSpeed2,
        'speedTrap': speedTrap,
        'pitOut': pitOut,
      };

  factory LapRecord.fromJson(Map<String, dynamic> json) => LapRecord(
        driverNumber: _int(json['driverNumber']),
        lapNumber: _int(json['lapNumber']),
        dateStart: _optionalDate(json['dateStart']),
        durationSeconds: _double(json['durationSeconds']),
        sector1: _double(json['sector1']),
        sector2: _double(json['sector2']),
        sector3: _double(json['sector3']),
        intermediateSpeed1: _double(json['intermediateSpeed1']),
        intermediateSpeed2: _double(json['intermediateSpeed2']),
        speedTrap: _double(json['speedTrap']),
        pitOut: json['pitOut'] == true,
      );
}

class DriverTelemetry {
  const DriverTelemetry({
    required this.driverNumber,
    required this.driverCode,
    required this.teamName,
    required this.teamColor,
    required this.sampleCount,
    required this.maxSpeed,
    required this.averageSpeed,
    required this.maxRpm,
    required this.averageThrottle,
    required this.brakingPercent,
    required this.drsPercent,
    required this.speedSamples,
  });

  final int driverNumber;
  final String driverCode;
  final String teamName;
  final int teamColor;
  final int sampleCount;
  final double? maxSpeed;
  final double? averageSpeed;
  final int? maxRpm;
  final double? averageThrottle;
  final double? brakingPercent;
  final double? drsPercent;
  final List<double> speedSamples;

  Map<String, dynamic> toJson() => {
        'driverNumber': driverNumber,
        'driverCode': driverCode,
        'teamName': teamName,
        'teamColor': teamColor,
        'sampleCount': sampleCount,
        'maxSpeed': maxSpeed,
        'averageSpeed': averageSpeed,
        'maxRpm': maxRpm,
        'averageThrottle': averageThrottle,
        'brakingPercent': brakingPercent,
        'drsPercent': drsPercent,
        'speedSamples': speedSamples,
      };

  factory DriverTelemetry.fromJson(Map<String, dynamic> json) => DriverTelemetry(
        driverNumber: _int(json['driverNumber']),
        driverCode: '${json['driverCode'] ?? ''}',
        teamName: '${json['teamName'] ?? ''}',
        teamColor: _int(json['teamColor']),
        sampleCount: _int(json['sampleCount']),
        maxSpeed: _double(json['maxSpeed']),
        averageSpeed: _double(json['averageSpeed']),
        maxRpm: json['maxRpm'] == null ? null : _int(json['maxRpm']),
        averageThrottle: _double(json['averageThrottle']),
        brakingPercent: _double(json['brakingPercent']),
        drsPercent: _double(json['drsPercent']),
        speedSamples: _numberList(json['speedSamples']),
      );
}

class TrackTrace {
  const TrackTrace({required this.driverNumber, required this.driverCode, required this.teamColor, required this.points});

  final int driverNumber;
  final String driverCode;
  final int teamColor;
  final List<TrackPoint> points;

  Map<String, dynamic> toJson() => {
        'driverNumber': driverNumber,
        'driverCode': driverCode,
        'teamColor': teamColor,
        'points': points.map((point) => point.toJson()).toList(),
      };

  factory TrackTrace.fromJson(Map<String, dynamic> json) => TrackTrace(
        driverNumber: _int(json['driverNumber']),
        driverCode: '${json['driverCode'] ?? ''}',
        teamColor: _int(json['teamColor']),
        points: _readList(json['points'], TrackPoint.fromJson),
      );
}

class TrackPoint {
  const TrackPoint({required this.x, required this.y});
  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(x: _double(json['x']) ?? 0, y: _double(json['y']) ?? 0);
}

class GapSample {
  const GapSample({required this.driverNumber, required this.date, this.gapToLeader, this.interval});
  final int driverNumber;
  final DateTime? date;
  final String? gapToLeader;
  final String? interval;

  Map<String, dynamic> toJson() => {'driverNumber': driverNumber, 'date': date?.toIso8601String(), 'gapToLeader': gapToLeader, 'interval': interval};
  factory GapSample.fromApi(Map<String, dynamic> json) => GapSample(
        driverNumber: _int(json['driver_number']),
        date: _optionalDate(json['date']),
        gapToLeader: json['gap_to_leader']?.toString(),
        interval: json['interval']?.toString(),
      );
  factory GapSample.fromJson(Map<String, dynamic> json) => GapSample(
        driverNumber: _int(json['driverNumber']),
        date: _optionalDate(json['date']),
        gapToLeader: json['gapToLeader']?.toString(),
        interval: json['interval']?.toString(),
      );
}

class PitStop {
  const PitStop({required this.driverNumber, required this.lapNumber, required this.date, this.pitSeconds, this.laneSeconds, this.stopSeconds});
  final int driverNumber;
  final int lapNumber;
  final DateTime? date;
  final double? pitSeconds;
  final double? laneSeconds;
  final double? stopSeconds;

  Map<String, dynamic> toJson() => {
        'driverNumber': driverNumber,
        'lapNumber': lapNumber,
        'date': date?.toIso8601String(),
        'pitSeconds': pitSeconds,
        'laneSeconds': laneSeconds,
        'stopSeconds': stopSeconds,
      };
  factory PitStop.fromApi(Map<String, dynamic> json) => PitStop(
        driverNumber: _int(json['driver_number']),
        lapNumber: _int(json['lap_number']),
        date: _optionalDate(json['date']),
        pitSeconds: _double(json['pit_duration']),
        laneSeconds: _double(json['lane_duration']),
        stopSeconds: _double(json['stop_duration']),
      );
  factory PitStop.fromJson(Map<String, dynamic> json) => PitStop(
        driverNumber: _int(json['driverNumber']),
        lapNumber: _int(json['lapNumber']),
        date: _optionalDate(json['date']),
        pitSeconds: _double(json['pitSeconds']),
        laneSeconds: _double(json['laneSeconds']),
        stopSeconds: _double(json['stopSeconds']),
      );
}

class TyreStint {
  const TyreStint({
    required this.driverNumber,
    required this.stintNumber,
    required this.lapStart,
    required this.lapEnd,
    required this.compound,
    required this.tyreAgeAtStart,
  });

  final int driverNumber;
  final int stintNumber;
  final int lapStart;
  final int lapEnd;
  final String compound;
  final int tyreAgeAtStart;

  int get lapCount => lapEnd >= lapStart ? lapEnd - lapStart + 1 : 0;

  Map<String, dynamic> toJson() => {
        'driverNumber': driverNumber,
        'stintNumber': stintNumber,
        'lapStart': lapStart,
        'lapEnd': lapEnd,
        'compound': compound,
        'tyreAgeAtStart': tyreAgeAtStart,
      };
  factory TyreStint.fromApi(Map<String, dynamic> json) => TyreStint(
        driverNumber: _int(json['driver_number']),
        stintNumber: _int(json['stint_number']),
        lapStart: _int(json['lap_start']),
        lapEnd: _int(json['lap_end']),
        compound: '${json['compound'] ?? ''}',
        tyreAgeAtStart: _int(json['tyre_age_at_start']),
      );
  factory TyreStint.fromJson(Map<String, dynamic> json) => TyreStint(
        driverNumber: _int(json['driverNumber']),
        stintNumber: _int(json['stintNumber']),
        lapStart: _int(json['lapStart']),
        lapEnd: _int(json['lapEnd']),
        compound: '${json['compound'] ?? ''}',
        tyreAgeAtStart: _int(json['tyreAgeAtStart']),
      );
}

class WeatherSample {
  const WeatherSample({
    required this.date,
    this.airTemperature,
    this.trackTemperature,
    this.humidity,
    this.pressure,
    this.rainfall,
    this.windDirection,
    this.windSpeed,
  });

  final DateTime? date;
  final double? airTemperature;
  final double? trackTemperature;
  final double? humidity;
  final double? pressure;
  final bool? rainfall;
  final int? windDirection;
  final double? windSpeed;

  Map<String, dynamic> toJson() => {
        'date': date?.toIso8601String(),
        'airTemperature': airTemperature,
        'trackTemperature': trackTemperature,
        'humidity': humidity,
        'pressure': pressure,
        'rainfall': rainfall,
        'windDirection': windDirection,
        'windSpeed': windSpeed,
      };
  factory WeatherSample.fromJson(Map<String, dynamic> json) => WeatherSample(
        date: _optionalDate(json['date']),
        airTemperature: _double(json['airTemperature']),
        trackTemperature: _double(json['trackTemperature']),
        humidity: _double(json['humidity']),
        pressure: _double(json['pressure']),
        rainfall: json['rainfall'] == null ? null : _boolish(json['rainfall']),
        windDirection: json['windDirection'] == null ? null : _int(json['windDirection']),
        windSpeed: _double(json['windSpeed']),
      );
}

List<T> _readList<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
      for (final item in value is List ? value : const [])
        if (item is Map<String, dynamic>) parse(item),
    ];

List<double> _numberList(Object? value) => [
      for (final item in value is List ? value : const [])
        if (_double(item) != null) _double(item)!,
    ];

int _int(Object? value) => int.tryParse('$value') ?? 0;
double? _double(Object? value) => value is num ? value.toDouble() : double.tryParse('$value');
DateTime? _optionalDate(Object? value) => DateTime.tryParse('$value')?.toUtc();
DateTime _date(Object? value) => _optionalDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
bool _boolish(Object? value) => value == true || (_double(value) ?? 0) > 0;
