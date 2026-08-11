import 'package:flutter/foundation.dart';

/// Shared tab index for the bottom navigation so nested screens
/// (e.g. dashboard) can switch tabs.
class ShellTabController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void switchTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}
