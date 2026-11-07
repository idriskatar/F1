import 'package:flutter/material.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../data/remote/news_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository, this.newsRepository, this.clock, this.onOpenTab});
  final JolpicaRepository? repository;
  final NewsRepository? newsRepository;
  final DateTime Function()? clock;
  final ValueChanged<int>? onOpenTab;
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  late final JolpicaRepository _api=widget.repository??JolpicaRepository();
  late final NewsRepository _news=widget.newsRepository??NewsRepository();
  late final Future<NextRaceData> _next=_api.nextRace(now:_now());
  late final Future<JolpicaData<DriverResult>> _results=_api.latestResults();
  late final Future<JolpicaData<DriverStanding>> _drivers=_api.driverStandings();
  late final Future<JolpicaData<TeamStanding>> _teams=_api.teamStandings();
  late final Future<NewsFeedResult> _feed=_news.fetchAll();
  DateTime _now()=> (widget.clock??DateTime.now)();
  @override void dispose(){ if(widget.repository==null)_api.close(); if(widget.newsRepository==null)_news.close(); super.dispose(); }
  @override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,14,20,24),children:[
    Row(children:[Container(width:38,height:30,decoration:BoxDecoration(color:AppColors.red,borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.flag_rounded,color:Colors.white)),const SizedBox(width:10),const Text('F1 TRACKER',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,letterSpacing:1.8)),const Spacer(),IconButton(onPressed:(){},icon:const Icon(Icons.notifications_none_rounded))]),
    const SizedBox(height:18),
    FutureBuilder<NextRaceData>(future:_next,builder:(context,s)=>_raceCard(s)),
    const SizedBox(height:22),
    _section('Son yarış','Sonuçlar',3,()=>_results, (data)=>data.items.isEmpty?const Text('Henüz yarış sonucu yok'):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(data.label,style:const TextStyle(fontWeight:FontWeight.w800)),...data.items.take(3).map((r)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(r.name.isEmpty?r.code:r.name),subtitle:Row(children:[Text(r.code),Text(' • ${r.team}')]),trailing:Text(r.points))) ])),
    const SizedBox(height:22),
    _section('Son haberler','Tüm haberler',2,()=>_feed,(data)=>data.items.isEmpty?Text(data.errors.isEmpty?'Haber bulunamadı':'Haber bulunamadı'):Column(children:data.items.take(3).map((n)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(n.title),subtitle:Text(n.sourceName))).toList())),
    const SizedBox(height:22),const Text('ŞAMPİYONA',style:TextStyle(color:AppColors.muted,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2)),
    _standings('PİLOTLAR',_drivers,(d)=>'${d.position}. ${d.name}',(d)=>d.points),_standings('TAKIMLAR',_teams,(d)=>'${d.position}. ${d.name}',(d)=>d.points),
  ]));
  Widget _raceCard(AsyncSnapshot<NextRaceData> s){
    if(s.connectionState!=ConnectionState.done)return const _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('NEXT RACE',style:TextStyle(color:AppColors.red,fontWeight:FontWeight.w900,letterSpacing:2)),SizedBox(height:8),Text('SIRADAKİ YARIŞ',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:12),Center(child:CircularProgressIndicator())]));
    if(s.hasError)return _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NEXT RACE',style:TextStyle(color:AppColors.red,fontWeight:FontWeight.w900,letterSpacing:2)),const SizedBox(height:8),const Text('Sıradaki yarış yüklenemedi'),Text('${s.error}') ]));
    final data=s.data!; final race=data.race; if(race==null)return const _Card(child:Text('Sezon tamamlandı'));
    final diff=race.raceStart!.difference(_now().toUtc()); final days=diff.isNegative?0:diff.inDays; final hours=diff.isNegative?0:diff.inHours%24;
    final next=race.nextSession(_now());
    return _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NEXT RACE',style:TextStyle(color:AppColors.red,fontWeight:FontWeight.w900,letterSpacing:2)),const SizedBox(height:3),const Text('SIRADAKİ YARIŞ',style:TextStyle(color:AppColors.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1)),const SizedBox(height:10),Text(race.name,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),Text('${race.location}, ${race.country} • Tur ${race.round}',style:const TextStyle(color:AppColors.muted)),const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_CountdownUnit(value:days.toString().padLeft(2,'0'),label:'GÜN'),_CountdownUnit(value:hours.toString().padLeft(2,'0'),label:'SAAT')]),const SizedBox(height:12),Text(next==null?'Yarış hafta sonu programı': 'Sıradaki seans: ${next.name}') ]));
  }
  Widget _section<T>(String title,String action,int tab,Future<T> Function() future,Widget Function(T) content)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(title.toUpperCase(),style:const TextStyle(color:AppColors.muted,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2))),TextButton(onPressed:()=>widget.onOpenTab?.call(tab),child:Text(action))]),FutureBuilder<T>(future:future(),builder:(context,s){if(s.connectionState!=ConnectionState.done)return const _Card(child:Center(child:CircularProgressIndicator()));if(s.hasError)return _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title=='Son yarış'?'Son yarış sonucu yüklenemedi':'Haber bulunamadı'),if(title=='Son yarış')Text('${s.error}') ]));return _Card(child:content(s.data as T));})]);
  Widget _standings<T>(String title,Future<JolpicaData<T>> future,String Function(T) label,String Function(T) points)=>FutureBuilder<JolpicaData<T>>(future:future,builder:(context,s)=>s.hasData?_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:AppColors.muted,fontSize:10,fontWeight:FontWeight.w800)),...s.data!.items.take(3).map((d)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text(label(d))),Text(points(d),style:const TextStyle(fontWeight:FontWeight.w800))])))])):const SizedBox.shrink());
}
class _Card extends StatelessWidget{const _Card({required this.child});final Widget child;@override Widget build(BuildContext c)=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.border)),child:child);}
class _CountdownUnit extends StatelessWidget{const _CountdownUnit({required this.value,required this.label});final String value,label;@override Widget build(BuildContext c)=>Column(children:[Text(value,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:9,color:AppColors.muted,letterSpacing:1.2))]);}
