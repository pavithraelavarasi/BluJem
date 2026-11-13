import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:zcatalyst_sdk/zcatalyst_sdk.dart';

/// Signing in through Catalyst's hosted page, whose Zoho and Google buttons
/// are set up in the Catalyst console. The result is a Zoho OAuth token for
/// [AuthRepository] to trade for a BluJem session.
///
/// The Catalyst SDK is native on Android and iOS only; macOS players use
/// email and password, which work on every platform.
abstract class SocialSignIn {
  bool get available;

  /// The access token, or null when the player cancelled.
  Future<String?> signIn();

  Future<void> signOut();
}

class CatalystSignIn implements SocialSignIn {
  bool _ready = false;

  /// Starts the SDK from the console-issued config file bundled with the app
  /// (`app_configuration_development.properties` on Android,
  /// `AppConfigurationDevelopment.plist` on iOS). Fails quietly: the email
  /// form still works without it.
  Future<void> start() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await ZCatalystApp.init(environment: ZCatalystEnvironment.DEVELOPMENT);
      _ready = true;
    } catch (e) {
      debugPrint('Catalyst SDK did not start: $e');
    }
  }

  @override
  bool get available => _ready;

  @override
  Future<String?> signIn() async {
    if (!_ready) throw Exception('Zoho and Google sign-in are not available here.');
    final app = ZCatalystApp.getInstance();
    try {
      await app.login();
    } on ZCatalystException catch (e) {
      debugPrint('Catalyst login: ${e.code} $e');
      // Closing the sheet is a cancel, not a failure: Android says "cancel",
      // iOS reports Zoho error 205, "WKWebView Closed".
      final text = '${e.code} $e'.toLowerCase();
      if (text.contains('cancel') || text.contains('webview closed') || text.contains('code=205')) return null;
      rethrow;
    }
    if (!await app.isUserLoggedIn()) return null;
    final token = await app.getAccessToken();
    if (token.isEmpty) throw Exception('Signed in, but no token came back.');
    return token;
  }

  @override
  Future<void> signOut() async {
    if (!_ready) return;
    try {
      if (await ZCatalystApp.getInstance().isUserLoggedIn()) {
        await ZCatalystApp.getInstance().logout();
      }
    } catch (e) {
      debugPrint('Catalyst sign-out: $e');
    }
  }
}

/// No social sign-in: tests, and platforms without the Catalyst SDK.
class NoSocialSignIn implements SocialSignIn {
  const NoSocialSignIn();

  @override
  bool get available => false;

  @override
  Future<String?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}
