import 'dart:io';
import 'package:flutter/foundation.dart';

class DNSService {
  static String _getHostsFilePath() {
    if (Platform.isWindows) {
      return r'C:\Windows\System32\drivers\etc\hosts';
    } else if (Platform.isMacOS || Platform.isLinux) {
      return '/etc/hosts';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static bool get isSupported => !kIsWeb;

  static Future<void> updateDNSMapping(String ip, String domain) async {
    if (kIsWeb) {
      throw Exception('DNS 映射功能在 Web 版本中不可用');
    }

    try {
      final hostsPath = _getHostsFilePath();
      final hostsFile = File(hostsPath);

      if (!await hostsFile.exists()) {
        throw Exception('Hosts file not found at $hostsPath');
      }

      String content = await hostsFile.readAsString();
      final lines = content.split('\n');
      final newLines = <String>[];

      for (final line in lines) {
        if (line.trim().isNotEmpty && !line.trim().startsWith('#')) {
          if (line.contains(domain)) {
            continue;
          }
        }
        newLines.add(line);
      }

      newLines.add('$ip\t$domain');
      final newContent = newLines.join('\n');

      await hostsFile.writeAsString(newContent);
      debugPrint('Successfully updated DNS mapping: $ip -> $domain');
    } catch (e) {
      throw Exception('Failed to update DNS mapping: $e');
    }
  }

  static Future<void> removeDNSMapping(String domain) async {
    if (kIsWeb) {
      throw Exception('DNS 映射功能在 Web 版本中不可用');
    }

    try {
      final hostsPath = _getHostsFilePath();
      final hostsFile = File(hostsPath);

      if (!await hostsFile.exists()) {
        throw Exception('Hosts file not found');
      }

      String content = await hostsFile.readAsString();
      final lines = content.split('\n');
      final newLines = lines
          .where((line) => !line.contains(domain))
          .toList();

      await hostsFile.writeAsString(newLines.join('\n'));
    } catch (e) {
      throw Exception('Failed to remove DNS mapping: $e');
    }
  }
}
