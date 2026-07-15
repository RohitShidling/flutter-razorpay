import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// SharedPreferences-backed cache for non-sensitive app data (lists, cart snapshot).
/// Do not store tokens, OTPs, or payment payloads here — use secure storage instead.
class _CacheEntry {
  final dynamic data;
  final int storedAt;
  final int? ttlSeconds;

  _CacheEntry({required this.data, required this.storedAt, this.ttlSeconds});

  Map<String, dynamic> toJson() => {
        'data': data,
        'storedAt': storedAt,
        if (ttlSeconds != null) 'ttlSeconds': ttlSeconds,
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      data: json['data'],
      storedAt: json['storedAt'] as int,
      ttlSeconds: json['ttlSeconds'] as int?,
    );
  }

  bool get isExpired {
    if (ttlSeconds == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - storedAt;
    return age > ttlSeconds! * 1000;
  }
}

class CacheStore {
  CacheStore._();

  static const _prefix = 'cache:';

  static String _k(String key) => '$_prefix$key';

  static Future<void> setJson(
    String key,
    Object? value, {
    Duration? ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_k(key));
      return;
    }
    final entry = _CacheEntry(
      data: value,
      storedAt: DateTime.now().millisecondsSinceEpoch,
      ttlSeconds: ttl?.inSeconds,
    );
    await prefs.setString(_k(key), jsonEncode(entry.toJson()));
  }

  static Future<dynamic> getJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(decoded);
      if (entry.isExpired) {
        if (!NetworkStatusService.instance.isOnline) {
          return entry.data;
        }
        await prefs.remove(_k(key));
        return null;
      }
      return entry.data;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = await getJson(key);
    if (raw is List) {
      return raw.whereType<Map>().map((j) => Map<String, dynamic>.from(j)).toList();
    }
    return [];
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(key));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) {
      return k.startsWith(_prefix) ||
          k.startsWith('cache_') ||
          k == 'bulk_delivery_address_v1';
    }).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

