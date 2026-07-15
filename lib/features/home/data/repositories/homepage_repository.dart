import 'package:dio/dio.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/features/home/data/models/homepage_entry.dart';

class HomepageRepository {
  final DioClient _dioClient;

  HomepageRepository(this._dioClient);

  Future<List<HomepageEntry>> getHomepageEntries() async {
    const cacheKey = 'homepage_entries';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.homepage);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        await CacheStore.setJson(cacheKey, data, ttl: const Duration(hours: 24));
        return data.map((json) => HomepageEntry.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      final cached = await CacheStore.getJsonList(cacheKey);
      if (cached.isNotEmpty) {
        return cached.map((j) => HomepageEntry.fromJson(j)).toList();
      }
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      if (error.response?.data != null && error.response?.data['message'] != null) {
         return error.response?.data['message'];
      }
      return 'Server error: ${error.response?.statusCode}';
    } else {
      return 'Network error: Please check your connection.';
    }
  }
}
