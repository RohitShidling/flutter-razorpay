import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:meal_app/core/models/referral_model.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class ReferralRepository {
  final DioClient _dioClient;

  ReferralRepository(this._dioClient);

  Future<List<ReferralRewardModel>> getReferralRewards() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.referralRewards);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List;
        return list.map((r) => ReferralRewardModel.fromJson(r)).toList();
      }
      return [];
    } catch (e, stack) {
      // AUDIT-039 fix: log error instead of silently swallowing it
      debugPrint('[ReferralRepository] Error fetching referral rewards: $e\n$stack');
      rethrow;
    }
  }

  Future<bool> applyReferralCode(String code) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.applyReferralCode,
        data: {'code': code},
      );
      return (response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to apply referral code';
      throw Exception(msg);
    }
  }

  Future<bool> allocateReferralMeals({
    required int rewardId,
    required String entityType,
    required String entityId,
    int? mealsToClaim,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.allocateReferral,
        data: {
          'rewardId': rewardId,
          'entityType': entityType,
          'entityId': entityId,
          if (mealsToClaim != null) 'mealsToClaim': mealsToClaim,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to allocate extra meals';
      throw Exception(msg);
    }
  }

  Future<bool> allocateMultipleReferralMeals({
    required String entityType,
    required String entityId,
    required int totalMealsToClaim,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.allocateReferralMultiple,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'totalMealsToClaim': totalMealsToClaim,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to allocate extra meals';
      throw Exception(msg);
    }
  }
}
