import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles FCM delivery for Hissa. The actual push *send* is performed by the
/// push relay (a small server-side process reading the `notifications`
/// collection — never by the client, which does not hold any FCM credential).
///
/// This service only receives messages and routes taps:
/// - Foreground (`onMessage`) and background/terminated data messages
///   (`onBackgroundMessage`) are shown through
///   [FlutterLocalNotificationsPlugin] — FCM never draws data messages itself.
/// - Every tap funnels through [onDidReceiveNotificationResponse] /
///   [FirebaseMessaging.onMessageOpenedApp] / [getInitialMessage] into the
///   single [NotificationRouter] callback so deep links behave the same no
///   matter how the app was started.
///
/// Every call is best-effort and bounded by a timeout: FCM is unavailable on
/// some platforms (e.g. desktop) or unconfigured (e.g. a missing web VAPID
/// key), and must never block or stall the startup / auth flow.
class FcmMessagingService {
  static const String _channelId = 'hissa_notifications';
  static const String _channelName = 'Hissa notifications';
  static const String _channelDescription =
      'Expense, settlement, join and group request updates';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function(Map<String, dynamic> data)? _onTap;

  /// Sets up notification display (channel + handlers) and wires the
  /// notification-tap deep link. Safe to call once per app launch.
  static Future<void> init({required void Function(Map<String, dynamic> data) onTap}) async {
    _onTap = onTap;
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
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
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
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
    // A notification-message tap that brings a backgrounded app forward.
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleTap(message.data),
        onError: (_) {
          // Unsupported platform; deep-linking is simply disabled.
        },
      );
    } catch (_) {
      // Unsupported platform; deep-linking is simply disabled.
    }
  }

  /// The FCM message (if any) that opened a terminated app via a
  /// notification-message tap. Data-only messages opened through the local
  /// notification plugin instead arrive via [onDidReceiveNotificationResponse].
  static Future<Map<String, dynamic>?> getInitialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message?.data;
    } catch (_) {
      return null;
    }
  }

  /// Runs in a background isolate when a data message arrives while the app is
  /// in the background or terminated. Displays the notification locally so the
  /// user still sees it (Android only shows data messages through a background
  /// handler; it never draws them itself).
  @pragma('vm:entry-point')
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;
      if (data.isEmpty && notification == null) return;
      await _localNotifications.show(
        id: _notificationId(data),
        title: notification?.title ?? _fallbackTitle(data),
        body: notification?.body ?? _fallbackBody(data),
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
        payload: jsonEncode(data),
      );
    } catch (_) {
      // Best-effort: a failed display should never crash the handler.
    }
  }

  static String? _fallbackTitle(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return 'Hissa';
    return switch (type) {
      'expenseAdded' => 'Expense added',
      'expenseUpdated' => 'Expense updated',
      'settlementRecorded' => 'Settlement recorded',
      'spaceInvited' => 'Space invitation',
      'spaceJoinRequested' => 'Join request',
      'spaceJoinApproved' => 'Join request approved',
      'spaceJoinRejected' => 'Join request declined',
      'groupRequested' => 'Group request',
      'groupApproved' => 'Group request approved',
      'groupRejected' => 'Group request declined',
      _ => 'Hissa',
    };
  }

  static String? _fallbackBody(Map<String, dynamic> data) {
    final actor = data['actorName'] as String?;
    final spaceId = data['spaceId'] as String?;
    if (spaceId != null) return '$actor · $spaceId';
    return actor;
  }

  /// A stable id per notification so a new notification replaces the previous
  /// one for the same event instead of stacking duplicates. FNV-1a over the
  /// deterministic `notificationId` (`{recipientId}_{eventKey}`).
  static int _notificationId(Map<String, dynamic> data) {
    final notificationId = data['notificationId'] as String?;
    final key = (notificationId ?? data['type'] ?? 'notification');
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toInt();
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleTap(data);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  static void _handleTap(Map<String, dynamic> data) {
    final onTap = _onTap;
    if (onTap == null || data.isEmpty) return;
    try {
      onTap(data);
    } catch (_) {
      // A routing failure must never crash the message handler.
    }
  }

  /// Requests notification permission, persists the current FCM token for
  /// [userId] and keeps it fresh when the token rotates. Best effort.
  static Future<void> register({required String userId}) async {
    try {
      await FirebaseMessaging.instance.requestPermission().timeout(
        const Duration(seconds: 5),
      );
      // Android 13+ requires the runtime notification permission for the local
      // plugin used to draw notifications, independently of FCM's permission.
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Permission denial or an unsupported platform is non-fatal; the user
      // simply receives no notifications.
    }
    await _persistToken(userId);
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(_persistToken(userId, token: token));
      });
    } catch (_) {
      // Unsupported platform.
    }
  }

  /// A stable per-installation device id, persisted so the same device keeps
  /// the same `fcmTokens/{userId}/tokens/{deviceId}` document across launches
  /// and token rotations. Injectable [prefs] is used by tests.
  static const String _deviceIdKey = 'hissa_device_id_v1';

  static Future<String> getOrCreateDeviceId([SharedPreferencesAsync? prefs]) async {
    final store = prefs ?? SharedPreferencesAsync();
    final existing = await store.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    await store.setString(_deviceIdKey, generated);
    return generated;
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// The platform this device runs on, stored on the token doc so the relay can
  /// target or clean up devices by platform.
  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  static Future<void> _persistToken(String userId, {String? token}) async {
    try {
      final resolved =
          token ??
          await FirebaseMessaging.instance.getToken().timeout(
            const Duration(seconds: 10),
          );
      if (resolved == null || resolved.isEmpty) return;
      final deviceId = await getOrCreateDeviceId();
      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .collection('tokens')
          .doc(deviceId)
          .set({
            'token': resolved,
            'platform': _platformName,
            'updatedAt': FieldValue.serverTimestamp(),
            'active': true,
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort: a failed token write should never break sign-in.
    }
  }
}