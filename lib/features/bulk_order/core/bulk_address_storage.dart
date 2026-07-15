import 'dart:convert';

import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the client's saved bulk delivery address between sessions.
class BulkAddressStorage {
  BulkAddressStorage._();

  static const _key = 'bulk_delivery_address_v1';

  static Future<BulkDeliveryAddress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return BulkDeliveryAddress.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(BulkDeliveryAddress? address) async {
    final prefs = await SharedPreferences.getInstance();
    if (address == null || !address.isComplete) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(address.toJson()));
  }
}
