import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// A published version of the Android app, as blujem_daily offers it.
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.sha256,
    required this.size,
    required this.apkUrl,
  });

  final int versionCode;
  final String versionName;
  final String notes;
  final String sha256;
  final int size;

  /// A signed link, good for an hour.
  final String apkUrl;

  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  /// The reply of app-latest, or null when nothing usable is published.
  static AppRelease? tryParse(Map<String, dynamic> j) {
    final code = (j['versionCode'] as num?)?.toInt() ?? 0;
    final url = '${j['apkUrl'] ?? ''}';
    final sha = '${j['sha256'] ?? ''}'.toLowerCase();
    if (code <= 0 || url.isEmpty || !_sha256.hasMatch(sha)) return null;
    return AppRelease(
      versionCode: code,
      versionName: '${j['versionName'] ?? ''}',
      notes: '${j['notes'] ?? ''}',
      sha256: sha,
      size: (j['size'] as num?)?.toInt() ?? 0,
      apkUrl: url,
    );
  }
}

/// The Android app's own updates, without an app store: asks the backend
/// whether a newer version is published, downloads it, checks it is exactly
/// the file that was published, and hands it to Android's installer. Signed
/// with the same key and numbered higher, it installs over this one.
class AppUpdates {
  AppUpdates({http.Client? client, this.baseUrl = functionsBaseUrl}) : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  static const _channel = MethodChannel('blujem/updates');

  /// Only Android installs its own updates; elsewhere the store does.
  bool get supported => !kIsWeb && Platform.isAndroid;

  /// A newer published version than this one, or null (none, or no connection).
  Future<AppRelease?> newer() async {
    if (!supported) return null;
    try {
      final installed = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      final response = await _http
          .post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/server/blujem_daily/execute/app-latest'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final release = AppRelease.tryParse(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
      return release != null && release.versionCode > installed ? release : null;
    } catch (e) {
      debugPrint('Could not check for an update: $e');
      return null;
    }
  }

  /// Downloads [release], reporting progress from 0 to 1, and gives the file
  /// once its size and checksum match what was published; null otherwise.
  Future<File?> download(AppRelease release, void Function(double) onProgress) async {
    final folder = Directory('${(await getTemporaryDirectory()).path}/updates');
    // Only one update is ever kept.
    if (await folder.exists()) await folder.delete(recursive: true);
    await folder.create(recursive: true);
    final file = File('${folder.path}/BluJem-${release.versionName}.apk');
    try {
      final response = await _http.send(http.Request('GET', Uri.parse(release.apkUrl)));
      if (response.statusCode != 200) return null;
      final total = release.size > 0 ? release.size : (response.contentLength ?? 0);
      final sink = file.openWrite();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var read = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        read += chunk.length;
        if (total > 0) onProgress(read / total);
      }
      await sink.close();
      hasher.close();
      if ((release.size > 0 && read != release.size) || '${digest.value}' != release.sha256) {
        await file.delete();
        return null;
      }
      return file;
    } catch (e) {
      debugPrint('Update download failed: $e');
      if (await file.exists()) await file.delete();
      return null;
    }
  }

  /// Opens Android's installer on a downloaded update.
  Future<void> install(File apk) => _channel.invokeMethod('install', {'path': apk.path});
}

/// Keeps the one digest a chunked hash produces.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
