import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The Catalyst project's functions (BluJem, Development environment).
/// The same backend the Android and iOS apps use; nothing secret lives here.
const functionsBaseUrl = 'https://blujem-60093843442.development.catalystserverless.in';

/// The Catalyst functions the app calls.
enum JumbleFunction {
  auth('jumble_auth'),
  data('jumble_data'),
  ai('jumble_ai'),
  daily('blujem_daily');

  const JumbleFunction(this.path);
  final String path;
}

/// A failed call, with the server's own message when it gave one.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// The one way the app talks to its backend: `POST {base}/server/{fn}/execute/{route}`.
///
/// Our session token travels in X-Jumble-Token, never Authorization: Catalyst
/// reads Authorization itself and would reject our token before the function
/// runs. The single exception is the Zoho trade, which sends a real Zoho
/// OAuth token there on purpose.
class ApiClient {
  ApiClient({http.Client? http, this.baseUrl = functionsBaseUrl, this.token}) : _http = http ?? _defaultClient();

  final http.Client _http;
  final String baseUrl;

  /// Reads the signed-in session's token at call time.
  String? Function()? token;

  /// Called when the server refuses the session token (401), e.g. one issued
  /// by the old DailyJumble project, so the player is asked to sign in again.
  void Function()? onSessionRejected;

  static http.Client _defaultClient() => http.Client();

  bool get _hasToken => token?.call()?.isNotEmpty ?? false;

  Uri _uri(JumbleFunction fn, String route) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/server/${fn.path}/execute/$route');

  Map<String, String> _headers({String? authorization, bool withToken = true}) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': ?authorization,
    if (withToken && _hasToken) 'X-Jumble-Token': token!.call()!,
  };

  /// Posts [body] and returns the decoded JSON reply. Throws [ApiException].
  Future<Map<String, dynamic>> post(
    JumbleFunction fn,
    String route, {
    Map<String, dynamic> body = const {},
    String? authorization,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sentToken = authorization == null && _hasToken;
    final response = await _send(fn, route, body, authorization, timeout);
    if (sentToken && response.statusCode == 401) onSessionRejected?.call();
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json?['error'];
      debugPrint('$route failed (${response.statusCode}): ${text.length > 200 ? text.substring(0, 200) : text}');
      throw ApiException(
        error is String && error.isNotEmpty ? error : 'Request failed (${response.statusCode}).',
        status: response.statusCode,
      );
    }
    if (json == null) throw const ApiException('Unexpected reply from the server.');
    return json;
  }

  /// Like [post], but null instead of throwing: for calls whose failure the
  /// player never needs to hear about.
  Future<Map<String, dynamic>?> tryPost(JumbleFunction fn, String route, {Map<String, dynamic> body = const {}}) async {
    try {
      return await post(fn, route, body: body);
    } catch (e) {
      debugPrint('$route: $e');
      return null;
    }
  }

  /// Downloads a binary reply (a sheet image) into [destination], via a
  /// temporary file so a cut-off download is never taken for a whole one.
  Future<bool> download(JumbleFunction fn, String route, Map<String, dynamic> body, File destination) async {
    final partial = File('${destination.path}.part');
    try {
      final sentToken = _hasToken;
      final response = await _send(fn, route, body, null, const Duration(seconds: 60));
      if (sentToken && response.statusCode == 401) onSessionRejected?.call();
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return false;
      await partial.writeAsBytes(response.bodyBytes, flush: true);
      await partial.rename(destination.path);
      return true;
    } catch (e) {
      debugPrint('$route download: $e');
      if (await partial.exists()) await partial.delete();
      return false;
    }
  }

  Future<http.Response> _send(
    JumbleFunction fn,
    String route,
    Map<String, dynamic> body,
    String? authorization,
    Duration timeout,
  ) async {
    try {
      return await _http
          .post(
            _uri(fn, route),
            headers: _headers(authorization: authorization, withToken: authorization == null),
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on SocketException {
      throw const ApiException('Could not reach BluJem. Check your connection.');
    } on http.ClientException {
      throw const ApiException('Could not reach BluJem. Check your connection.');
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const ApiException('BluJem took too long to answer. Try again.');
      }
      rethrow;
    }
  }
}
