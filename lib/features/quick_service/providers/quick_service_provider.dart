import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/razorpay_service.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/quick_service/data/repositories/quick_service_repository.dart';
import 'package:meal_app/core/storage/cache_store.dart';

class QuickServiceProvider with ChangeNotifier {
  final QuickServiceRepository _repository;
  QuickServiceProvider(this._repository) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedConfig = await CacheStore.getJson('one_day_lunch_config');
      if (cachedConfig is Map<String, dynamic>) {
        _oneDayConfig = cachedConfig;
      }
      final cachedSpecial = await CacheStore.getJson('special_dish_config');
      if (cachedSpecial is Map<String, dynamic>) {
        _specialConfig = cachedSpecial;
      }
      final cachedCategories = await CacheStore.getJson('special_categories');
      if (cachedCategories is List) {
        _categories = cachedCategories;
      }
      notifyListeners();
    } catch (_) {}
  }

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  // TTL guards

  DateTime? _lastCategoriesFetchedAt;
  DateTime? _lastOneDayConfigFetchedAt;
  DateTime? _lastSpecialConfigFetchedAt;
  DateTime? _lastCartFetchedAt;
  final Map<String, DateTime> _lastItemsFetchedAt = {};

  bool _isCategoriesFresh() =>
      _lastCategoriesFetchedAt != null &&
      DateTime.now().difference(_lastCategoriesFetchedAt!).inHours < 6;

  bool _isOneDayConfigFresh() =>
      _lastOneDayConfigFetchedAt != null &&
      DateTime.now().difference(_lastOneDayConfigFetchedAt!).inMinutes < 2;

  bool _isSpecialConfigFresh() =>
      _lastSpecialConfigFetchedAt != null &&
      DateTime.now().difference(_lastSpecialConfigFetchedAt!).inHours < 6;

  bool _isItemsFresh(String categoryId) {
    final t = _lastItemsFetchedAt[categoryId];
    return t != null && DateTime.now().difference(t).inMinutes < 60;
  }

  bool _isCartFresh() =>
      _lastCartFetchedAt != null &&
      DateTime.now().difference(_lastCartFetchedAt!).inSeconds < 90;

  Map<String, dynamic>? _oneDayConfig;
  Map<String, dynamic>? get oneDayConfig => _oneDayConfig;

  Map<String, dynamic>? _specialConfig;
  Map<String, dynamic>? get specialConfig => _specialConfig;
  int get specialMinLeadDays => (specialConfig?['min_lead_days'] as num?)?.toInt() ?? 0;

  Map<String, dynamic>? _todayMenu;
  Map<String, dynamic>? get todayMenu => _todayMenu;

  List<dynamic> _categories = [];
  List<dynamic> get categories => _categories;

  List<dynamic> _items = [];
  List<dynamic> get items => _items;

  final Map<String, int> _cartQty = {};
  Map<String, int> get cartQty => Map.unmodifiable(_cartQty);

  int get cartItemCount => _cartQty.values.fold(0, (a, b) => a + b);

  final Map<String, Map<String, dynamic>> _itemCache = {};
  Map<String, Map<String, dynamic>> get itemCache => _itemCache;
  final Map<String, List<dynamic>> _categoryItemsMemoryCache = {};

  double get cartTotalAmount {
    double total = 0.0;
    for (final entry in _cartQty.entries) {
      final item = _itemCache[entry.key];
      if (item != null) {
        final price = double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
        total += price * entry.value;
      }
    }
    return total;
  }

  BulkDeliveryAddress? _address;
  BulkDeliveryAddress? get address => _address;

  void setAddress(BulkDeliveryAddress? value) {
    _address = value;
    notifyListeners();
  }

  Future<BulkDeliveryAddress?> loadSavedDeliveryAddress({bool force = false}) async {
    if (!force && _address != null) return _address;
    try {
      final data = await _repository.getSavedDeliveryAddress();
      if (data == null) return null;
      final address = BulkDeliveryAddress(
        id: data['id'] is int ? data['id'] as int : int.tryParse('${data['id']}'),
        stateId: int.tryParse('${data['state_id'] ?? data['stateId']}') ?? 0,
        cityId: int.tryParse('${data['city_id'] ?? data['cityId']}') ?? 0,
        addressLine: data['address_line']?.toString() ?? data['addressLine']?.toString() ?? '',
        pincode: data['pincode']?.toString(),
        stateName: data['state_name']?.toString() ?? data['stateName']?.toString(),
        cityName: data['city_name']?.toString() ?? data['cityName']?.toString(),
        deliveryTime: data['delivery_time']?.toString() ?? data['deliveryTime']?.toString(),
        phoneNumber: data['phone_number']?.toString() ?? data['phoneNumber']?.toString(),
        altPhoneNumber: data['alt_phone_number']?.toString() ?? data['altPhoneNumber']?.toString(),
        customerName: data['customer_name']?.toString() ?? data['customerName']?.toString(),
      );
      if (address.isComplete) {
        _address = address;
        notifyListeners();
        return address;
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadOneDayConfig({bool force = false}) async {
    if (!force && _oneDayConfig != null && _isOneDayConfigFresh()) return;

    if (_oneDayConfig == null) {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        final cached = await CacheStore.getJson('one_day_lunch_config');
        if (cached is Map<String, dynamic>) {
          _oneDayConfig = cached;
          notifyListeners();
        }
      } catch (_) {}
    }

    try {
      _oneDayConfig = await _repository.getOneDayLunchConfig();
      _lastOneDayConfigFetchedAt = DateTime.now();
      await CacheStore.setJson('one_day_lunch_config', _oneDayConfig, ttl: const Duration(minutes: 10));
      _error = null;
    } catch (e) {
      if (_oneDayConfig == null) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Public menu helpers (un-gated, for One Day Lunch screen) ────────────
  Future<Map<String, dynamic>?> fetchPublicMenuToday() =>
      _repository.getPublicMenuToday().catchError((_) => null);

  Future<List<dynamic>> fetchPublicMenuWeekly() =>
      _repository.getPublicMenuWeekly().catchError((_) => <dynamic>[]);

  Future<Map<String, dynamic>?> fetchPublicMenuByDate(String date) =>
      _repository.getPublicMenuByDate(date).catchError((_) => null);

  Future<void> loadSpecialConfig({bool force = false}) async {
    if (!force && _specialConfig != null && _isSpecialConfigFresh()) return;

    if (_specialConfig == null) {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        final cached = await CacheStore.getJson('special_dish_config');
        if (cached is Map<String, dynamic>) {
          _specialConfig = cached;
          notifyListeners();
        }
      } catch (_) {}
    }

    try {
      _specialConfig = await _repository.getSpecialDishConfig();
      _lastSpecialConfigFetchedAt = DateTime.now();
      await CacheStore.setJson('special_dish_config', _specialConfig, ttl: const Duration(hours: 6));
      _error = null;
    } catch (e) {
      if (_specialConfig == null) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setTodayMenu(Map<String, dynamic>? menu) {
    _todayMenu = menu;
    notifyListeners();
  }

  Future<void> loadCategories({bool force = false}) async {
    // Skip API if data is fresh in memory
    if (!force && _isCategoriesFresh()) return;

    if (_categories.isEmpty) {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        final cached = await CacheStore.getJson('special_categories');
        if (cached is List) {
          _categories = cached;
          notifyListeners();
        }
      } catch (_) {}
    }

    try {
      _categories = await _repository.getSpecialCategories();
      _lastCategoriesFetchedAt = DateTime.now();
      await CacheStore.setJson('special_categories', _categories, ttl: const Duration(hours: 6));
      _error = null;
    } catch (e) {
      if (_categories.isEmpty) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadItems(String categoryId, {bool force = false}) async {
    // Check memory cache first
    if (!force && _isItemsFresh(categoryId)) {
      final cached = _categoryItemsMemoryCache[categoryId];
      if (cached != null) {
        _items = cached;
        notifyListeners();
        return;
      }
    }

    _loading = true;
    _error = null;
    _items = [];
    
    // Check cache first
    try {
      final cachedItems = await CacheStore.getJson('special_items_$categoryId');
      if (cachedItems is List && _items.isEmpty) {
        _items = cachedItems;
        _categoryItemsMemoryCache[categoryId] = cachedItems;
        for (final item in _items) {
          final id = item['id']?.toString();
          if (id != null) {
            _itemCache[id] = Map<String, dynamic>.from(item);
          }
        }
        notifyListeners();
        if (!force && _isItemsFresh(categoryId)) {
          _loading = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}
    
    notifyListeners();
    try {
      _items = await _repository.getSpecialItems(categoryId);
      _categoryItemsMemoryCache[categoryId] = _items;
      for (final item in _items) {
        final id = item['id']?.toString();
        if (id != null) {
          _itemCache[id] = Map<String, dynamic>.from(item);
        }
      }
      _lastItemsFetchedAt[categoryId] = DateTime.now();
      await CacheStore.setJson('special_items_$categoryId', _items, ttl: const Duration(hours: 6));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCartFromServer({bool force = false}) async {
    if (!force && _isCartFresh()) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repository.getSpecialCart();
      final items = data['items'];
      _cartQty.clear();
      if (items is List) {
        for (final row in items) {
          if (row is Map) {
            final id = row['item_id']?.toString() ?? row['special_dish_item_id']?.toString();
            final qty = int.tryParse('${row['quantity']}') ?? 0;
            if (id != null && id.isNotEmpty && qty > 0) {
              _cartQty[id] = qty;
            }
          }
        }
      }
      if (_cartQty.isNotEmpty) {
        try {
          final allItems = await _repository.getSpecialItems('all');
          for (final item in allItems) {
            final id = item['id']?.toString();
            if (id != null) {
              _itemCache[id] = Map<String, dynamic>.from(item);
            }
          }
        } catch (_) {}
      }
      _lastCartFetchedAt = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCartQty(String itemId, int qty) {
    if (qty <= 0) {
      _cartQty.remove(itemId);
    } else {
      _cartQty[itemId] = qty;
    }
    _lastCartFetchedAt = DateTime.now();
    notifyListeners();
    _persistCart();
  }

  void clearCart() {
    _cartQty.clear();
    _lastCartFetchedAt = DateTime.now();
    notifyListeners();
    _persistCart();
  }

  Future<void> _persistCart() async {
    try {
      await _repository.saveSpecialCart({
        'items': _cartQty.entries.map((e) => {'item_id': e.key, 'quantity': e.value}).toList(),
      });
    } catch (_) {}
  }

  Map<String, dynamic> _addressPayload() {
    final a = _address!;
    return {
      'state_id': a.stateId,
      'city_id': a.cityId,
      'address_line': a.addressLine,
      if (a.pincode != null) 'pincode': a.pincode,
      if (a.deliveryTime != null && a.deliveryTime!.trim().isNotEmpty) 'delivery_time': a.deliveryTime!.trim(),
      if (a.phoneNumber != null) 'phone_number': a.phoneNumber,
      if (a.altPhoneNumber != null) 'alt_phone_number': a.altPhoneNumber,
      if (a.customerName != null && a.customerName!.trim().isNotEmpty) 'customer_name': a.customerName!.trim(),
    };
  }

  Future<Map<String, dynamic>?> payOneDayLunch({
    required String deliveryType,
    required int quantity,
    required int mealSizeId,
    required String deliveryTime,
  }) async {
    if (_address == null || !_address!.isComplete) {
      _error = 'Please complete delivery address';
      notifyListeners();
      return null;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final paymentData = await _repository.initiateOneDayLunchPayment({
        'delivery_type': deliveryType,
        'quantity': quantity,
        'meal_size_id': mealSizeId,
        'delivery_time': deliveryTime,
        'delivery_address': _addressPayload(),
        'redirectUrl': ApiEndpoints.paymentStatusPage,
      });
      return _runRazorpay(paymentData);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> paySpecialDishes({String? deliveryDate}) async {
    if (_address == null || !_address!.isComplete) {
      _error = 'Please complete delivery address';
      notifyListeners();
      return null;
    }
    if (_cartQty.isEmpty) {
      _error = 'Cart is empty';
      notifyListeners();
      return null;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = <String, dynamic>{
        'items': _cartQty.entries.map((e) => {'item_id': e.key, 'quantity': e.value}).toList(),
        'delivery_address': _addressPayload(),
        'redirectUrl': ApiEndpoints.paymentStatusPage,
      };
      if (deliveryDate != null && deliveryDate.isNotEmpty) {
        payload['delivery_date'] = deliveryDate;
      }
      if (_address?.deliveryTime != null && _address!.deliveryTime!.trim().isNotEmpty) {
        payload['delivery_time'] = _address!.deliveryTime!.trim();
      }
      final paymentData = await _repository.initiateSpecialDishPayment(payload);
      final result = await _runRazorpay(paymentData);
      if (result != null && result['sdkStatus'] == 'SUCCESS') {
        _cartQty.clear();
        await _persistCart();
      }
      return result;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _runRazorpay(Map<String, dynamic> paymentData) async {
    final razorpayOrderId = paymentData['razorpayOrderId']?.toString() ?? '';
    final keyId = paymentData['keyId']?.toString() ?? '';
    final amount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = paymentData['currency']?.toString() ?? 'INR';
    final merchantTransactionId = paymentData['merchantTransactionId']?.toString() ?? '';
    final orderId = paymentData['orderId']?.toString() ?? '';
    final contact = paymentData['contact']?.toString();
    final email = paymentData['email']?.toString();

    if (razorpayOrderId.isEmpty || keyId.isEmpty) {
      _error = 'Payment information not received from gateway';
      return null;
    }

    final sdkResult = await RazorpayService.pay(
      razorpayOrderId: razorpayOrderId,
      keyId: keyId,
      amount: amount,
      currency: currency,
      contact: contact,
      email: email,
    );
    final status = sdkResult['status']?.toString() ?? 'FAILURE';
    if (status != 'SUCCESS') {
      _error = sdkResult['error']?.toString() ?? 'Payment was not completed';
    }
    return {
      'sdkStatus': status,
      'merchantTransactionId': merchantTransactionId,
      'orderId': orderId,
      'razorpayOrderId': razorpayOrderId,
      'paymentId': sdkResult['paymentId'],
      'signature': sdkResult['signature'],
      'error': sdkResult['error']?.toString(),
    };
  }

  void clearState() {
    _loading = false;
    _error = null;
    _oneDayConfig = null;
    _specialConfig = null;
    _todayMenu = null;
    _categories = [];
    _items = [];
    _cartQty.clear();
    _itemCache.clear();
    _categoryItemsMemoryCache.clear();
    _address = null;
    _lastCategoriesFetchedAt = null;
    _lastOneDayConfigFetchedAt = null;
    _lastSpecialConfigFetchedAt = null;
    _lastCartFetchedAt = null;
    _lastItemsFetchedAt.clear();
    notifyListeners();
  }
}
