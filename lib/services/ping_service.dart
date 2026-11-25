import 'package:http/http.dart' as http;

class IPLatency {
  final String ip;
  final int latency;
  final bool success;

  IPLatency({required this.ip, required this.latency, required this.success});

  @override
  String toString() => '$ip: ${success ? '$latency ms' : 'timeout'}';
}

class PingService {
  static const int _concurrentLimit = 10; // 模拟器性能有限，限制并发数避免崩溃

  static Future<IPLatency> testLatency(
    String ip,
    Duration timeout, {
    String? host,
  }) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('http://$ip:80/cdn-cgi/trace'),
      );
      if (host != null && host.trim().isNotEmpty) {
        request.headers['Host'] = host.trim();
      }
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 500) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await response.stream.drain();
      stopwatch.stop();
      return IPLatency(
        ip: ip,
        latency: stopwatch.elapsedMilliseconds,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return IPLatency(ip: ip, latency: 9999, success: false);
    } finally {
      client.close();
    }
  }

  /// 测试多个 IP，支持进度回调
  /// [timeout] 单个 IP 超时时间
  /// [onProgress] 进度回调 (当前完成数, 总数, 当前测试的 IP)
  /// [onResult] 单个结果回调，用于实时显示
  static Future<List<IPLatency>> testMultipleIPs(
    List<String> ips, {
    Duration timeout = const Duration(seconds: 1),
    String? host,
    void Function(int completed, int total, String currentIP)? onProgress,
    void Function(IPLatency result)? onResult,
  }) async {
    final List<IPLatency> results = [];
    int completed = 0;

    // 分批并发测试
    for (int i = 0; i < ips.length; i += _concurrentLimit) {
      final batch = ips.skip(i).take(_concurrentLimit).toList();

      final futures = batch.map((ip) async {
        onProgress?.call(completed, ips.length, ip);
        final result = await testLatency(ip, timeout, host: host);
        completed++;
        onProgress?.call(completed, ips.length, ip);
        onResult?.call(result);
        return result;
      }).toList();

      final batchResults = await Future.wait(futures);
      results.addAll(batchResults);
    }

    // 只返回成功的，按延迟排序
    final successResults = results.where((r) => r.success).toList();
    successResults.sort((a, b) => a.latency.compareTo(b.latency));
    return successResults;
  }
}
