import 'dart:io';
import 'package:flutter/foundation.dart';

/// Clash 配置文件服务
/// 用于修改 Clash 配置文件中的服务器地址，实现 IP 优选
/// 兼容多种 Clash 配置格式（Clash Premium, Clash.Meta, 原版 Clash）
class ClashConfigService {
  /// 更新配置文件中的 server 字段
  /// 只修改 proxies 部分中的 server，保持其他内容不变
  static Future<void> updateConfigDirectly(
    String configPath,
    String newIP,
  ) async {
    try {
      final file = File(configPath);
      if (!await file.exists()) {
        throw Exception('配置文件不存在');
      }

      final content = await file.readAsString();
      final modifiedContent = _replaceServerInProxies(content, newIP);

      // 备份原文件
      final backupPath = '$configPath.bak';
      await file.copy(backupPath);
      debugPrint('已备份原配置到: $backupPath');

      // 写入新内容
      await file.writeAsString(modifiedContent);
      debugPrint('配置文件已更新: $configPath');
    } catch (e) {
      debugPrint('更新配置文件失败: $e');
      rethrow;
    }
  }

  /// 替换 proxies 部分的 server 字段
  /// 兼容多种缩进格式和注释
  /// 会保留原域名到 servername 字段
  static String _replaceServerInProxies(String content, String newIP) {
    final lines = content.split('\n');
    final result = <String>[];
    bool inProxiesSection = false;
    bool inProxyItem = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // 检测 proxies 部分
      if (trimmed == 'proxies:' || trimmed.startsWith('proxies: #')) {
        inProxiesSection = true;
        result.add(line);
        continue;
      }

      // 检测其他顶级部分（结束 proxies 部分）
      if (inProxiesSection) {
        if (!line.startsWith('  ') && !line.startsWith('\t') && trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          if (trimmed.contains(':') && !trimmed.startsWith('-')) {
            inProxiesSection = false;
            inProxyItem = false;
          }
        }
      }

      // 在 proxies 部分内处理
      if (inProxiesSection) {
        // 检测代理项开始
        if (trimmed.startsWith('- ') && !trimmed.startsWith('#')) {
          inProxyItem = true;
        }

        // 替换 server 行
        if (inProxyItem && _isServerLine(trimmed)) {
          final serverIndent = line.indexOf('server');
          final indentStr = line.substring(0, serverIndent);

          // 提取原 server 值
          final originalServer = trimmed
              .replaceFirst('server:', '')
              .split('#')
              .first
              .trim();

          // 替换 server 为新 IP
          result.add('${indentStr}server: $newIP  # IP优选');

          // 如果原 server 是域名，检查下一行是否有 servername
          if (!_isIPAddress(originalServer) && originalServer.isNotEmpty) {
            // 检查下一行
            final nextLine = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
            if (!nextLine.startsWith('servername:')) {
              // 添加 servername 行
              result.add('${indentStr}servername: $originalServer');
            }
          }
          continue;
        }
      }

      result.add(line);
    }

    return result.join('\n');
  }

  /// 判断是否是 IP 地址
  static bool _isIPAddress(String value) {
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6Regex = RegExp(r'^[0-9a-fA-F:]+$');
    return ipv4Regex.hasMatch(value) || ipv6Regex.hasMatch(value);
  }

  /// 判断是否是 server 行（非注释）
  static bool _isServerLine(String trimmed) {
    // 以 server: 开头，且不是注释
    if (trimmed.startsWith('server:') && !trimmed.startsWith('#')) {
      return true;
    }
    // 注释掉的 server 行也替换
    if (trimmed.startsWith('# server:') || trimmed.startsWith('#server:')) {
      return true;
    }
    return false;
  }

  /// 获取配置文件中的当前 server（用于显示）
  static String? getCurrentServer(String configPath) {
    try {
      final file = File(configPath);
      final content = file.readAsStringSync();

      final lines = content.split('\n');
      bool inProxiesSection = false;

      for (final line in lines) {
        final trimmed = line.trim();

        if (trimmed == 'proxies:' || trimmed.startsWith('proxies:')) {
          inProxiesSection = true;
          continue;
        }

        if (inProxiesSection && !line.startsWith('  ') && !line.startsWith('\t') && trimmed.isNotEmpty) {
          break;
        }

        if (inProxiesSection && trimmed.startsWith('server:') && !trimmed.startsWith('#')) {
          return trimmed.replaceFirst('server:', '').trim().split('#').first.trim();
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 恢复备份配置
  static Future<bool> restoreBackup(String configPath) async {
    try {
      final backupFile = File('$configPath.bak');
      if (!await backupFile.exists()) {
        return false;
      }

      final configFile = File(configPath);
      await backupFile.copy(configPath);
      return true;
    } catch (e) {
      debugPrint('恢复备份失败: $e');
      return false;
    }
  }
}
