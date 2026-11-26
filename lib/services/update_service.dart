import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ReleaseInfo {
  final String tag;
  final String title;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tag,
    required this.title,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
  });

  String get version => tag.startsWith('v') ? tag.substring(1) : tag;
}

class UpdateStatus {
  final String currentVersion;
  final List<ReleaseInfo> releases;

  const UpdateStatus({required this.currentVersion, required this.releases});

  ReleaseInfo? get latest => releases.isEmpty ? null : releases.first;

  bool get hasUpdate {
    final latestRelease = latest;
    if (latestRelease == null) return false;
    return UpdateService.compareVersions(
          latestRelease.version,
          currentVersion,
        ) >
        0;
  }
}

class UpdateService {
  static const _releasesURL =
      'https://api.github.com/repos/ligson/cfprefect/releases?per_page=10';

  static Future<UpdateStatus> loadStatus() async {
    final package = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          Uri.parse(_releasesURL),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('读取版本发布信息失败：HTTP ${response.statusCode}');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    final releases = items
        .whereType<Map<String, dynamic>>()
        .where((item) => item['draft'] != true && item['prerelease'] != true)
        .map(
          (item) => ReleaseInfo(
            tag: (item['tag_name'] as String? ?? '').trim(),
            title: (item['name'] as String? ?? '').trim(),
            body: (item['body'] as String? ?? '').trim(),
            htmlUrl: (item['html_url'] as String? ?? '').trim(),
            publishedAt: DateTime.tryParse(
              (item['published_at'] as String? ?? '').trim(),
            ),
          ),
        )
        .where(
          (release) => release.tag.isNotEmpty && release.htmlUrl.isNotEmpty,
        )
        .toList();
    releases.sort((a, b) => compareVersions(b.version, a.version));
    return UpdateStatus(currentVersion: package.version, releases: releases);
  }

  static Future<bool> openRelease(ReleaseInfo release) {
    return launchUrl(
      Uri.parse(release.htmlUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index++) {
      if (leftParts[index] != rightParts[index]) {
        return leftParts[index].compareTo(rightParts[index]);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final parts = value.replaceFirst(RegExp(r'^v'), '').split('.');
    return List<int>.generate(
      3,
      (index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }
}
