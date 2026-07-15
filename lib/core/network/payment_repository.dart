import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';

List<dynamic> normalizeWalletTransactionList(dynamic payload) {
  if (payload is List) {
    return List<dynamic>.from(payload);
  }

  if (payload is Map) {
    for (final candidate in [payload['transactions'], payload['items'], payload['data']]) {
      if (candidate is List) {
        return List<dynamic>.from(candidate);
      }
    }
  }

  return const [];
}

class PaymentRepository {
  final DioClient _dioClient;

  PaymentRepository(this._dioClient);

  Future<Map<String, dynamic>> initiatePayment({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    String? customRedirectUrl,
    bool useWallet = true,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.initiatePayment,
        data: {
          'subscriptionId': subscriptionId,
          'entityType': entityType,
          'entityId': entityId,
          'includeSaturday': includeSaturday,
          'useWallet': useWallet,
          if (startDate != null) 'startDate': startDate,
          if (customRedirectUrl != null) 'redirectUrl': customRedirectUrl,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to initiate payment';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMealSizeUpgradeOptions({
    required String entityType,
    required String entityId,
  }) async {
    final response = await _dioClient.dio.get(
      ApiEndpoints.mealSizeUpgradeOptions,
      queryParameters: {
        'entityType': entityType,
        'entityId': entityId,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to load upgrade options';
  }

  Future<List<dynamic>> fetchMealSizeUpgradePrices() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSizeUpgradePrices);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      }
      throw response.data['message']?.toString() ?? 'Failed to load upgrade prices';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initiateMealSizeUpgrade({
    required String entityType,
    required String entityId,
    required int toMealSizeId,
    String? customRedirectUrl,
    bool useWallet = true,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.initiateMealSizeUpgrade,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'toMealSizeId': toMealSizeId,
          'useWallet': useWallet,
          if (customRedirectUrl != null) 'redirectUrl': customRedirectUrl,
        },
      );
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw response.data['message']?.toString() ?? 'Failed to initiate upgrade payment';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelPendingMealSizeUpgrade({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.cancelPendingMealSizeUpgrade,
        data: {
          'entityType': entityType,
          'entityId': entityId,
        },
      );
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw response.data['message']?.toString() ?? 'Failed to cancel pending upgrade';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> applyMealSizeDowngrade({
    required String entityType,
    required String entityId,
    required int toMealSizeId,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.applyMealSizeDowngrade,
      data: {
        'entityType': entityType,
        'entityId': entityId,
        'toMealSizeId': toMealSizeId,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to apply downgrade';
  }

  Future<Map<String, dynamic>> getWallet() async {
    final response = await _dioClient.dio.get(ApiEndpoints.wallet);
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from((response.data['data'] as Map?) ?? {});
    }
    throw response.data['message']?.toString() ?? 'Failed to load wallet';
  }

  Future<Map<String, dynamic>> previewWalletApply({
    required double total,
    bool useWallet = true,
  }) async {
    final response = await _dioClient.dio.get(
      ApiEndpoints.walletPreview,
      queryParameters: {
        'total': total,
        'useWallet': useWallet,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from((response.data['data'] as Map?) ?? {});
    }
    throw response.data['message']?.toString() ?? 'Failed to preview wallet';
  }

  Future<List<dynamic>> getWalletTransactions({int limit = 50}) async {
    final response = await _dioClient.dio.get(
      ApiEndpoints.walletTransactions,
      queryParameters: {'limit': limit},
    );
    if (response.data['success'] == true) {
      return normalizeWalletTransactionList(response.data['data']);
    }
    throw response.data['message']?.toString() ?? 'Failed to load wallet history';
  }

  Future<Map<String, dynamic>> checkoutCart({String? redirectUrl, bool useWallet = true}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.checkoutCart,
        data: {
          if (redirectUrl != null) 'redirectUrl': redirectUrl,
          'useWallet': useWallet,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to checkout cart';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> abandonPendingPayment({
    String? orderId,
    String? merchantTransactionId,
    bool cancelPendingCart = false,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.abandonPayment,
      data: {
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (merchantTransactionId != null && merchantTransactionId.isNotEmpty)
          'merchantTransactionId': merchantTransactionId,
        if (cancelPendingCart) 'cancelPendingCart': true,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from((response.data['data'] as Map?) ?? {});
    }
    throw response.data['message']?.toString() ?? 'Failed to cancel payment';
  }

  Future<Map<String, dynamic>> getPaymentStatus(String txnId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.paymentStatus(txnId));
      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to get payment status';
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a page of payment history.
  /// Returns `{'data': List, 'total': int, 'page': int, 'limit': int}`.
  Future<Map<String, dynamic>> getPaymentHistory({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.paymentHistory,
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.data['success'] == true) {
        final pagination = response.data['pagination'] as Map? ?? {};
        return {
          'data': (response.data['data'] as List?) ?? [],
          'total': pagination['total'] ?? 0,
          'page': pagination['page'] ?? page,
          'limit': pagination['limit'] ?? limit,
        };
      } else {
        throw response.data['message']?.toString() ?? 'Failed to fetch payment history';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getActiveSubscriptions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.activeSubscriptions);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to fetch active subscriptions';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> forceSync(String txnId) async {
    try {
      final response = await _dioClient.dio.post(ApiEndpoints.forceSync(txnId));
      if (response.data['success'] == true) {
        return response.data;
      } else {
        throw response.data['message']?.toString() ?? 'Failed to sync payment';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptionStatus);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSubscriptionAlerts() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptionAlerts);
      if (response.data['success'] == true) {
        return response.data['alerts'] ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
