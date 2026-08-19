import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's explicitly chosen app language. When [locale] is `null`
/// the app follows the system locale instead.
class LocaleController extends ChangeNotifier {
  static const String _prefKey = 'locale';

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == null) return;
    final resolved = _parse(code);
    if (resolved != null) {
      _locale = resolved;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, locale.languageCode);
    }
  }

  Locale? _parse(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'ne':
        return const Locale('ne');
      default:
        return null;
    }
  }
}
