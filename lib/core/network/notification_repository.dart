import 'package:flutter/foundation.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/models/notification_model.dart';

class NotificationRepository {
  final DioClient _dioClient;

  NotificationRepository(this._dioClient);

  /// Registers the FCM device token on the backend server.
  Future<bool> registerToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'token': token,
          'platform': platform,
          if (deviceId != null) 'deviceId': deviceId,
        },
      );

      return response.data['success'] == true;
    } catch (e, stack) {
      debugPrint('[NotificationRepository] Error registering token: $e\n$stack');
      return false;
    }
  }

  /// Unregisters the FCM device token from the backend server on logout.
  Future<bool> unregisterToken({required String token}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.unregisterDeviceToken,
        data: {
          'token': token,
        },
      );

      return response.data['success'] == true;
    } catch (e, stack) {
      debugPrint('[NotificationRepository] Error unregistering token: $e\n$stack');
      return false;
    }
  }

  /// Fetches notification history for the authenticated client.
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _dioClient.dio.get('/api/client/notifications');
      if (response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((n) => NotificationModel.fromJson(n)).toList();
      }
      return [];
    } catch (e, stack) {
      debugPrint('[NotificationRepository] Error fetching notifications: $e\n$stack');
      return [];
    }
  }

  /// Marks a specific notification as read.
  Future<bool> markAsRead(int id) async {
    try {
      final response = await _dioClient.dio.patch('/api/client/notifications/$id/read');
      return response.data['success'] == true;
    } catch (e, stack) {
      debugPrint('[NotificationRepository] Error marking notification as read: $e\n$stack');
      return false;
    }
  }
}
