/// Filters payment history rows for meal pack resize (upgrade pay + downgrade credit).
List<Map<String, dynamic>> filterMealSizeUpgradePayments(List<dynamic> payments) {
  final out = <Map<String, dynamic>>[];
  for (final raw in payments) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final type = (m['order_type'] ?? m['orderType'] ?? m['payment_type'] ?? '')
        .toString()
        .toLowerCase();
    if (type == 'meal_size_upgrade' || type == 'meal_size_downgrade') out.add(m);
  }
  return out;
}
