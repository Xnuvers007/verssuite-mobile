import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/native_bridge.dart';

class UpdateAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String arch;

  const UpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.arch,
  });

  static String detectArch(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('arm64-v8a')) return 'arm64-v8a';
    if (lower.contains('armeabi-v7a')) return 'armeabi-v7a';
    if (lower.contains('x86_64')) return 'x86_64';
    if (lower.contains('universal')) return 'universal';
    return 'all';
  }

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return UpdateAsset(
      name: name,
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      arch: detectArch(name),
    );
  }

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AppUpdateInfo {
  final String tagName;
  final String title;
  final String changelog;
  final String htmlUrl;
  final String publishedAt;
  final List<UpdateAsset> assets;

  const AppUpdateInfo({
    required this.tagName,
    required this.title,
    required this.changelog,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  String get cleanVersion => tagName.startsWith('v') ? tagName.substring(1) : tagName;

  UpdateAsset? getOptimalAsset(String deviceAbi) {
    if (assets.isEmpty) return null;

    final apkAssets = assets.where((a) => a.name.endsWith('.apk')).toList();
    if (apkAssets.isEmpty) return null;

    // 1. Direct match for device ABI
    final directMatch = apkAssets.where((a) => a.arch == deviceAbi).toList();
    if (directMatch.isNotEmpty) return directMatch.first;

    // 2. Fallback to universal
    final universal = apkAssets.where((a) => a.arch == 'universal').toList();
    if (universal.isNotEmpty) return universal.first;

    // 3. Fallback to any APK
    return apkAssets.first;
  }
}

class UpdateService {
  static const String repoOwner = 'Xnuvers007';
  static const String repoName = 'verssuite-mobile';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static const String _prefDismissedTag = 'dismissed_update_tag';
  static const String _prefDismissedTime = 'dismissed_update_time';
  static const String _prefInstalledVersion = 'installed_app_version';

  /// Returns the current installed app version.
  /// Priority:
  /// 1. Compile-time constant from --dart-define=APP_VERSION=... (if not default '1.0.0')
  /// 2. Android native PackageManager versionName (if not default '1.0.0')
  /// 3. Locally saved version in SharedPreferences from in-app updates
  /// 4. Fallback to native bridge or '1.0.0'
  static Future<String> getCurrentVersion() async {
    const envVer = String.fromEnvironment('APP_VERSION');
    if (envVer.isNotEmpty && envVer != '1.0.0') {
      return envVer;
    }

    try {
      final nativeVer = await NativeBridge.getAppVersion();
      if (nativeVer.isNotEmpty && nativeVer != '1.0.0') {
        return nativeVer;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVer = prefs.getString(_prefInstalledVersion);
      if (savedVer != null && savedVer.isNotEmpty) {
        return savedVer;
      }
    } catch (_) {}

    try {
      final nativeVer = await NativeBridge.getAppVersion();
      if (nativeVer.isNotEmpty) return nativeVer;
    } catch (_) {}

    return envVer.isNotEmpty ? envVer : '1.0.0';
  }

  /// Check if the user already dismissed this update within the last 24 hours.
  static Future<bool> isUpdateDismissed(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedTag = prefs.getString(_prefDismissedTag);
      final dismissedTime = prefs.getInt(_prefDismissedTime) ?? 0;
      if (dismissedTag == tagName) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - dismissedTime;
        // Don't auto-prompt again for 24 hours if dismissed
        if (elapsed < const Duration(hours: 24).inMilliseconds) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Mark the update as dismissed so the dialog doesn't repeatedly appear.
  static Future<void> markUpdateDismissed(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDismissedTag, tagName);
      await prefs.setInt(_prefDismissedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Mark the version as installed when user downloads and initiates installation.
  static Future<void> markUpdateInstalled(String versionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = versionName.replaceFirst(RegExp(r'^[vV]'), '').trim();
      await prefs.setString(_prefInstalledVersion, clean);
      await prefs.setString(_prefDismissedTag, versionName);
      await prefs.setInt(_prefDismissedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Compare two semantic version strings (e.g. "1.0.3" vs "1.0.0").
  /// Returns true if remote is strictly newer than current.
  static bool isNewer(String remote, String current) {
    final rClean = remote.replaceFirst(RegExp(r'^[vV]'), '').trim();
    final cClean = current.replaceFirst(RegExp(r'^[vV]'), '').trim();

    final rParts = _parseVersionParts(rClean);
    final cParts = _parseVersionParts(cClean);

    final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
    for (var i = 0; i < maxLen; i++) {
      final rVal = i < rParts.length ? rParts[i] : 0;
      final cVal = i < cParts.length ? cParts[i] : 0;
      if (rVal > cVal) return true;
      if (rVal < cVal) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    // Strip build metadata like "+1" or "-build"
    final clean = version.split('+').first.split('-').first;
    return clean
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  /// Check GitHub Releases API for the latest version.
  static Future<AppUpdateInfo?> checkForUpdate({bool checkDismissed = false}) async {
    final client = HttpClient();
    client.findProxy = (uri) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse(releasesApiUrl);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'VersSuite-Mobile-App');
      req.headers.set('Accept', 'application/vnd.github.v3+json');

      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        return null;
      }

      final bodyStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;

      final tagName = data['tag_name'] as String? ?? '';
      if (tagName.isEmpty) return null;

      // If requested, ignore if already dismissed within cooldown window
      if (checkDismissed && await isUpdateDismissed(tagName)) {
        return null;
      }

      final currentVersion = await getCurrentVersion();

      // Check if remote version is newer
      if (!isNewer(tagName, currentVersion)) {
        return null;
      }

      final rawAssets = data['assets'] as List<dynamic>? ?? [];
      final assets = rawAssets
          .map((e) => UpdateAsset.fromJson(e as Map<String, dynamic>))
          .toList();

      return AppUpdateInfo(
        tagName: tagName,
        title: data['name'] as String? ?? tagName,
        changelog: data['body'] as String? ?? 'No release notes provided.',
        htmlUrl: data['html_url'] as String? ??
            'https://github.com/$repoOwner/$repoName/releases',
        publishedAt: data['published_at'] as String? ?? '',
        assets: assets,
      );
    } catch (e) {
      print('[UpdateService] Check error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetch the latest release info regardless of whether it's newer (useful for manual check).
  static Future<AppUpdateInfo?> getLatestReleaseInfo() async {
    final client = HttpClient();
    client.findProxy = (uri) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse(releasesApiUrl);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'VersSuite-Mobile-App');
      req.headers.set('Accept', 'application/vnd.github.v3+json');

      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;

      final bodyStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;

      final rawAssets = data['assets'] as List<dynamic>? ?? [];
      final assets = rawAssets
          .map((e) => UpdateAsset.fromJson(e as Map<String, dynamic>))
          .toList();

      return AppUpdateInfo(
        tagName: data['tag_name'] as String? ?? '',
        title: data['name'] as String? ?? '',
        changelog: data['body'] as String? ?? '',
        htmlUrl: data['html_url'] as String? ?? '',
        publishedAt: data['published_at'] as String? ?? '',
        assets: assets,
      );
    } catch (e) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Download the APK with progress streaming.
  static Future<File?> downloadApk(
    UpdateAsset asset, {
    required void Function(int received, int total) onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    try {
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final file = File('${updatesDir.path}/${asset.name.isNotEmpty ? asset.name : "verssuite_update.apk"}');
      if (await file.exists()) {
        await file.delete();
      }

      final req = await client.getUrl(Uri.parse(asset.downloadUrl));
      req.headers.set('User-Agent', 'VersSuite-Mobile-App');
      req.followRedirects = true;

      final resp = await req.close();
      if (resp.statusCode != 200 && resp.statusCode != 302) {
        return null;
      }

      final total = resp.contentLength > 0 ? resp.contentLength : asset.size;
      var received = 0;

      final sink = file.openWrite();
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();

      return file;
    } catch (e) {
      print('[UpdateService] Download error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Trigger the native PackageInstaller via FileProvider.
  static Future<bool> installApk(String filePath) async {
    return await NativeBridge.installApk(filePath);
  }
}
