class LiveTimingDriver {
  const LiveTimingDriver({required this.position,required this.number,required this.code,required this.name,required this.team,required this.teamColor,required this.lapTime,required this.status,required this.compound,required this.retired,required this.inPit,required this.stopped});
  final int position,teamColor;
  final String number,code,name,team,lapTime,status,compound;
  final bool retired,inPit,stopped;

  String get racingNumber => number;
  String get bestLapTime => lapTime;

  factory LiveTimingDriver.fromJson(Map<String,dynamic> json) {
    final driver=_asMap(json['driver']??json['Driver']??json['DriverData']??json['driverData']);
    final color='${driver['TeamColour']??driver['teamColour']??driver['teamColor']??driver['team_colour']??json['teamColor']??json['team_colour']??''}'.replaceFirst('#','');
    final parsedColor=int.tryParse(color,radix:16)??0x808D95A3;
    final number=json['racingNumber']??json['RacingNumber']??json['driverNumber']??json['DriverNumber']??json['number']??json['driver_number']??'—';
    final code='${driver['Tla']??driver['tla']??driver['code']??json['Tla']??json['tla']??json['code']??'—'}'.toUpperCase();
    final retired=_asBool(json['retired']??json['Retired']??json['isRetired']);
    final inPit=_asBool(json['inPit']??json['InPit']??json['pitLane']);
    final stopped=_asBool(json['stopped']??json['Stopped']);
    final compound='${json['compound']??json['Compound']??json['tyreCompound']??json['TyreCompound']??'—'}'.toUpperCase();
    final status=retired?'OUT':inPit?'PIT':stopped?'STOP':compound=='—'?'':compound;
    final rawPosition=json['position']??json['Position']??json['positionNumber']??json['PositionNumber'];
    final rawLap=json['bestLapTime']??json['BestLapTime']??json['lastLapTime']??json['LastLapTime']??json['lapTime']??json['LapTime'];
    return LiveTimingDriver(position:int.tryParse('$rawPosition')??0,number:'$number',code:code,name:'${driver['FullName']??driver['fullName']??driver['BroadcastName']??driver['broadcastName']??json['fullName']??json['name']??'Unknown driver'}',team:'${driver['TeamName']??driver['teamName']??driver['team_name']??json['teamName']??json['team_name']??'Unknown team'}',teamColor:color.length<=6?0xFF000000|parsedColor:parsedColor,lapTime:'${rawLap??'—'}',status:status,compound:compound,retired:retired,inPit:inPit,stopped:stopped);
  }
}
Map<String,dynamic> _asMap(Object? value)=>value is Map<String,dynamic>?value:const {};
bool _asBool(Object? value)=>value==true||value==1||value=='true';
