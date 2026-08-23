import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAccount {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;

  const BiometricAccount({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
      };

  factory BiometricAccount.fromJson(Map<String, dynamic> j) => BiometricAccount(
        uid: j['uid'] as String,
        name: j['name'] as String? ?? 'User',
        email: j['email'] as String? ?? '',
        avatarUrl: j['avatarUrl'] as String?,
      );
}

/// Holds per-user "log in with biometrics" preference and wraps `local_auth`.
///
/// v1 was a global bool; v2 is per-uid so User A enabling never unlocks User B.
/// The device biometrics never stores credentials — it only gates the locally
/// cached Firebase session for that specific uid.
class BiometricAuthController extends ChangeNotifier {
  static const String _legacyKey = 'hissa_biometric_enabled_v1';
  static const String _usersKey = 'hissa_biometric_users_v1';
  static const String _accountsKey = 'hissa_biometric_accounts_v1';

  final LocalAuthentication _auth = LocalAuthentication();
  bool _supported = false;
  Set<String> _enabledUids = {};
  Map<String, BiometricAccount> _accounts = {};

  bool get supported => _supported;

  /// Global: is any account enabled? (keeps old UI callers working)
  bool get enabled => _enabledUids.isNotEmpty;

  Set<String> get enabledUids => Set.unmodifiable(_enabledUids);
  List<BiometricAccount> get enabledAccounts =>
      _enabledUids.map((uid) => _accounts[uid]).whereType<BiometricAccount>().toList();

  bool isEnabledFor(String? uid) => uid != null && _enabledUids.contains(uid);

  /// The account that will be unlocked on launch — the Firebase current user if
  /// he is enabled, otherwise the last enabled account.
  BiometricAccount? get boundAccountForCurrentUser {
    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    if (fbUid != null && _accounts[fbUid] != null && _enabledUids.contains(fbUid)) {
      return _accounts[fbUid];
    }
    if (_enabledUids.isEmpty) return null;
    // Last enabled is last in list
    final last = _enabledUids.last;
    return _accounts[last];
  }

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    _supported = await _checkDeviceSupport();
    final list = await prefs.getStringList(_usersKey);
    _enabledUids = (list ?? []).toSet();
    final raw = await prefs.getString(_accountsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _accounts = {
          for (final e in decoded)
            (e as Map)['uid'] as String: BiometricAccount.fromJson(e as Map<String, dynamic>)
        };
      } catch (_) {}
    }
    // Migrate legacy global bool -> per-user if needed
    if (_enabledUids.isEmpty) {
      final legacy = await prefs.getBool(_legacyKey);
      if (legacy == true) {
        final fbUid = FirebaseAuth.instance.currentUser?.uid;
        if (fbUid != null) {
          _enabledUids = {fbUid};
          await prefs.setStringList(_usersKey, _enabledUids.toList());
        }
      }
    }
    notifyListeners();
  }

  Future<bool> _checkDeviceSupport() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

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
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth PlatformException: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  Future<void> saveAccount({
    required String uid,
    required String name,
    required String email,
    String? avatarUrl,
  }) async {
    _accounts[uid] = BiometricAccount(uid: uid, name: name, email: email, avatarUrl: avatarUrl);
    await _persistAccounts();
    notifyListeners();
  }

  /// Requires a successful scan before the preference is persisted for [uid].
  Future<bool> enableFor(String uid, String localizedReason) async {
    if (await availabilityIssue() != null) return false;
    final ok = await authenticate(localizedReason);
    if (!ok) return false;
    _enabledUids.add(uid);
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(_usersKey, _enabledUids.toList());
    notifyListeners();
    return true;
  }

  /// Back-compat: enable for current Firebase user
  Future<bool> enable(String localizedReason) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return enableFor(uid, localizedReason);
  }

  Future<void> disableFor(String uid) async {
    if (!_enabledUids.contains(uid)) return;
    _enabledUids.remove(uid);
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(_usersKey, _enabledUids.toList());
    notifyListeners();
  }

  Future<void> disable() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _enabledUids.contains(uid)) {
      await disableFor(uid);
    } else if (_enabledUids.isNotEmpty) {
      // Fallback: disable last enabled (old callers without uid)
      await disableFor(_enabledUids.last);
    }
  }

  Future<void> _persistAccounts() async {
    final prefs = SharedPreferencesAsync();
    final list = _accounts.values.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(list));
  }
}
