import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Registers the current device with Firebase Cloud Messaging so the backend
/// Cloud Functions can deliver push notifications for the group creation
/// request lifecycle (submitted / pending approval / approved / rejected) and
/// the Space join request lifecycle.
///
/// Tokens are persisted in the `fcmTokens/{userId}` Firestore collection,
/// which the Cloud Functions read (with the Admin SDK, bypassing security
/// rules) to resolve the recipient device for each user.
///
/// Every call is best-effort and bounded by a timeout: FCM is unavailable on
/// some platforms (e.g. desktop) or unconfigured (e.g. a missing web VAPID
/// key / service worker), and must never block or stall the startup / auth
/// flow.
///
/// Notifications received while the app is in the foreground are displayed
/// through [FlutterLocalNotificationsPlugin] (FCM only surfaces foreground
/// messages via `onMessage`; it does not draw them automatically). The local
/// notification channel also guarantees the message is visible on Android 8+
/// once `POST_NOTIFICATIONS` is granted on Android 13+.
class FcmMessagingService {
  static const String _channelId = 'hissa_notifications';
  static const String _channelName = 'Hissa notifications';
  static const String _channelDescription =
      'Group creation requests and space join updates';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function()? _onGroupRequestTap;

  /// Sets up notification display (channel + foreground handler) and wires the
  /// notification-tap deep link. Safe to call once per app launch.
  static Future<void> init({required void Function() onGroupRequestTap}) async {
    _onGroupRequestTap = onGroupRequestTap;
    await _initLocalNotifications();
    _wireMessageHandlers();
  }

  static Future<void> _initLocalNotifications() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == 'group_request') {
            _onGroupRequestTap?.call();
          }
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    } catch (_) {
      // Unsupported platform; foreground display is simply disabled.
    }
  }

  static void _wireMessageHandlers() {
    // Foreground messages are not drawn by FCM itself: display them locally.
    try {
      FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showLocalNotification(message));
      });
    } catch (_) {
      // Unsupported platform.
    }
    // Background/terminated messages are drawn by FCM; tapping one deep-links.
    try {
      FirebaseMessaging.onMessageOpenedApp
          .where((message) => message.data['type'] == 'group_request')
          .listen(
            (_) => _onGroupRequestTap?.call(),
            onError: (_) {
              // Unsupported platform; deep-linking is simply disabled.
            },
          );
    } catch (_) {
      // Unsupported platform; deep-linking is simply disabled.
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;
      await _localNotifications.show(
        id: _notificationId(message),
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['type'],
      );
    } catch (_) {
      // Best-effort: a failed display should never crash the handler.
    }
  }

  /// A stable id per notification type so a new notification replaces the
  /// previous one of the same kind instead of stacking duplicates.
  static int _notificationId(RemoteMessage message) {
    return switch (message.data['type']) {
      'space_join_request' => 2,
      'member_invite' => 3,
      _ => 1,
    };
  }

  /// Requests notification permission, persists the current FCM token for
  /// [userId] and keeps it fresh when the token rotates.
  static Future<void> register({required String userId}) async {
    try {
      await FirebaseMessaging.instance.requestPermission().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Permission denial or an unsupported platform is non-fatal; the user
      // simply receives no pushes.
    }
    await _persistToken(userId);
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        unawaited(_persistToken(userId));
      });
    } catch (_) {
      // Unsupported platform.
    }
  }

  static Future<void> _persistToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 10),
      );
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort: a failed token write should never break sign-in.
    }
  }
}
