import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// A newer release published on GitHub.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.currentVersion,
    required this.notes,
    required this.downloadUrl,
  });

  final String version;
  final String currentVersion;
  final String notes;

  /// The release's APK file, or the release page when no APK is attached.
  final String downloadUrl;
}

/// Checks GitHub Releases of the app repository for a newer version.
///
/// A release is published with a tag such as `v1.0.1` and the signed
/// `app-release.apk` attached; the tag is compared with the installed
/// version (pubspec `version:`).
class UpdateService {
  const UpdateService({http.Client? client}) : _client = client;

  static const String repository = 'TamTam-hub/gabaybatas_app';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repository/releases/latest';

  final http.Client? _client;

  /// The newer release, or null when the app is up to date or GitHub cannot
  /// be reached (an update check never interrupts the resident).
  Future<AppUpdate?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(latestReleaseUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final release = jsonDecode(response.body);
      if (release is! Map<String, dynamic>) return null;
      return updateFromRelease(release, info.version);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Reads a GitHub release; null when it is not newer than [currentVersion].
  static AppUpdate? updateFromRelease(
    Map<String, dynamic> release,
    String currentVersion,
  ) {
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final version = (release['tag_name'] ?? '').toString().replaceFirst(
      RegExp(r'^[vV]'),
      '',
    );
    if (!isNewer(version, currentVersion)) return null;

    var downloadUrl = (release['html_url'] ?? '').toString();
    final assets = release['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        final name = (asset['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = (asset['browser_download_url'] ?? downloadUrl)
              .toString();
          break;
        }
      }
    }
    if (downloadUrl.isEmpty) return null;

    return AppUpdate(
      version: version,
      currentVersion: currentVersion,
      notes: (release['body'] ?? '').toString().trim(),
      downloadUrl: downloadUrl,
    );
  }

  /// Compares versions such as `1.0.10` and `1.0.9` part by part.
  static bool isNewer(String latest, String current) {
    List<int> parts(String value) => value
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
    final a = parts(latest);
    final b = parts(current);
    if (a.every((part) => part == 0)) return false;
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
