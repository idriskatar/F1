class LiveTimingDriver {
  const LiveTimingDriver({required this.position,required this.number,required this.code,required this.name,required this.team,required this.teamColor,required this.lapTime,required this.status,required this.compound,required this.retired,required this.inPit,required this.stopped});
  final int position,teamColor;
  final String number,code,name,team,lapTime,status,compound;
  final bool retired,inPit,stopped;

  String get racingNumber => number;
  String get bestLapTime => lapTime;

  factory LiveTimingDriver.fromJson(Map<String,dynamic> json) {
    final driver=_asMap(json['driver']??json['Driver']);
    final color='${driver['TeamColour']??driver['teamColour']??driver['teamColor']??''}'.replaceFirst('#','');
    final parsedColor=int.tryParse(color,radix:16)??0x808D95A3;
    final number=json['racingNumber']??json['RacingNumber']??json['number']??'—';
    final code='${driver['Tla']??driver['tla']??driver['code']??'—'}'.toUpperCase();
    final retired=_asBool(json['retired']??json['Retired']);
    final inPit=_asBool(json['inPit']??json['InPit']);
    final stopped=_asBool(json['stopped']??json['Stopped']);
    final compound='${json['compound']??json['Compound']??'—'}'.toUpperCase();
    final status=retired?'OUT':inPit?'PIT':stopped?'STOP':compound=='—'?'':compound;
    return LiveTimingDriver(position:int.tryParse('${json['position']??json['Position']??''}')??0,number:'$number',code:code,name:'${driver['FullName']??driver['fullName']??driver['BroadcastName']??'Unknown driver'}',team:'${driver['TeamName']??driver['teamName']??'Unknown team'}',teamColor:color.length<=6?0xFF000000|parsedColor:parsedColor,lapTime:'${json['bestLapTime']??json['BestLapTime']??'—'}',status:status,compound:compound,retired:retired,inPit:inPit,stopped:stopped);
  }
}
Map<String,dynamic> _asMap(Object? value)=>value is Map<String,dynamic>?value:const {};
bool _asBool(Object? value)=>value==true||value==1||value=='true';
