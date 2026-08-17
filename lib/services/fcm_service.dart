import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers the current device with Firebase Cloud Messaging so the backend
/// Cloud Functions can deliver push notifications for the group creation
/// request lifecycle (submitted / pending approval / approved / rejected).
///
/// Tokens are persisted in the `fcmTokens/{userId}` Firestore collection,
/// which the Cloud Functions read (with the Admin SDK, bypassing security
/// rules) to resolve the recipient device for each user.
///
/// Every call is best-effort and bounded by a timeout: FCM is unavailable on
/// some platforms (e.g. desktop) or unconfigured (e.g. a missing web VAPID
/// key / service worker), and must never block or stall the startup / auth
/// flow.
class FcmMessagingService {
  /// Requests notification permission, persists the current FCM token for
  /// [userId] and keeps it fresh when the token rotates.
  static Future<void> register({required String userId}) async {
    try {
      await FirebaseMessaging.instance
          .requestPermission()
          .timeout(const Duration(seconds: 5));
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

  /// Wires up notification tap handling. Group request lifecycle
  /// notifications invoke [onGroupRequestTap] so the requester can follow the
  /// request's outcome (deep-linked by the app shell).
  static void configureTapHandling({
    required void Function() onGroupRequestTap,
  }) {
    try {
      FirebaseMessaging.onMessageOpenedApp
          .where((message) => message.data['type'] == 'group_request')
          .listen(
        (_) => onGroupRequestTap(),
        onError: (_) {
          // Unsupported platform; deep-linking is simply disabled.
        },
      );
    } catch (_) {
      // Unsupported platform; deep-linking is simply disabled.
    }
  }

  static Future<void> _persistToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10));
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc(userId)
          .set({
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort: a failed token write should never break sign-in.
    }
  }
}