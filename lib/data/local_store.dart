import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app keeps on the device: small values in preferences, and a
/// folder for downloaded sheets and the cached puzzle list.
class LocalStore {
  LocalStore._(this._prefs, this.directory);

  final SharedPreferences _prefs;

  /// App-private folder for sheets and the puzzle cache.
  final Directory directory;

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/blujem');
    await dir.create(recursive: true);
    return LocalStore._(prefs, dir);
  }

  /// For tests: preferences already mocked, files under [dir].
  static Future<LocalStore> forTest(Directory dir) async => LocalStore._(await SharedPreferences.getInstance(), dir);

  Map<String, dynamic>? readJson(String key) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic>? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, jsonEncode(value));

  bool flag(String key, {bool fallback = false}) => _prefs.getBool(key) ?? fallback;

  Future<void> setFlag(String key, bool value) => _prefs.setBool(key, value);

  Directory folder(String name) {
    final dir = Directory('${directory.path}/$name');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
