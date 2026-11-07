import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/models/live_timing_model.dart';

class F1LivePulseClient {
  F1LivePulseClient({http.Client? client}):_client=client??http.Client();
  final http.Client _client;
  Future<List<LiveTimingDriver>> fetch(String apiKey) async {
    final response=await _client.get(Uri.parse('https://f1-live-pulse.p.rapidapi.com/timingData'),headers:{'X-RapidAPI-Key':apiKey,'X-RapidAPI-Host':'f1-live-pulse.p.rapidapi.com','Accept':'application/json'}).timeout(const Duration(seconds:10));
    if(response.statusCode==401||response.statusCode==403)throw const F1LivePulseException('API anahtarı geçersiz veya F1 Live Pulse aboneliği etkin değil.');
    if(response.statusCode==429)throw const F1LivePulseException('Ücretsiz planın istek sınırına ulaşıldı. Daha sonra tekrar dene.');
    if(response.statusCode<200||response.statusCode>=300)throw F1LivePulseException('F1 Live Pulse HTTP ${response.statusCode} yanıtı verdi.');
    final decoded=jsonDecode(response.body); final rows=_rows(decoded);
    if(rows==null)throw const F1LivePulseException('API yanıtında sürücü listesi bulunamadı.');
    final drivers=rows.whereType<Map<String,dynamic>>().map(LiveTimingDriver.fromJson).toList()..sort((a,b)=>a.position.compareTo(b.position));
    return drivers;
  }
  void close()=>_client.close();
  List<Object?>? _rows(Object? json){if(json is List)return json.cast<Object?>();if(json is! Map<String,dynamic>)return null;final direct=json['drivers']??json['Drivers'];if(direct is List)return direct.cast<Object?>();final data=json['data']??json['Data'];if(data is List)return data.cast<Object?>();if(data is Map<String,dynamic>){final nested=data['drivers']??data['Drivers'];if(nested is List)return nested.cast<Object?>();}return null;}
}
class F1LivePulseException implements Exception{const F1LivePulseException(this.message);final String message;@override String toString()=>message;}
