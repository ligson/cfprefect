import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

class CloudflareService {
  static const String _apiUrl = 'https://api.cloudflare.com/client/v4/ips';

  static http.Client _createClient() {
    final httpClient = HttpClient();

    // 让系统自动处理代理（读取环境变量 HTTP_PROXY/HTTPS_PROXY）
    // 只在 Android 模拟器上需要特殊处理
    if (Platform.isAndroid) {
      // Android 模拟器可能需要通过 10.0.2.2 访问主机代理
      // 但优先使用环境变量中的代理设置
      final envProxy = Platform.environment['https_proxy'] ??
                       Platform.environment['HTTPS_PROXY'] ??
                       Platform.environment['http_proxy'] ??
                       Platform.environment['HTTP_PROXY'];

      if (envProxy != null && envProxy.isNotEmpty) {
        // 解析环境变量中的代理地址
        final proxyUri = Uri.tryParse(envProxy);
        if (proxyUri != null) {
          final proxyHost = proxyUri.host;
          final proxyPort = proxyUri.port;
          // 如果代理地址是 127.0.0.1 或 localhost，替换为 10.0.2.2
          if (proxyHost == '127.0.0.1' || proxyHost == 'localhost') {
            httpClient.findProxy = (uri) => 'PROXY 10.0.2.2:$proxyPort';
          }
        }
      }
    }

    // 其他平台使用系统默认代理设置（自动读取环境变量）
    return IOClient(httpClient);
  }

  static Future<List<String>> fetchCloudflareIPs() async {
    try {
      debugLog('开始获取 Cloudflare IP...');
      debugLog('请求 URL: $_apiUrl');

      final client = _createClient();
      try {
        final response = await client.get(Uri.parse(_apiUrl)).timeout(
          const Duration(seconds: 15),
        );

        debugLog('HTTP 状态码: ${response.statusCode}');

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: 无法获取 IP 列表');
        }

        final Map<String, dynamic> data = jsonDecode(response.body);
        debugLog('API 响应: $data');

        if (data['success'] != true) {
          throw Exception('API 错误: ${data['errors']}');
        }

        final result = data['result'] as Map<String, dynamic>?;
        if (result == null) {
          throw Exception('result 字段为空');
        }

        debugLog('Result 内容: $result');
        final ipv4List = List<String>.from(result['ipv4_cidrs'] ?? []);

        debugLog('成功获取 ${ipv4List.length} 个 IPv4');
        debugLog('IPv4 列表: $ipv4List');
        return ipv4List;
      } finally {
        client.close();
      }
    } catch (e) {
      debugLog('错误详情: $e');
      throw Exception('获取 Cloudflare IP 失败: $e');
    }
  }

  static void debugLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] [CloudflareService] $message');
  }

  /// 从每个 CIDR 段中生成具体 IP
  /// [maxPerCidr] 每个 CIDR 段最大生成的 IP 数量，null 表示全部生成
  static Future<List<String>> extractBaseIPs(List<String> cidrs, {int? maxPerCidr}) async {
    final List<String> result = [];

    for (final cidr in cidrs) {
      final parts = cidr.split('/');
      if (parts.length != 2) continue;

      final baseIP = parts[0];
      final prefixLen = int.tryParse(parts[1]) ?? 32;

      final ipParts = baseIP.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      if (ipParts.length != 4) continue;

      // 计算主机位数（32 - 前缀长度）
      final hostBits = 32 - prefixLen;
      if (hostBits <= 0) {
        result.add(baseIP);
        continue;
      }

      // 计算该 CIDR 内的 IP 总数
      final ipCount = 1 << hostBits;

      // 将基础 IP 转换为 32 位整数
      int baseInt = (ipParts[0] << 24) | (ipParts[1] << 16) | (ipParts[2] << 8) | ipParts[3];

      // 计算实际生成的数量
      final generateCount = maxPerCidr != null ? min(maxPerCidr, ipCount - 1) : ipCount - 1;

      // 均匀采样
      if (maxPerCidr != null && ipCount - 1 > maxPerCidr) {
        final step = (ipCount - 1) / maxPerCidr;
        for (int i = 0; i < generateCount; i++) {
          final offset = (i * step).round() + 1;
          final ipInt = baseInt + offset;
          result.add(_intToIP(ipInt));
        }
      } else {
        // 全部生成（跳过 .0 网络地址）
        for (int offset = 1; offset <= generateCount; offset++) {
          final ipInt = baseInt + offset;
          result.add(_intToIP(ipInt));
        }
      }
    }

    debugLog('从 ${cidrs.length} 个 CIDR 中生成了 ${result.length} 个具体 IP');
    return result;
  }

  static String _intToIP(int ip) {
    return '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';
  }
}
