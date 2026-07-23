import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/utils/wallet_payment_flow.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/utils/error_handler.dart';

/// Payment status returned after the SDK transaction completes.
enum PaymentStatus { none, processing, success, failure, interrupted }

class PaymentProvider with ChangeNotifier {
  final PaymentRepository _repository;
  final LocalCache _cache;
  static const _historyCacheKey = 'cache_payment_history_v1';
  static const _activeCacheKey = 'cache_active_subscriptions_v1';

  PaymentProvider(this._repository, this._cache) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedHistory = await _cache.loadJson(_historyCacheKey);
      if (cachedHistory != null) {
        _paymentHistory = (cachedHistory['items'] as List? ?? const []).toList();
      }
      final cachedActive = await _cache.loadJson(_activeCacheKey);
      if (cachedActive != null) {
        _activeSubscriptions = (cachedActive['items'] as List? ?? const []).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  PaymentStatus _paymentStatus = PaymentStatus.none;
  PaymentStatus get paymentStatus => _paymentStatus;

  String? _lastTxnId;
  String? get lastTxnId => _lastTxnId;

  List<dynamic> _paymentHistory = [];
  List<dynamic> get paymentHistory => _paymentHistory;

  // Pagination state for payment history
  int _historyPage = 1;
  int _historyTotal = 0;
  final int _historyLimit = 10;
  bool _isLoadingMore = false;

  int get historyTotal => _historyTotal;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreHistory => _paymentHistory.length < _historyTotal;

  List<dynamic> _activeSubscriptions = [];
  List<dynamic> get activeSubscriptions => _activeSubscriptions;

  String? _walletBalance;
  String? get walletBalance => _walletBalance;

  List<dynamic> _walletTransactions = [];
  List<dynamic> get walletTransactions => _walletTransactions;

  DateTime? _lastHistoryFetchedAt;
  DateTime? _lastActiveSubFetchedAt;
  DateTime? _lastWalletFetchedAt;

  bool _isHistoryFresh() =>
      _lastHistoryFetchedAt != null &&
      DateTime.now().difference(_lastHistoryFetchedAt!).inMinutes < 10;

  bool _isActiveSubFresh() =>
      _lastActiveSubFetchedAt != null &&
      DateTime.now().difference(_lastActiveSubFetchedAt!).inMinutes < 5;

  bool _isWalletFresh() =>
      _lastWalletFetchedAt != null &&
      DateTime.now().difference(_lastWalletFetchedAt!).inMinutes < 5;

  // ─── Payment History ───────────────────────────────────────────────────────

  /// Resets and re-fetches from page 1.
  Future<void> fetchPaymentHistory({bool silent = false, bool force = false}) async {
    if (!force && _isHistoryFresh()) return;

    bool hasCachedData = false;
    final cached = await _cache.loadJson(_historyCacheKey);
    if (cached != null && _paymentHistory.isEmpty) {
      _paymentHistory = (cached['items'] as List? ?? const []).toList();
      _historyTotal = (cached['total'] as int?) ?? _paymentHistory.length;
      hasCachedData = _paymentHistory.isNotEmpty;
      notifyListeners();
    } else if (_paymentHistory.isNotEmpty) {
      hasCachedData = true;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _repository.getPaymentHistory(page: 1, limit: _historyLimit);
      _paymentHistory = (result['data'] as List?) ?? [];
      _historyTotal = (result['total'] as int?) ?? _paymentHistory.length;
      _historyPage = 1;
      _lastHistoryFetchedAt = DateTime.now();
      await _cache.saveJson(_historyCacheKey, {
        'items': _paymentHistory,
        'total': _historyTotal,
      });
    } catch (e) {
      // Keep showing cached history in offline mode; only show hard error if nothing cached.
      _error = hasCachedData ? null : ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  /// Appends the next page of history to the existing list.
  Future<void> loadMorePaymentHistory() async {
    if (_isLoadingMore || !hasMoreHistory) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = _historyPage + 1;
      final result = await _repository.getPaymentHistory(page: nextPage, limit: _historyLimit);
      final newItems = (result['data'] as List?) ?? [];
      _paymentHistory = [..._paymentHistory, ...newItems];
      _historyTotal = (result['total'] as int?) ?? _historyTotal;
      _historyPage = nextPage;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ─── Active Subscriptions ──────────────────────────────────────────────────

  Future<void> fetchActiveSubscriptions({bool silent = false, bool force = false}) async {
    if (!force && _isActiveSubFresh()) return;

    bool hasCachedData = false;
    final cached = force ? null : await _cache.loadJson(_activeCacheKey);
    if (cached != null && _activeSubscriptions.isEmpty) {
      _activeSubscriptions = (cached['items'] as List? ?? const []).toList();
      hasCachedData = _activeSubscriptions.isNotEmpty;
      notifyListeners();
    } else if (_activeSubscriptions.isNotEmpty) {
      hasCachedData = true;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _activeSubscriptions = await _repository.getActiveSubscriptions();
      _lastActiveSubFetchedAt = DateTime.now();
      await _cache.saveJson(_activeCacheKey, {'items': _activeSubscriptions});
    } catch (e) {
      // Keep showing cached plans in offline mode; only show hard error if nothing cached.
      _error = hasCachedData ? null : ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> fetchMealSizeUpgradeOptionsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    try {
      _error = null;
      notifyListeners();
      final payload = await _repository.fetchMealSizeUpgradeOptions(
        entityType: entityType,
        entityId: entityId,
      );
      final balance = payload['wallet_balance']?.toString();
      if (balance != null && balance.isNotEmpty) {
        _walletBalance = balance;
        notifyListeners();
      }
      return payload;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelPendingMealSizeUpgrade({
    required String entityType,
    required String entityId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.cancelPendingMealSizeUpgrade(
        entityType: entityType,
        entityId: entityId,
      );
      _lastWalletFetchedAt = null;
      _lastHistoryFetchedAt = null;
      _lastActiveSubFetchedAt = null;
      await fetchWallet(silent: true, force: true);
      await fetchPaymentHistory(silent: true, force: true);
      await fetchActiveSubscriptions(silent: true, force: true);
      return result;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> applyMealSizeDowngrade({
    required String entityType,
    required String entityId,
    required int toMealSizeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.applyMealSizeDowngrade(
        entityType: entityType,
        entityId: entityId,
        toMealSizeId: toMealSizeId,
      );
      final data = result['data'];
      if (data is Map) {
        final balance = data['walletBalance']?.toString();
        if (balance != null && balance.isNotEmpty) {
          _walletBalance = balance;
        }
      }
      _lastWalletFetchedAt = null;
      _lastHistoryFetchedAt = null;
      _lastActiveSubFetchedAt = null;
      await fetchWallet(silent: true, force: true);
      await fetchPaymentHistory(silent: true, force: true);
      await fetchActiveSubscriptions(silent: true, force: true);
      return result;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> previewWalletForTotal(double total, {bool useWallet = true}) async {
    return _repository.previewWalletApply(total: total, useWallet: useWallet);
  }

  Future<void> fetchWallet({bool silent = false, bool force = false}) async {
    if (!force && _walletBalance != null && _isWalletFresh()) return;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _repository.getWallet();
      _walletBalance = data['balance']?.toString();
      _lastWalletFetchedAt = DateTime.now();
    } catch (e) {
      if (!silent) _error = ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchWalletTransactions({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _walletTransactions = List<dynamic>.from(await _repository.getWalletTransactions());
    } catch (e) {
      if (!silent) _error = ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<dynamic>> fetchMealSizeUpgradePriceRows() async {
    try {
      _error = null;
      notifyListeners();
      return await _repository.fetchMealSizeUpgradePrices();
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // ─── Checkout via Razorpay SDK ──────────────────────────────────────────────

  /// Full checkout flow:
  /// 1. Call backend to initiate the payment order → get order ID
  /// 2. Pass the order ID to [RazorpayService.pay] which drives the native SDK
  /// 3. Return the SDK status (SUCCESS / FAILURE)
  Future<Map<String, dynamic>?> initiateCheckout({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    bool isSandbox = true,
    bool useWallet = true,
  }) async {
    _isLoading = true;
    _paymentStatus = PaymentStatus.processing;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Create the order on the backend
      final paymentData = await _repository.initiatePayment(
        subscriptionId: subscriptionId,
        entityType: entityType,
        entityId: entityId,
        includeSaturday: includeSaturday,
        startDate: startDate,
        customRedirectUrl: ApiEndpoints.paymentStatusPage,
        useWallet: useWallet,
      );

      _lastTxnId = paymentData['merchantTransactionId']?.toString();

      final result = await WalletPaymentFlow.completeAfterInit(
        paymentData: paymentData,
        isSandbox: isSandbox,
        paymentRepository: _repository,
      );

      return _finalizeCheckoutResult(result);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _paymentStatus = PaymentStatus.failure;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Razorpay checkout for admin-published meal size bumps (see meal_size_upgrade_prices).
  Future<Map<String, dynamic>?> initiateMealSizeUpgrade({
    required String entityType,
    required String entityId,
    required int toMealSizeId,
    bool isSandbox = true,
    bool useWallet = true,
  }) async {
    _isLoading = true;
    _paymentStatus = PaymentStatus.processing;
    _error = null;
    notifyListeners();

    try {
      final paymentData = await _repository.initiateMealSizeUpgrade(
        entityType: entityType,
        entityId: entityId,
        toMealSizeId: toMealSizeId,
        customRedirectUrl: ApiEndpoints.paymentStatusPage,
        useWallet: useWallet,
      );

      _lastTxnId = paymentData['merchantTransactionId']?.toString();

      final result = await WalletPaymentFlow.completeAfterInit(
        paymentData: paymentData,
        isSandbox: isSandbox,
        paymentRepository: _repository,
      );

      return _finalizeCheckoutResult(result);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _paymentStatus = PaymentStatus.failure;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _finalizeCheckoutResult(Map<String, dynamic> result) {
    final status = result['sdkStatus'] as String? ?? 'FAILURE';
    if (status == 'SUCCESS') {
      _paymentStatus = PaymentStatus.success;
      _lastWalletFetchedAt = null;
      _lastHistoryFetchedAt = null;
      _lastActiveSubFetchedAt = null;
      // MEDIUM-08: Use unawaited() to satisfy the lint rule (fire-and-forget is intentional).
      // Invalidate history cache so the next fetch shows the latest entity names.
      unawaited(_cache.saveJson(_historyCacheKey, {'items': <dynamic>[]}));
      unawaited(fetchWallet(silent: true, force: true));
      unawaited(fetchPaymentHistory(silent: true, force: true));
      unawaited(fetchActiveSubscriptions(silent: true, force: true));
    } else if (status == 'EXTERNAL_WALLET') {
      // User redirected to external wallet app (PhonePe/GPay). Payment may
      // still succeed — webhook will finalize. Treat as processing/pending.
      _paymentStatus = PaymentStatus.processing;
    } else if (status == 'CANCELLED' || status == 'INTERRUPTED') {
      _paymentStatus = PaymentStatus.interrupted;
      _lastWalletFetchedAt = null;
      unawaited(fetchWallet(silent: true, force: true));
    } else {
      _paymentStatus = PaymentStatus.failure;
      // MEDIUM-08: No wallet fetch on payment failure — wallet balance is unchanged.
    }
    return result;
  }

  Future<void> abandonPendingPayment({
    String? orderId,
    String? merchantTransactionId,
    bool cancelPendingCart = false,
  }) async {
    try {
      await _repository.abandonPendingPayment(
        orderId: orderId,
        merchantTransactionId: merchantTransactionId,
        cancelPendingCart: cancelPendingCart,
      );
      _lastWalletFetchedAt = null;
      await fetchWallet(silent: true, force: true);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    }
  }

  // ─── Status Polling ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> checkStatus(String txnId) async {
    try {
      return await _repository.getPaymentStatus(txnId);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    }
  }

  Future<void> forceSyncPayment(String txnId) async {
    try {
      await _repository.forceSync(txnId);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      rethrow;
    }
  }

  void resetStatus() {
    _paymentStatus = PaymentStatus.none;
    _error = null;
    notifyListeners();
  }

  void clearState() {
    _paymentHistory = [];
    _activeSubscriptions = [];
    _walletBalance = null;
    _walletTransactions = [];
    _lastHistoryFetchedAt = null;
    _lastActiveSubFetchedAt = null;
    _lastWalletFetchedAt = null;
    _isLoading = false;
    _error = null;
    _paymentStatus = PaymentStatus.none;
    _lastTxnId = null;
    notifyListeners();
  }
}
