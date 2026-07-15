
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/features/children/data/models/child_model.dart';

class ChildrenRepository {
  final DioClient _dioClient;

  ChildrenRepository(this._dioClient);

  Future<List<ChildModel>> getChildren() async {
    const cacheKey = 'children_list';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.children);
      if (response.data['success'] == true) {
        final List children = response.data['data']['children'];
        await CacheStore.setJson(cacheKey, children);
        return children.map((c) => ChildModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is List) {
        return cached.whereType<Map>().map((c) => ChildModel.fromJson(Map<String, dynamic>.from(c))).toList();
      }
      rethrow;
    }
  }

  Future<List<ChildModel>> registerChildren(List<ChildModel> children) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.children,
        data: {
          'children': children.map((c) => c.toJson()).toList(),
        },
      );
      if (response.data['success'] == true) {
        final raw = response.data['data']?['children'];
        if (raw is List) {
          return raw.map((c) => ChildModel.fromJson(Map<String, dynamic>.from(c as Map))).toList();
        }
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateChild(String id, ChildModel child) async {
    try {
      final response = await _dioClient.dio.put(
        ApiEndpoints.child(id),
        data: child.toJson(),
      );
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteChild(String id) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.child(id));
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }
}
