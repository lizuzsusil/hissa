import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the "log in with biometrics" preference and wraps `local_auth`.
///
/// When [enabled], the app gates the shell behind a device biometric prompt
/// on launch instead of showing the password login. The flag itself is a
/// device-local preference; no credentials are ever stored.
class BiometricAuthController extends ChangeNotifier {
  static const String _prefKey = 'hissa_biometric_enabled_v1';

  final LocalAuthentication _auth = LocalAuthentication();
  bool _enabled = false;
  bool _supported = false;

  bool get enabled => _enabled;

  /// Whether this device has biometric hardware and can check it. Used to
  /// hide biometric options entirely on unsupported devices.
  bool get supported => _supported;

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    _enabled = await prefs.getBool(_prefKey) ?? false;
    _supported = await _checkDeviceSupport();
    notifyListeners();
  }

  Future<bool> _checkDeviceSupport() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Returns `null` when biometrics can be used right now, otherwise a short
  /// reason key ('notSupported' | 'notEnrolled') that callers map to a
  /// localized message.
  Future<String?> availabilityIssue() async {
    try {
      if (!await _auth.isDeviceSupported()) return 'notSupported';
      if (!await _auth.canCheckBiometrics) return 'notSupported';
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty) return 'notEnrolled';
      return null;
    } catch (_) {
      return 'notSupported';
    }
  }

  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth PlatformException: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Requires a successful scan before the preference is persisted.
  Future<bool> enable(String localizedReason) async {
    if (!_enabled && await availabilityIssue() != null) return false;
    final ok = await authenticate(localizedReason);
    if (!ok) return false;
    _enabled = true;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_prefKey, true);
    return true;
  }

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_prefKey, false);
  }
}
