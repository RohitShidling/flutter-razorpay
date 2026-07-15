import 'package:flutter/material.dart';
import 'package:meal_app/core/storage/secure_storage.dart';

class ThemeProvider with ChangeNotifier {
  final SecureStorage _secureStorage;
  bool _isDarkMode = false;

  ThemeProvider(this._secureStorage) {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _loadTheme() async {
    final storedTheme = await _secureStorage.getTheme();
    _isDarkMode = storedTheme == 'dark';
    // AUDIT-050 fix: defer notifyListeners to post-frame to avoid build-phase crash
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> toggleTheme(bool isOn) async {
    _isDarkMode = isOn;
    await _secureStorage.saveTheme(isOn ? 'dark' : 'light');
    notifyListeners();
  }
}
