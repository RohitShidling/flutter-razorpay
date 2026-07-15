import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';

class BulkOrderRepository {
  final DioClient _dioClient;

  BulkOrderRepository(this._dioClient);

  Future<BulkOrderConfig> fetchConfig() async {
    final response = await _dioClient.dio.get(ApiEndpoints.bulkOrderConfig);
    if (response.data['success'] == true) {
      return BulkOrderConfig.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    }
    throw response.data['message']?.toString() ?? 'Failed to load bulk order settings';
  }

  Future<Map<String, dynamic>> fetchMenusForDelivery(String deliveryDate) async {
    final response = await _dioClient.dio.get(ApiEndpoints.bulkOrderMenus(deliveryDate));
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to load menus';
  }

  Future<List<BulkVarietyCategory>> fetchVarietyCategories() async {
    final response = await _dioClient.dio.get(ApiEndpoints.bulkOrderVarietyCategories);
    if (response.data['success'] == true) {
      final list = response.data['data'];
      if (list is! List) return [];
      return list
          .map((e) => BulkVarietyCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw response.data['message']?.toString() ?? 'Failed to load categories';
  }

  Future<List<BulkMenuOption>> fetchMealsByCategory(String categoryId) async {
    final response = await _dioClient.dio.get(ApiEndpoints.bulkOrderCategoryMeals(categoryId));
    if (response.data['success'] == true) {
      final list = response.data['data'];
      if (list is! List) return [];
      return list
          .map((e) => BulkMenuOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw response.data['message']?.toString() ?? 'Failed to load meals';
  }

  Future<Map<String, dynamic>> quote({
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.bulkOrderQuote,
      data: {
        'deliveryDate': deliveryDate,
        'items': items,
        'deliveryAddress': deliveryAddress,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Quote failed';
  }

  Future<Map<String, dynamic>?> getCartDraft() async {
    final response = await _dioClient.dio.get(ApiEndpoints.bulkOrderCart);
    if (response.data['success'] == true) {
      final data = response.data['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    }
    throw response.data['message']?.toString() ?? 'Failed to load bulk cart';
  }

  Future<void> saveCartDraft(Map<String, dynamic> payload) async {
    final response = await _dioClient.dio.put(
      ApiEndpoints.bulkOrderCart,
      data: {'payload': payload},
    );
    if (response.data['success'] != true) {
      throw response.data['message']?.toString() ?? 'Failed to save bulk cart';
    }
  }

  Future<void> deleteCartDraft() async {
    final response = await _dioClient.dio.delete(ApiEndpoints.bulkOrderCart);
    if (response.data['success'] != true) {
      throw response.data['message']?.toString() ?? 'Failed to clear bulk cart';
    }
  }

  Future<List<dynamic>> getSavedDeliveryAddresses() async {
    final response = await _dioClient.dio.get(ApiEndpoints.clientDeliveryAddresses);
    if (response.data['success'] == true) {
      final data = response.data['data'];
      if (data is List) return data;
      return [];
    }
    throw response.data['message']?.toString() ?? 'Failed to load saved addresses';
  }

  Future<Map<String, dynamic>> createSavedDeliveryAddress(Map<String, dynamic> body) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.clientDeliveryAddresses,
      data: body,
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to save address';
  }

  Future<Map<String, dynamic>> updateSavedDeliveryAddress(int addressId, Map<String, dynamic> body) async {
    final response = await _dioClient.dio.put(
      '${ApiEndpoints.clientDeliveryAddresses}/$addressId',
      data: body,
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to update address';
  }

  Future<void> deleteSavedDeliveryAddress(int addressId) async {
    final response = await _dioClient.dio.delete('${ApiEndpoints.clientDeliveryAddresses}/$addressId');
    if (response.data['success'] != true) {
      throw response.data['message']?.toString() ?? 'Failed to delete address';
    }
  }

  Future<Map<String, dynamic>> selectSavedDeliveryAddress(int addressId) async {
    final response = await _dioClient.dio.post('${ApiEndpoints.clientDeliveryAddresses}/$addressId/select');
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to select address';
  }

  Future<Map<String, dynamic>> initiateBundlePayment({
    required String deliveryDate,
    required Map<String, dynamic> deliveryAddress,
    Map<String, dynamic>? standard,
    List<Map<String, dynamic>>? variety,
    String? redirectUrl,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.bulkOrderInitiateBundlePayment,
      data: {
        'deliveryDate': deliveryDate,
        'deliveryAddress': deliveryAddress,
        if (standard != null) 'standard': standard,
        if (variety != null && variety.isNotEmpty) 'variety': variety,
        if (redirectUrl != null) 'redirectUrl': redirectUrl,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Bundle payment initiation failed';
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    String? redirectUrl,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.bulkOrderInitiatePayment,
      data: {
        'deliveryDate': deliveryDate,
        'items': items,
        'deliveryAddress': deliveryAddress,
        if (redirectUrl != null) 'redirectUrl': redirectUrl,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw response.data['message']?.toString() ?? 'Payment initiation failed';
  }
}
