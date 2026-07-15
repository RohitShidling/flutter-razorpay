import 'package:meal_app/core/utils/meal_date.dart';

/// Normalizes `/api/client/subscriptions/status` payloads so all Flutter
/// consumers see the same shape regardless of minor API/caching quirks.
class SubscriptionStatusNormalizer {
  SubscriptionStatusNormalizer._();

  static bool _truthy(dynamic v) {
    if (v == true || v == 1) return true;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == 't' || s == '1' || s == 'yes';
    }
    return false;
  }

  static int _remaining(Map<String, dynamic> row) {
    final r = row['remaining_meals'];
    if (r is int) return r;
    if (r is num) return r.toInt();
    return int.tryParse(r?.toString() ?? '') ?? 0;
  }

  static String? _ymd(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.length >= 10) return s.substring(0, 10);
    return null;
  }

  /// Active window: paid flag, meals left, and calendar today within [start, end].
  static bool rowIsServingToday(Map<String, dynamic> row, String todayYmd) {
    if (!_truthy(row['subscription_status'] ?? row['is_active'])) return false;
    final remaining = _remaining(row);
    if (remaining <= 0) return false;
    final start = _ymd(row['start_date']);
    if (start != null && start.compareTo(todayYmd) > 0) return false;
    return true;
  }

  /// Paid / active row but service window starts after today.
  static bool rowIsUpcoming(Map<String, dynamic> row, String todayYmd) {
    if (!_truthy(row['subscription_status'] ?? row['is_active'])) return false;
    final remaining = _remaining(row);
    if (remaining <= 0) return false;
    final start = _ymd(row['start_date']);
    if (start == null) return false;
    if (start.compareTo(todayYmd) <= 0) return false;
    return true;
  }

  static Map<String, dynamic> normalize(dynamic raw) {
    if (raw is! Map) {
      return {
        'success': false,
        'has_active_subscription': false,
        'has_upcoming_subscription': false,
        'data': <Map<String, dynamic>>[],
        'entities': <Map<String, dynamic>>[],
        'alerts': [],
        'notifications': [],
      };
    }
    final map = Map<String, dynamic>.from(raw);
    final today = MealDate.sessionTodayYmd();

    List<dynamic> rawList = const [];
    final inner = map['data'];
    if (inner is List) {
      rawList = inner;
    } else if (inner is Map) {
      final m = Map<String, dynamic>.from(inner);
      if (m['subscriptions'] is List) {
        rawList = m['subscriptions'] as List;
      } else if (m['entities'] is List) {
        rawList = m['entities'] as List;
      }
    }

    final entities = <Map<String, dynamic>>[];
    for (final e in rawList) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final et = row['entity_type']?.toString() ?? '';
      final eid = row['entity_id']?.toString() ?? '';
      final activeFlag = _truthy(row['subscription_status'] ?? row['is_active']);
      row['entity_type'] = et;
      row['entity_id'] = eid;
      row['subscription_status'] = activeFlag;
      entities.add(row);
    }

    var hasActive = entities.any((r) => rowIsServingToday(r, today));
    var hasUpcoming = entities.any((r) => rowIsUpcoming(r, today));

    if (map['has_active_subscription'] == true) {
      hasActive = true;
    }
    if (map['has_upcoming_subscription'] == true) {
      hasUpcoming = true;
    }

    return {
      ...map,
      'data': entities,
      'entities': entities,
      'has_active_subscription': hasActive,
      'has_upcoming_subscription': hasUpcoming,
    };
  }

  /// Whether [entityType]/[entityId] has a serving or upcoming subscription row.
  static bool entityHasSubscription(
    Map<String, dynamic>? statusMap,
    String entityType,
    String entityId, {
    bool includeUpcoming = true,
  }) {
    if (statusMap == null) return false;
    final list = statusMap['entities'] is List
        ? statusMap['entities'] as List
        : (statusMap['data'] is List ? statusMap['data'] as List : const []);
    final today = MealDate.sessionTodayYmd();
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      if (row['entity_type']?.toString() != entityType) continue;
      if (row['entity_id']?.toString() != entityId.toString()) continue;
      if (rowIsServingToday(row, today)) return true;
      if (includeUpcoming && rowIsUpcoming(row, today)) return true;
    }
    return false;
  }

  /// Profile meal size id from subscription status row, if present.
  static int? profileMealSizeIdForEntity(
    Map<String, dynamic>? statusMap,
    String entityType,
    String entityId,
  ) {
    if (statusMap == null) return null;
    final list = statusMap['entities'] is List
        ? statusMap['entities'] as List
        : (statusMap['data'] is List ? statusMap['data'] as List : const []);
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      if (row['entity_type']?.toString() != entityType) continue;
      if (row['entity_id']?.toString() != entityId.toString()) continue;
      final id = row['profile_meal_size_id'] ?? row['meal_size_id'];
      return int.tryParse('$id');
    }
    return null;
  }

  static bool accountHasActive(Map<String, dynamic>? statusMap) {
    if (statusMap == null) return false;
    return statusMap['has_active_subscription'] == true;
  }

  /// True when any entity is upcoming and none are serving today.
  static bool accountHasOnlyUpcoming(Map<String, dynamic>? statusMap) {
    if (statusMap == null) return false;
    final hasUpcoming = statusMap['has_upcoming_subscription'] == true;
    return hasUpcoming && !accountHasActive(statusMap);
  }

  /// Earliest `start_date` among upcoming (not yet serving) subscription rows.
  static String? earliestUpcomingStartYmd(Map<String, dynamic>? statusMap) {
    if (statusMap == null) return null;
    final list = statusMap['entities'] is List
        ? statusMap['entities'] as List
        : (statusMap['data'] is List ? statusMap['data'] as List : const []);
    final today = MealDate.sessionTodayYmd();
    String? earliest;
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      if (!rowIsUpcoming(row, today)) continue;
      final start = _ymd(row['start_date']);
      if (start == null) continue;
      if (earliest == null || start.compareTo(earliest) < 0) {
        earliest = start;
      }
    }
    return earliest;
  }

  /// `'active'` | `'upcoming'` | `'none'`.
  static String entityPlanState(
    Map<String, dynamic>? statusMap,
    String entityType,
    String entityId,
  ) {
    if (statusMap == null) return 'none';
    final list = statusMap['entities'] is List
        ? statusMap['entities'] as List
        : (statusMap['data'] is List ? statusMap['data'] as List : const []);
    final today = MealDate.sessionTodayYmd();
    var serving = false;
    var upcoming = false;
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      if (row['entity_type']?.toString() != entityType) continue;
      if (row['entity_id']?.toString() != entityId.toString()) continue;
      if (rowIsServingToday(row, today)) serving = true;
      if (rowIsUpcoming(row, today)) upcoming = true;
    }
    if (serving) return 'active';
    if (upcoming) return 'upcoming';
    return 'none';
  }
}
