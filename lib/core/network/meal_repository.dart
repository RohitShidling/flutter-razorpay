import 'package:dio/dio.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';

/// Repository for meal management — today/weekly menu, meal status,
/// skip management, and subscription alerts.
class MealRepository {
  final DioClient _dioClient;

  MealRepository(this._dioClient);

  // ─── Today & Weekly Menu ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchTodayMenu() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.todayMeal);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchWeeklyMenu() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.weeklyMeal);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Meal Status (remaining meals) ───────────────────────────────────────

  Future<List<dynamic>> fetchMealStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealStatus);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // ─── Skip Meals ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> skipMeal({
    required String entityType,
    required String entityId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.skipMeal,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'startDate': startDate,
          'endDate': endDate,
        },
      );
      if (response.data['success'] == true) {
        return response.data;
      }
      throw Exception(response.data['message']?.toString() ?? 'Failed to skip meal');
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString()
          ?? e.response?.data?['error']?.toString()
          ?? e.message
          ?? 'Failed to skip meal';
      throw Exception(msg);
    }
  }

  Future<List<dynamic>> fetchMealSkips() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSkips);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMealSkipPolicy() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSkipPolicy);
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data'] ?? {});
      }
      return const {};
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> cancelSkip(int skipId) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.cancelSkip(skipId));
      return response.data['success'] == true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString()
          ?? e.response?.data?['error']?.toString()
          ?? e.message
          ?? 'Failed to cancel skip';
      throw Exception(msg);
    }
  }

  Future<bool> deleteSkip(int skipId) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.deleteSkip(skipId));
      return response.data['success'] == true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString()
          ?? e.response?.data?['error']?.toString()
          ?? e.message
          ?? 'Failed to delete skip';
      throw Exception(msg);
    }
  }

  // ─── Subscription Status & Alerts ────────────────────────────────────────

  Future<Map<String, dynamic>> fetchSubscriptionStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptionStatus);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> fetchSubscriptionAlerts() async {
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

  // ─── Update Start Date ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateStartDate({
    required String entityType,
    required String entityId,
    required String startDate,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiEndpoints.updateStartDate,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'startDate': startDate,
        },
      );
      if (response.data['success'] == true) {
        return response.data;
      }
      throw response.data['message']?.toString() ?? 'Failed to update start date';
    } catch (e) {
      rethrow;
    }
  }
}
