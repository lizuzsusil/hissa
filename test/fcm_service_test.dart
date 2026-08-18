import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/services/fcm_service.dart';

/// Device-token identity: each installation owns a stable device id so FCM
/// tokens can be stored per device (`fcmTokens/{userId}/tokens/{deviceId}`)
/// instead of one overwritten token per user.
void main() {
  test('the device id is stable for the lifetime of an installation', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = await FcmMessagingService.getOrCreateDeviceId();
    final again = await FcmMessagingService.getOrCreateDeviceId();
    expect(again, first);
  });

  test('a fresh installation gets a distinct device id', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final first = await FcmMessagingService.getOrCreateDeviceId();

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final second = await FcmMessagingService.getOrCreateDeviceId();

    expect(second, isNot(first));
  });

  test('the device id is a 128-bit hex string', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final id = await FcmMessagingService.getOrCreateDeviceId();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}