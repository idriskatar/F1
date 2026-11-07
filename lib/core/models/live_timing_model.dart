class LiveTimingDriver {
  const LiveTimingDriver({required this.position,required this.number,required this.code,required this.name,required this.team,required this.teamColor,required this.lapTime,required this.status});
  final int position,teamColor;
  final String number,code,name,team,lapTime,status;

  factory LiveTimingDriver.fromJson(Map<String,dynamic> json) {
    final driver=_asMap(json['driver']??json['Driver']);
    final color='${driver['TeamColour']??driver['teamColour']??driver['teamColor']??''}'.replaceFirst('#','');
    final parsedColor=int.tryParse(color,radix:16)??0x808D95A3;
    final number=json['racingNumber']??json['RacingNumber']??json['number']??'—';
    final code='${driver['Tla']??driver['tla']??driver['code']??'—'}'.toUpperCase();
    return LiveTimingDriver(position:int.tryParse('${json['position']??json['Position']??''}')??0,number:'$number',code:code,name:'${driver['FullName']??driver['fullName']??driver['BroadcastName']??'Unknown driver'}',team:'${driver['TeamName']??driver['teamName']??'Unknown team'}',teamColor:color.length<=6?0xFF000000|parsedColor:parsedColor,lapTime:'${json['bestLapTime']??json['BestLapTime']??'—'}',status:json['retired']==true?'OUT':json['inPit']==true?'PIT':'');
  }
}
Map<String,dynamic> _asMap(Object? value)=>value is Map<String,dynamic>?value:const {};
