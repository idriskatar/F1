import 'package:flutter/material.dart';
import '../../core/models/news_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/news_repository.dart';
import '../../shared/open_url.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key,this.repository,this.onOpenUrl});
  final NewsRepository? repository;
  final Future<bool> Function(String url)? onOpenUrl;
  @override State<NewsScreen> createState()=>_NewsScreenState();
}
class _NewsScreenState extends State<NewsScreen>{
  late final NewsRepository _repository=widget.repository??NewsRepository();
  late Future<NewsFeedResult> _future=_repository.fetchAll();
  String _filter='Tümü';
  @override void dispose(){if(widget.repository==null)_repository.close();super.dispose();}
  Future<void> _refresh() async {setState(()=>_future=_repository.fetchAll(force:true));try{await _future;}catch(_) {}}
  Future<void> _open(NewsItem item) async {final ok=await (widget.onOpenUrl??openExternalUrl)(item.url);if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bağlantı açılamadı')));}
  @override Widget build(BuildContext context)=>SafeArea(child:RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(20),children:[Text('Haberler',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('RSS akışlarından alınır • başlık ve özetler yayıncı kaynaklarından gelir',style:TextStyle(color:AppColors.muted)),const SizedBox(height:14),FutureBuilder<NewsFeedResult>(future:_future,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator()));if(s.hasError)return const Text('Haberler yüklenemedi');final data=s.data!;final sources=<String>{for(final n in data.items)n.sourceName};final filtered=data.items.where((n)=>_filter=='Tümü'||n.sourceName==_filter).toList();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:8,children:[ChoiceChip(label:const Text('Tümü'),selected:_filter=='Tümü',onSelected:(_)=>setState(()=>_filter='Tümü')),...sources.map((name)=>ChoiceChip(label:Text(name=='TRF1.net'?'TRF1.net':name.toUpperCase()),selected:_filter==name,onSelected:(_)=>setState(()=>_filter=name)))]),for(final entry in data.errors.entries) Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Text('${_sourceName(entry.key)} güncellenemedi: ${entry.value}',style:const TextStyle(color:AppColors.amber,fontSize:12))),if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Haber bulunamadı')),for(final item in filtered) _NewsCard(item:item,onTap:()=>_open(item))]);})])));
  String _sourceName(String id)=>_repository.sources.where((s)=>s.id==id).map((s)=>s.name).firstOrNull??id;
}
class _NewsCard extends StatelessWidget{const _NewsCard({required this.item,required this.onTap});final NewsItem item;final VoidCallback onTap;@override Widget build(BuildContext c)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:Container(margin:const EdgeInsets.only(top:12),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.sourceId=='trf1'?item.sourceName.toUpperCase():item.sourceName,style:const TextStyle(color:AppColors.red,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),const SizedBox(height:6),Text(item.title,style:const TextStyle(fontWeight:FontWeight.w800)),if(item.summary.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text(item.summary,style:const TextStyle(color:AppColors.muted,fontSize:12)))])));}
