import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/live_timing_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/rapid_api_key_store.dart';
import '../../data/remote/f1_live_pulse_client.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key,required this.isActive});
  final bool isActive;
  @override State<LiveScreen> createState()=>_LiveScreenState();
}
class _LiveScreenState extends State<LiveScreen>{
  final _store=RapidApiKeyStore(); F1LivePulseClient? _api;
  Timer? _timer; String? _key,_error; List<LiveTimingDriver> _drivers=[]; DateTime? _updatedAt; bool _loading=false,_hasLoaded=false;
  @override void initState(){super.initState();if(widget.isActive)unawaited(_activate());}
  @override
  void didUpdateWidget(covariant LiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        unawaited(_activate());
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
  }
  Future<void> _activate() async {try{_key=(await _store.read())?.trim();if(!mounted)return;if(_key==null||_key!.isEmpty){setState(()=>_error='Anahtarını Ayarlar sekmesinden ekleyebilirsin.');return;}await _refresh();_timer?.cancel();_timer=Timer.periodic(const Duration(seconds:30),(_)=>unawaited(_refresh()));}catch(_){if(mounted)setState(()=>_error='API anahtarı güvenli depodan okunamadı.');}}
  Future<void> _refresh() async {final key=_key;if(key==null||key.isEmpty||_loading)return;setState(()=>_loading=true);try{final api=_api??F1LivePulseClient();_api=api;final data=await api.fetch(key);if(!mounted)return;setState((){_drivers=data;_error=null;_updatedAt=DateTime.now();_hasLoaded=true;});}catch(e){if(mounted)setState(()=>_error='$e');}finally{if(mounted)setState(()=>_loading=false);}}
  @override void dispose(){_timer?.cancel();_api?.close();super.dispose();}
  @override Widget build(BuildContext context)=>SafeArea(child:RefreshIndicator(onRefresh:_refresh,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(20),children:[Row(children:[Expanded(child:Text('Canlı',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900))),IconButton(onPressed:_key==null?null:_refresh,tooltip:'Şimdi yenile',icon:const Icon(Icons.refresh_rounded))]),Text('F1 Live Pulse • RapidAPI',style:TextStyle(color:AppColors.muted)),const SizedBox(height:14),_panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(_error==null&&_drivers.isNotEmpty?Icons.sensors:Icons.cloud_outlined,color:_error==null&&_drivers.isNotEmpty?AppColors.green:AppColors.amber),const SizedBox(width:8),Expanded(child:Text(_updatedAt==null?'Canlı zamanlama bağlantısı': 'Güncellendi ${_clock(_updatedAt!)}',style:const TextStyle(fontWeight:FontWeight.w700))),if(_loading)const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2))]),if(_error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(_error!,style:TextStyle(color:AppColors.amber,fontSize:12))),if(_key==null)Padding(padding:const EdgeInsets.only(top:8),child:Text('API anahtarını Daha fazla → Ayarlar bölümünden kaydet veya değiştir.',style:TextStyle(color:AppColors.muted,fontSize:12)))])),const SizedBox(height:12),if(_drivers.isEmpty&&_error==null&&!_hasLoaded)const Padding(padding:EdgeInsets.all(32),child:Center(child:CircularProgressIndicator())),if(_drivers.isEmpty&&_error==null&&_hasLoaded)Padding(padding:const EdgeInsets.all(18),child:Text('API yanıtı alındı ancak şu anda gösterilecek sürücü zamanlaması yok. Yarış seansı sırasında yeniden deneyebilirsin.',textAlign:TextAlign.center,style:TextStyle(color:AppColors.muted))),for(final d in _drivers)_driver(d),if(_drivers.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('30 saniyede yenilenir • Canlı sekme açıkken',textAlign:TextAlign.center,style:TextStyle(color:AppColors.muted,fontSize:10))) ])));
  Widget _panel(Widget child)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.border)),child:child);
  Widget _driver(LiveTimingDriver d)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.border)),child:Row(children:[SizedBox(width:30,child:Text(d.position==0?'—':'${d.position}',style:TextStyle(color:AppColors.red,fontWeight:FontWeight.w900))),Container(width:3,height:32,color:Color(d.teamColor)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d.name}  ${d.code}',style:const TextStyle(fontWeight:FontWeight.w800)),Text('${d.team}${d.status.isEmpty?'':' • ${d.status}'}',style:TextStyle(color:AppColors.muted,fontSize:11))])),Text(d.lapTime,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:11))]));
}
String _clock(DateTime value)=>'${value.hour.toString().padLeft(2,'0')}:${value.minute.toString().padLeft(2,'0')}';
