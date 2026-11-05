import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal HTTP boundary for the optional personal FastAPI service.
/// Configure a reachable base URL before using it on a physical phone.
class F1ApiClient {
  F1ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> health() async {
    final uri = Uri.parse('$baseUrl/health');
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}
