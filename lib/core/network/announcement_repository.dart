
import 'package:flutter/foundation.dart';
import 'package:meal_app/core/models/announcement_model.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class AnnouncementRepository {
  final DioClient _dioClient;

  AnnouncementRepository(this._dioClient);

  Future<List<AnnouncementModel>> getAnnouncements({String? location}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.announcements,
        queryParameters: {
          if (location != null) 'location': location,
        },
      );

      if (response.data['success'] == true) {
        final List announcements = response.data['data'];
        return announcements.map((a) => AnnouncementModel.fromJson(a)).toList();
      }
      return [];
    } catch (e, stack) {
      // AUDIT-033 fix: log error instead of silently swallowing it
      debugPrint('[AnnouncementRepository] Error fetching announcements: $e\n$stack');
      rethrow;
    }
  }
}
