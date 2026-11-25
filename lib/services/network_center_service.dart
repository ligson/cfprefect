import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceEndpoint {
  final String relayMode;
  final String serverName;

  const DeviceEndpoint({required this.relayMode, required this.serverName});
}

class NetworkCenterService {
  final String baseUrl;
  final String deviceToken;

  NetworkCenterService({required this.baseUrl, required this.deviceToken});

  Future<DeviceEndpoint> fetchDeviceEndpoint() async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'\/$'), '')}/api/public/devices/$deviceToken',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('读取设备配置失败：HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return DeviceEndpoint(
      relayMode: (payload['relay_mode'] as String? ?? '').trim(),
      serverName: (payload['server_name'] as String? ?? '').trim(),
    );
  }

  Future<int> uploadCandidates({required List<dynamic> candidates}) async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'\\/$'), '')}/api/public/devices/$deviceToken/candidates',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'candidates': candidates
                .map((item) => {'ip': item.ip, 'latency_ms': item.latency})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Network Center 更新失败：HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>? ?? data;
    return (payload['count'] as num?)?.toInt() ?? 0;
  }
}
