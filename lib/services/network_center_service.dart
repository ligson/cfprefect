import 'dart:convert';
import 'package:http/http.dart' as http;

class NetworkCenterService {
  final String baseUrl;
  final String deviceToken;

  NetworkCenterService({required this.baseUrl, required this.deviceToken});

  Future<int> uploadCandidates({required String profile, required List<dynamic> candidates}) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'\\/$'), '')}/api/public/devices/$deviceToken/candidates');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile': profile, 'candidates': candidates.map((item) => {'ip': item.ip, 'latency_ms': item.latency}).toList()}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Network Center 更新失败：HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>? ?? data;
    return (payload['count'] as num?)?.toInt() ?? 0;
  }
}
