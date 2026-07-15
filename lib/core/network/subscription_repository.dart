
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/cache_store.dart';

class SubscriptionRepository {
  final DioClient _dioClient;

  SubscriptionRepository(this._dioClient);

  Future<List<SubscriptionModel>> getSubscriptions() async {
    const cacheKey = 'subscriptions_list';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptions);
      if (response.data['success'] == true) {
        final List data = response.data['data'];
        await CacheStore.setJson(cacheKey, data);
        return data.map((s) => SubscriptionModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is List) {
        return cached.whereType<Map>().map((s) => SubscriptionModel.fromJson(Map<String, dynamic>.from(s))).toList();
      }
      rethrow;
    }
  }

  Future<SubscriptionModel?> getSubscriptionById(String id) async {
    try {
      final response = await _dioClient.dio.get('${ApiEndpoints.subscriptions}/$id');
      if (response.data['success'] == true) {
        return SubscriptionModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
