import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/utils/error_handler.dart';

class MenuProvider with ChangeNotifier {
  final DioClient _dioClient;
  final LocalCache _cache;
  static const _todayCacheKey = 'cache_today_menu_v1';
  static const _weeklyCacheKey = 'cache_weekly_menu_v3';
  static const _legacyWeeklyCacheKey = 'cache_weekly_menu_v2';

  MenuProvider(this._dioClient, this._cache) {
    _loadCachedTodayMenu();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  Map<String, dynamic>? _todayMenu;
  Map<String, dynamic>? get todayMenu => _todayMenu;

  List<dynamic> _weeklyMenu = [];
  List<dynamic> get weeklyMenu => _weeklyMenu;

  List<dynamic> _subscriptionSummary = [];
  List<dynamic> get subscriptionSummary => _subscriptionSummary;

  String? _error;
  String? get error => _error;

  String? _homeMealMessage;
  String? get homeMealMessage => _homeMealMessage;

  bool _hasInitiallyLoaded = false;
  bool get hasInitiallyLoaded => _hasInitiallyLoaded;

  // TTL guards — avoids redundant API calls on repeated screen opens
  DateTime? _lastWeeklyFetchedAt;
  DateTime? _lastTodayFetchedAt;

  bool _isWeeklyFresh() =>
      _lastWeeklyFetchedAt != null &&
      DateTime.now().difference(_lastWeeklyFetchedAt!).inMinutes < 60;

  bool _isTodayFresh() =>
      _lastTodayFetchedAt != null &&
      DateTime.now().difference(_lastTodayFetchedAt!).inMinutes < 10;

  String _normalizeDateKey(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return '';
    return value.contains('T') ? value.split('T').first : value;
  }

  /// Nutrition rows sometimes use alternate column names (`date`, `nutrition_date`, …).
  String _nutritionRowDateKey(dynamic row) {
    if (row is! Map) return '';
    final d = row['menu_date'] ?? row['date'] ?? row['nutrition_date'] ?? row['for_date'] ?? row['target_date'];
    return _normalizeDateKey(d);
  }

  /// Menu rows may expose `delivery_date`, etc.—keep keys aligned with nutrition API.
  String _menuRowDateKey(Map<String, dynamic> menu) {
    final d = menu['menu_date'] ?? menu['date'] ?? menu['delivery_date'] ?? menu['for_date'];
    return _normalizeDateKey(d);
  }

  List<String> _extractNutrition(dynamic value) {
    if (value is List) {
      return value
          .map((e) {
            if (e is Map) {
              final text = e['nutrition_text'] ?? e['text'] ?? e['point'] ?? e['label'] ?? e['name'];
              return text?.toString() ?? '';
            }
            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return [];

      if ((raw.startsWith('[') && raw.endsWith(']')) ||
          (raw.startsWith('{') && raw.endsWith('}'))) {
        try {
          final normalized = raw.startsWith('{')
              ? '[${raw.substring(1, raw.length - 1).split(',').map((e) => jsonEncode(e.trim())).join(',')}]'
              : raw;
          final decoded = jsonDecode(normalized);
          return _extractNutrition(decoded);
        } catch (_) {
          // Fall through to plain-text handling below.
        }
      }

      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> _prefetchWeeklyMenuImages(List<dynamic> menus) async {
    final manager = DefaultCacheManager();
    for (final entry in menus) {
      if (entry is! Map) continue;
      final url = entry['image_url']?.toString();
      if (url == null || url.isEmpty) continue;
      try {
        await manager.downloadFile(url);
      } catch (_) {}
    }
  }

  Future<void> _loadCachedTodayMenu() async {
    try {
      final cached = await CacheStore.getJson('today_menu');
      if (cached is Map<String, dynamic>) {
        _isSubscribed = cached['is_subscribed'] ?? false;
        if (_isSubscribed) {
          _todayMenu = cached['menu'] != null ? Map<String, dynamic>.from(cached['menu']) : null;
          _subscriptionSummary = cached['subscription_summary'] ?? [];
        }
        _homeMealMessage = cached['message']?.toString();
        _hasInitiallyLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> fetchTodayMenu({bool silent = false, bool force = false}) async {
    // Skip if data is fresh and caller is not forcing a refresh
    if (!force && _todayMenu != null && _isTodayFresh()) return;

    if (!silent) {
      if (_todayMenu == null) _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final mealResponse = await _dioClient.dio.get('/api/client/meals/today');
      final data = mealResponse.data;
      _isSubscribed = data['is_subscribed'] ?? false;
      if (_isSubscribed) {
        if (data['menu'] is Map<String, dynamic>) {
          final menu = Map<String, dynamic>.from(data['menu']);
          List<String> nutritionPoints = [];
          try {
            final nutritionResponse = await _dioClient.dio.get(ApiEndpoints.clientMenuNutritionToday);
            final nutritionData = nutritionResponse.data;
            nutritionPoints = _extractNutrition(nutritionData['data']?['nutrition_points']);
          } catch (_) {
            // Keep menu working even if nutrition endpoint fails temporarily.
          }
          menu['nutrition_points'] = nutritionPoints;
          _todayMenu = menu;
        } else {
          _todayMenu = null;
        }
        _subscriptionSummary = data['subscription_summary'] ?? [];
        await _cache.saveJson(_todayCacheKey, {
          'is_subscribed': _isSubscribed,
          'menu': _todayMenu,
          'subscription_summary': _subscriptionSummary,
        });
      } else {
        _todayMenu = null;
        _subscriptionSummary = [];
      }
      _homeMealMessage = data['message']?.toString();
      _lastTodayFetchedAt = DateTime.now();
      // Cache the response structure
      await CacheStore.setJson('today_menu', {
        'is_subscribed': _isSubscribed,
        'menu': _todayMenu,
        'subscription_summary': _subscriptionSummary,
        'message': _homeMealMessage,
      }, ttl: const Duration(hours: 6));
      _hasInitiallyLoaded = true;
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
        _todayMenu = null;
        _subscriptionSummary = [];
        await CacheStore.remove('today_menu');
      } else {
        _error = ErrorHandler.getErrorMessage(e);
        // Keep cached data on network error
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Opens from cache when available, then refreshes from network if stale.
  Future<void> fetchWeeklyMenuSilent({bool forceRefresh = false}) async {
    // If data is already in memory and fresh, skip API entirely
    if (!forceRefresh && _weeklyMenu.isNotEmpty && _isWeeklyFresh()) return;

    if (!forceRefresh) {
      final cached = await _cache.loadJson(_weeklyCacheKey);
      if (cached != null && _weeklyMenu.isEmpty) {
        _applyWeeklyCache(cached);
        notifyListeners();
      }
    }

    final showSkeleton = _weeklyMenu.isEmpty;
    if (showSkeleton) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    await fetchWeeklyMenu(silent: !showSkeleton, forceRefresh: forceRefresh);
  }

  void _applyWeeklyCache(Map<String, dynamic> cached) {
    _isSubscribed = cached['is_subscribed'] == true;
    _weeklyMenu = (cached['menu'] as List? ?? const []).toList();
    _subscriptionSummary = (cached['subscription_summary'] as List? ?? const []).toList();
  }

  Future<void> fetchWeeklyMenu({bool silent = false, bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.loadJson(_weeklyCacheKey);
      if (cached != null && _weeklyMenu.isEmpty) {
        _applyWeeklyCache(cached);
        notifyListeners();
      }
    } else {
      await _cache.remove(_legacyWeeklyCacheKey);
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final mealResponse = await _dioClient.dio.get('/api/client/meals/weekly');
      final data = mealResponse.data;
      _isSubscribed = data['is_subscribed'] ?? false;
      if (_isSubscribed) {
        final weeklyMenus = (data['menu'] as List?) ?? [];
        final nutritionByDate = <String, List<String>>{};
        try {
          final nutritionResponse = await _dioClient.dio.get(ApiEndpoints.clientMenuNutritionWeekly);
          final nutritionData = nutritionResponse.data;
          final nutritionRows = (nutritionData['data'] as List?) ?? [];
          for (final row in nutritionRows) {
            if (row is! Map) continue;
            final rowMap = row is Map<String, dynamic> ? row : Map<String, dynamic>.from(row);
            final menuDate = _nutritionRowDateKey(rowMap);
            if (menuDate.isNotEmpty) {
              nutritionByDate[menuDate] = _extractNutrition(rowMap['nutrition_points']);
            }
          }
        } catch (_) {
          // Keep weekly menu working even if nutrition endpoint fails temporarily.
        }

        _weeklyMenu = weeklyMenus.map((entry) {
          if (entry is! Map) return entry;
          final menu = entry is Map<String, dynamic> ? Map<String, dynamic>.from(entry) : Map<String, dynamic>.from(entry);
          final menuDate = _menuRowDateKey(menu);
          final embedded = _extractNutrition(menu['nutrition_points']);
          final overlay = nutritionByDate[menuDate] ?? <String>[];
          final combined = <String>{...embedded, ...overlay}.toList();
          menu['nutrition_points'] = combined;
          return menu;
        }).toList();
        _subscriptionSummary = data['subscription_summary'] ?? [];
        _lastWeeklyFetchedAt = DateTime.now();
        await _cache.saveJson(_weeklyCacheKey, {
          'is_subscribed': _isSubscribed,
          'menu': _weeklyMenu,
          'subscription_summary': _subscriptionSummary,
        });
        // Warm disk cache so weekly images still appear offline later.
        await _prefetchWeeklyMenuImages(_weeklyMenu);
      } else {
        _weeklyMenu = [];
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
        _weeklyMenu = [];
        await _cache.remove(_weeklyCacheKey);
      } else {
        // Keep showing cached weekly menu when offline / flaky network.
        _error = _weeklyMenu.isEmpty ? ErrorHandler.getErrorMessage(e) : null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearState() {
    _isSubscribed = false;
    _todayMenu = null;
    _weeklyMenu = [];
    _subscriptionSummary = [];
    _homeMealMessage = null;
    _lastWeeklyFetchedAt = null;
    _lastTodayFetchedAt = null;
    _hasInitiallyLoaded = false;
    _error = null;
    notifyListeners();
  }
}
