import 'package:flutter/material.dart';
import 'package:meal_app/core/network/cart_repository.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/offline_queue.dart';
import 'package:meal_app/core/utils/wallet_payment_flow.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/error_handler.dart';

/// Server-side cart item — mirrors the backend response.
class CartItem {
  final int id; // server-side cart item id (for delete)
  final String entityName;
  final String entityType;
  final String planName;
  final double unitPrice;
  final String? startDate;
  final String? entityId;
  final String? subscriptionId;
  final bool includeSaturday;
  final int? mealSizeId;
  final String? mealSizeName;
  final String? mealTiming;

  CartItem({
    required this.id,
    required this.entityName,
    required this.entityType,
    required this.planName,
    required this.unitPrice,
    this.startDate,
    this.entityId,
    this.subscriptionId,
    this.includeSaturday = true,
    this.mealSizeId,
    this.mealSizeName,
    this.mealTiming,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? 0,
      entityName: json['entity_name']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      startDate: json['start_date']?.toString(),
      entityId: json['entity_id']?.toString(),
      subscriptionId: json['subscription_id']?.toString(),
      includeSaturday: json['include_saturday'] == null ? true : json['include_saturday'] == true,
      mealSizeId: json['meal_size_id'] is int
          ? json['meal_size_id'] as int
          : int.tryParse(json['meal_size_id']?.toString() ?? ''),
      mealSizeName: json['meal_size_name']?.toString(),
      mealTiming: json['meal_timing']?.toString(),
    );
  }
}

/// Provider managing the SERVER-SIDE cart.
/// All operations hit the backend — no local-only state.
class CartProvider with ChangeNotifier {
  final CartRepository _repository;
  final PaymentRepository? _paymentRepository;

  CartProvider(this._repository, {PaymentRepository? paymentRepository})
      : _paymentRepository = paymentRepository {
    _loadCachedCart();
  }

  List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  String? _cartId;
  String? get cartId => _cartId;

  double _totalAmount = 0;
  double get totalAmount => _totalAmount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightFetch;

  /// Bumped when local cart rows change so a slow `_loadCachedCart` read does not
  /// overwrite fresher in-memory state (e.g. offline remove completed before disk read finished).
  int _localCartMutationGen = 0;

  void _bumpLocalCartMutation() => _localCartMutationGen++;

  int get itemCount => _items.length;

