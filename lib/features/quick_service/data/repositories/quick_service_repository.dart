import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class QuickServiceRepository {
  final DioClient _dioClient;
  QuickServiceRepository(this._dioClient);

  Future<Map<String, dynamic>> getOneDayLunchConfig() async {
    final res = await _dioClient.dio.get(ApiEndpoints.oneDayLunchConfig);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<Map<String, dynamic>> getSpecialDishConfig() async {
    final res = await _dioClient.dio.get(ApiEndpoints.specialDishConfig);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<Map<String, dynamic>?> getSavedDeliveryAddress() async {
    final res = await _dioClient.dio.get(ApiEndpoints.quickServiceDeliveryAddress);
    final data = res.data['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>> quoteOneDayLunch(Map<String, dynamic> body) async {
    final res = await _dioClient.dio.post(ApiEndpoints.oneDayLunchQuote, data: body);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<Map<String, dynamic>> initiateOneDayLunchPayment(Map<String, dynamic> body) async {
    final res = await _dioClient.dio.post(ApiEndpoints.oneDayLunchInitiatePayment, data: body);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<List<dynamic>> getSpecialCategories() async {
    final res = await _dioClient.dio.get(ApiEndpoints.specialDishCategories);
    return res.data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getSpecialItems(String categoryId) async {
    final res = await _dioClient.dio.get(ApiEndpoints.specialDishItems(categoryId));
    return res.data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getSpecialCart() async {
    final res = await _dioClient.dio.get(ApiEndpoints.specialDishCart);
    return Map<String, dynamic>.from(res.data['data'] as Map? ?? {});
  }

  Future<void> saveSpecialCart(Map<String, dynamic> payload) async {
    await _dioClient.dio.put(ApiEndpoints.specialDishCart, data: {'payload': payload});
  }

  Future<Map<String, dynamic>> initiateSpecialDishPayment(Map<String, dynamic> body) async {
    final res = await _dioClient.dio.post(ApiEndpoints.specialDishInitiatePayment, data: body);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }
}
