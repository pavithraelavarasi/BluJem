import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// "A new BluJem is out", pushed by the server the moment a puzzle opens:
/// when the admin publishes the morning or Sunday one, and at 3 PM and 9 PM for the
/// afternoon and night ones (catalyst/functions/jumble_data/lib/notify.js). Every phone
/// listens on one Firebase topic, so there is no device list to keep.
///
/// With the app closed or in the background, Android shows the notification
/// by itself. With it open, [onPuzzleOut] fetches the new puzzle and the
/// notification is shown here, since Firebase leaves that to the app.
class PuzzleReminders {
  PuzzleReminders({FlutterLocalNotificationsPlugin? plugin, this.onPuzzleOut})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Called when a puzzle comes out while the app is open, or is opened from
  /// its notification.
  final VoidCallback? onPuzzleOut;

  /// The server's FCM_TOPIC.
  static const topic = 'puzzles';

  static const _channel = AndroidNotificationChannel(
    'new_puzzle',
    'New puzzles',
    description: 'When the morning, afternoon, night and Sunday puzzles come out',
  );

  /// Asks for permission once (Android 13+ and iOS prompt only the first
  /// time) and listens for new puzzles. Never throws: notifications are a
  /// nicety, and without Firebase set up the app works as before.
  Future<void> start() async {
    if (kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      // 1.27.0 scheduled weekly reminders on the phone at 10 AM and 4 PM.
      // Nothing else is ever scheduled, so all of them go: nobody should be
      // told about a puzzle that is not out.
      await _plugin.cancelAllPendingNotifications();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notifications not set up: $e');
    }

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push is off (no Firebase config): $e');
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      if (defaultTargetPlatform == TargetPlatform.iOS && !await _apnsReady(messaging)) {
        debugPrint('Push not started: no APNs token');
        return;
      }
      await messaging.subscribeToTopic(topic);
      FirebaseMessaging.onMessage.listen(_showWhileOpen);
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onPuzzleOut?.call());
      if (await messaging.getInitialMessage() != null) onPuzzleOut?.call();
    } catch (e) {
      debugPrint('Push not started: $e');
    }
  }

  /// On iOS, Firebase can only join the topic once Apple has handed the phone
  /// its push token, which can take a few seconds after the first launch.
  static Future<bool> _apnsReady(FirebaseMessaging messaging) async {
    for (var i = 0; i < 15; i++) {
      if (await messaging.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<void> _showWhileOpen(RemoteMessage message) async {
    onPuzzleOut?.call();
    final note = message.notification;
    if (note == null) return;
    try {
      await _plugin.show(
        id: message.hashCode,
        title: note.title,
        body: note.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Could not show the notification: $e');
    }
  }
}