  Future<void> _loadCachedCart() async {
    final genAtStart = _localCartMutationGen;
    try {
      final cached = await CacheStore.getJson('cart_data');
      if (genAtStart != _localCartMutationGen) return;
      if (cached is Map<String, dynamic>) {
        _cartId = cached['cart_id']?.toString();
        _totalAmount = double.tryParse(cached['total_amount']?.toString() ?? '') ?? 0.0;
        final itemsList = cached['items'];
        if (itemsList is List) {
          _items = itemsList.map((json) => CartItem.fromJson(Map<String, dynamic>.from(json as Map))).toList();
        }
        notifyListeners();
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _persistCart() async {
    try {
      await CacheStore.setJson('cart_data', {
        'cart_id': _cartId,
        'total_amount': _totalAmount,
        'items': _items.map((i) => {
          'id': i.id,
          'entity_name': i.entityName,
          'entity_type': i.entityType,
          'plan_name': i.planName,
          'unit_price': i.unitPrice,
          'start_date': i.startDate,
          'entity_id': i.entityId,
          'subscription_id': i.subscriptionId,
          'include_saturday': i.includeSaturday,
          'meal_size_id': i.mealSizeId,
          'meal_size_name': i.mealSizeName,
          'meal_timing': i.mealTiming,
        }).toList(),
      }, ttl: const Duration(hours: 6));
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _persistLocalCart() => _persistCart();

  bool _isLikelyNetworkError(Object e) {
    final raw = e.toString().toLowerCase();
    return raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('timed out') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection');
  }

  Future<void> _addLocalItem({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    String? entityName,
    String? planName,
    double? unitPrice,
    int? mealSizeId,
    String? mealSizeName,
    String? mealTiming,
  }) async {
    _bumpLocalCartMutation();
    final safeStart = startDate ?? '';
    _items = [
      ..._items.where((i) =>
          !(i.subscriptionId == subscriptionId &&
              i.entityType == entityType &&
              i.entityId == entityId &&
              i.includeSaturday == includeSaturday)),
      CartItem(
        id: -DateTime.now().microsecondsSinceEpoch,
        entityName: entityName ?? entityType.toUpperCase(),
        entityType: entityType,
        planName: planName ?? 'Plan',
        unitPrice: unitPrice ?? 0,
        startDate: safeStart,
        entityId: entityId,
        subscriptionId: subscriptionId,
        includeSaturday: includeSaturday,
        mealSizeId: mealSizeId,
        mealSizeName: mealSizeName,
        mealTiming: mealTiming,
      ),
    ];
    _totalAmount = _items.fold(0.0, (sum, i) => sum + i.unitPrice);
    await _persistLocalCart();
  }

  // ─── Fetch cart from server ─────────────────────────────────────────────────

  Future<void> fetchCart({bool force = false, bool silent = false}) async {
    final isFresh = _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inSeconds < 90;
    // Always reconcile with server when the cart may have changed (checkout, reconnect).
    if (!force && silent && _items.isNotEmpty && isFresh) return;
    if (_inflightFetch != null) return _inflightFetch;

    final request = _doFetchCart(silent: silent);
    _inflightFetch = request;
    try {
      await request;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<void> _doFetchCart({bool silent = false}) async {
    if (!silent) {
      if (_items.isEmpty) _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _repository.getCart();

      // Parse the cart response
      final cart = data['cart'];
      if (cart != null) {
        _cartId = cart['id']?.toString();
        _totalAmount = double.tryParse(cart['total_amount']?.toString() ?? '0') ?? 0;
      } else {
        _cartId = null;
        _totalAmount = 0;
      }

      // Parse items
      final List itemsList = data['items'] ?? [];
      _items = itemsList.map((json) => CartItem.fromJson(json)).toList();
      _lastFetchedAt = DateTime.now();
      await _persistCart();
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      // Keep cached cart data on network error instead of clearing
      if (_items.isEmpty) {
        _totalAmount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // After load, silently fix any items whose start date is missing/today/past.
    // Meal subscriptions can never start today, so we promote them to tomorrow.
    await _autoCorrectInvalidStartDates();
  }

  /// Patches any cart items that have a missing / past / today start_date,
  /// bumping them to tomorrow on the server. Runs in the background; errors
  /// are swallowed so a transient network glitch never blocks the UI.
  Future<void> _autoCorrectInvalidStartDates() async {
    if (_items.isEmpty) return;
    final invalid = _items.where((i) => 
        i.startDate != null && 
        i.startDate!.trim().isNotEmpty && 
        !MealDate.isValidFutureStartDate(i.startDate)
    ).toList();
    if (invalid.isEmpty) return;

    final tomorrow = MealDate.tomorrowYmd();
    bool changed = false;
    for (final item in invalid) {
      try {
        await _repository.updateCartItemStartDate(itemId: item.id, startDate: tomorrow);
        changed = true;
      } catch (_) {
        // Silent — user can still manually change date in the UI.
      }
    }
    if (changed) {
      // Re-fetch without recursion (skip auto-correct second time).
      try {
        final data = await _repository.getCart();
        final cart = data['cart'];
        if (cart != null) {
          _cartId = cart['id']?.toString();
          _totalAmount = double.tryParse(cart['total_amount']?.toString() ?? '0') ?? 0;
        }
        final List itemsList = data['items'] ?? [];
        _items = itemsList.map((json) => CartItem.fromJson(json)).toList();
        notifyListeners();
      } catch (_) {/* keep prior state */}
    }
  }

  // ─── Add item to server cart ────────────────────────────────────────────────

  Future<bool> addItem({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    String? entityName,
    String? planName,
    double? unitPrice,
    int? mealSizeId,
    String? mealSizeName,
    String? mealTiming,
  }) async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      final safeStart = startDate ?? '';
      await OfflineQueue.enqueue(
        method: 'POST',
        path: ApiEndpoints.addToCart,
        data: {
          'subscriptionId': subscriptionId,
          'entityType': entityType,
          'entityId': entityId,
          'includeSaturday': includeSaturday,
          if (safeStart.isNotEmpty) 'startDate': safeStart,
        },
      );
      // Same metadata + pricing as when we queue after a failed network call.
      await _addLocalItem(
        subscriptionId: subscriptionId,
        entityType: entityType,
        entityId: entityId,
        includeSaturday: includeSaturday,
        startDate: safeStart,
        entityName: entityName,
        planName: planName,
        unitPrice: unitPrice,
        mealSizeId: mealSizeId,
        mealSizeName: mealSizeName,
        mealTiming: mealTiming,
      );
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.addToCart(
        subscriptionId: subscriptionId,
        entityType: entityType,
        entityId: entityId,
        includeSaturday: includeSaturday,
        startDate: startDate,
      );

      // Refresh cart from server to get updated state
      await fetchCart(force: true, silent: true);
      return true;
    } catch (e) {
      if (_isLikelyNetworkError(e)) {
        await _addLocalItem(
          subscriptionId: subscriptionId,
          entityType: entityType,
          entityId: entityId,
          includeSaturday: includeSaturday,
          startDate: startDate,
          entityName: entityName,
          planName: planName,
          unitPrice: unitPrice,
          mealSizeId: mealSizeId,
          mealSizeName: mealSizeName,
          mealTiming: mealTiming,
        );
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update cart line start date ────────────────────────────────────────────

  Future<bool> updateItemStartDate(int cartItemId, String startDate) async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();
      await OfflineQueue.enqueue(
        method: 'PATCH',
        path: ApiEndpoints.removeCartItem(cartItemId),
        data: {'startDate': safeStart},
      );
      _bumpLocalCartMutation();
      _items = _items
          .map((i) => i.id == cartItemId
              ? CartItem(
                  id: i.id,
                  entityName: i.entityName,
                  entityType: i.entityType,
                  planName: i.planName,
                  unitPrice: i.unitPrice,
                  startDate: safeStart,
                  entityId: i.entityId,
                  subscriptionId: i.subscriptionId,
                  includeSaturday: i.includeSaturday,
                  mealSizeId: i.mealSizeId,
                  mealSizeName: i.mealSizeName,
                  mealTiming: i.mealTiming,
                )
              : i)
          .toList();
      await _persistCart();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Defensive: clamp to tomorrow if caller somehow passes today/past.
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();

      await _repository.updateCartItemStartDate(
        itemId: cartItemId,
        startDate: safeStart,
      );
      await fetchCart(force: true, silent: true);
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Remove item from server cart ───────────────────────────────────────────

  Future<bool> removeItem(int cartItemId) async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.removeCartItem(cartItemId),
      );
      _bumpLocalCartMutation();
      _items = _items.where((i) => i.id != cartItemId).toList();
      _totalAmount = _items.fold(0.0, (sum, i) => sum + i.unitPrice);
      await _persistCart();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var idToRemove = cartItemId;
      if (idToRemove <= 0) {
        await fetchCart(force: true, silent: true);
        final match = _items.where((i) => i.id == cartItemId).firstOrNull;
        if (match != null && match.id > 0) {
          idToRemove = match.id;
        } else if (_items.length == 1 && _items.first.id > 0) {
          idToRemove = _items.first.id;
        } else {
          _error = 'Could not remove item — refresh the cart and try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }
      await _repository.removeCartItem(idToRemove);
      await fetchCart(force: true, silent: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isLikelyNetworkError(e) && NetworkStatusService.instance.canAttemptApi) {
        await OfflineQueue.enqueue(
          method: 'DELETE',
          path: ApiEndpoints.removeCartItem(cartItemId > 0 ? cartItemId : 0),
        );
      }
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Clear entire cart on server ────────────────────────────────────────────

  Future<bool> clearCart() async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      await OfflineQueue.enqueue(method: 'DELETE', path: ApiEndpoints.clearCart);
      _bumpLocalCartMutation();
      _items = [];
      _totalAmount = 0;
      _cartId = null;
      _error = null;
      await _persistCart();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.clearCart();
      _items = [];
      _totalAmount = 0;
      _cartId = null;
      await _persistLocalCart();
    } catch (e) {
      if (_isLikelyNetworkError(e)) {
        _items = [];
        _totalAmount = 0;
        _cartId = null;
        await _persistLocalCart();
        _error = null;
      } else {
        _error = _extractErrorMessage(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _error == null;
  }

  /// Local-only reset — used after a successful payment to avoid an extra
  /// network round-trip (the backend marks the cart as `checked_out`
  /// during finalization, so it will not be returned by GET /cart anyway).
  void resetLocal() {
    _items = [];
    _totalAmount = 0;
    _cartId = null;
    _error = null;
    _persistLocalCart();
    notifyListeners();
  }

  Future<void> syncOfflineItemsIfAny() async {
    final pending = _items.where((i) => i.id <= 0).toList();
    if (pending.isEmpty) return;
    for (final item in pending) {
      if (item.subscriptionId == null || item.entityId == null) continue;
      try {
        await _repository.addToCart(
          subscriptionId: item.subscriptionId!,
          entityType: item.entityType,
          entityId: item.entityId!,
          includeSaturday: item.includeSaturday,
          startDate: item.startDate ?? MealDate.tomorrowYmd(),
        );
      } catch (_) {
        // keep pending item for next reconnect
      }
    }
    await fetchCart();
  }

  // ─── Check if entity is already in cart ─────────────────────────────────────

  bool hasEntity(String entityId) {
    return _items.any((i) => i.entityId == entityId);
  }

  bool hasExactCartItem({
    required String entityType,
    required String entityId,
    required String subscriptionId,
    required bool includeSaturday,
  }) {
    return _items.any((i) =>
        i.entityType == entityType &&
        i.entityId == entityId &&
        i.subscriptionId == subscriptionId &&
        i.includeSaturday == includeSaturday);
  }

  // ─── Cart Checkout via Razorpay SDK ──────────────────────────────────────────

  Future<Map<String, dynamic>?> checkoutAll({bool isSandbox = true, bool useWallet = true}) async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      _error = 'No internet connection. Connect to the internet to complete payment.';
      notifyListeners();
      return null;
    }

    if (_items.isEmpty) {
      _error = 'Cart is empty';
      notifyListeners();
      return null;
    }
    if (_items.any((i) => i.id <= 0)) {
      _error = 'No internet connection. Connect before checkout so your cart can be updated.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final paymentData = await _repository.checkoutCart(
        redirectUrl: ApiEndpoints.paymentStatusPage,
        useWallet: useWallet,
      );

      final result = await WalletPaymentFlow.completeAfterInit(
        paymentData: paymentData,
        isSandbox: isSandbox,
        paymentRepository: _paymentRepository,
      );

      return result;
    } catch (e) {
      _error = _extractErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _extractErrorMessage(Object e) => ErrorHandler.getErrorMessage(e);
}
