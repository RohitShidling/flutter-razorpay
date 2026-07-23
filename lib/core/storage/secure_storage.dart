import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage()
      : _storage = const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
            synchronizable: false,
          ),
          aOptions: AndroidOptions(
            // encryptedSharedPreferences is deprecated in newer flutter_secure_storage and can be removed
          ),
        );

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const String _themeKey = 'theme_mode';
  static const String _phoneKey = 'phone_number';
  static const String _usernameKey = 'cached_username';

  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (e) {
      try {
        await _storage.delete(key: _accessTokenKey);
        await _storage.delete(key: _refreshTokenKey);
        await _storage.write(key: _accessTokenKey, value: accessToken);
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      } catch (_) {
        // Swallow exception so it doesn't block the login flow.
      }
    }
  }

  Future<void> savePhoneNumber(String phone) async {
    try {
      await _storage.write(key: _phoneKey, value: phone);
    } catch (e) {
      try {
        await _storage.delete(key: _phoneKey);
        await _storage.write(key: _phoneKey, value: phone);
      } catch (_) {}
    }
  }

  Future<String?> getPhoneNumber() async {
    return await _storage.read(key: _phoneKey);
  }

  Future<void> saveUsername(String username) async {
    try {
      await _storage.write(key: _usernameKey, value: username);
    } catch (e) {
      try {
        await _storage.delete(key: _usernameKey);
        await _storage.write(key: _usernameKey, value: username);
      } catch (_) {}
    }
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    _cachedAccessToken = await _storage.read(key: _accessTokenKey);
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
    return _cachedRefreshToken;
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _usernameKey);
  }

  Future<void> saveTheme(String theme) async {
    await _storage.write(key: _themeKey, value: theme);
  }

  Future<String?> getTheme() async {
    return await _storage.read(key: _themeKey);
  }
}

