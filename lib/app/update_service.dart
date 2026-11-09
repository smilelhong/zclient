import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub Releases update check (zic posture): compare versionName with
/// the latest release tag; the download itself opens in the browser.
class UpdateCheck {
  const UpdateCheck({
    required this.currentVersion,
    required this.latestVersion,
    required this.pageUrl,
    this.notes = '',
  });

  final String currentVersion;
  final String latestVersion;
  final String pageUrl;
  final String notes;

  bool get hasUpdate =>
      _normalize(latestVersion).compareTo(_normalize(currentVersion)) > 0;

  static String _normalize(String v) =>
      v.startsWith('v') ? v.substring(1) : v;

  static const repo = 'smilelhong/zclient';

  static Future<UpdateCheck> run() async {
    final info = await PackageInfo.fromPlatform();
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('GitHub API ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    return UpdateCheck(
      currentVersion: info.version,
      latestVersion: '${(data as Map)['tag_name'] ?? ''}',
      pageUrl:
          'https://github.com/$repo/releases/latest',
      notes: '${data['body'] ?? ''}',
    );
  }
}
