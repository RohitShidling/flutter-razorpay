import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/models/referral_model.dart';
import 'package:meal_app/core/network/referral_repository.dart';
import 'package:meal_app/core/storage/cache_store.dart';

class ReferralProvider with ChangeNotifier {
  final ReferralRepository _repository;

  ReferralProvider(this._repository) {
    _loadCachedRewards();
  }

  List<ReferralRewardModel> _rewards = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSeenTime;
  DateTime? _lastRewardsFetchedAt;

  List<ReferralRewardModel> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool _isRewardsFresh() =>
      _lastRewardsFetchedAt != null &&
      DateTime.now().difference(_lastRewardsFetchedAt!).inMinutes < 30;

  Future<void> _loadCachedRewards() async {
    try {
      final cached = await CacheStore.getJson('referral_rewards');
      if (cached is List) {
        _rewards = cached
            .map((e) => ReferralRewardModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        // AUDIT-038 fix: defer notifyListeners to post-frame to avoid build-phase crash
        WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      }
    } catch (_) {}
  }

  Future<void> fetchRewards({bool force = false}) async {
    // Skip API if data is fresh in memory
    if (!force && _rewards.isNotEmpty && _isRewardsFresh()) return;

    if (_rewards.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _rewards = await _repository.getReferralRewards();
      _lastRewardsFetchedAt = DateTime.now();
      await CacheStore.setJson(
        'referral_rewards',
        _rewards.map((r) => r.toJson()).toList(),
        ttl: const Duration(hours: 6),
      );
      if (_lastSeenTime == null) {
        final prefs = await SharedPreferences.getInstance();
        final timeStr = prefs.getString('referral_rewards_last_seen');
        if (timeStr != null) {
          _lastSeenTime = DateTime.tryParse(timeStr);
        }
      }
    } catch (e) {
      _errorMessage = _rewards.isNotEmpty ? null : e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.applyReferralCode(code);
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get hasUnclaimedRewards {
    if (_lastSeenTime == null) {
      return _rewards.any((r) => r.mealsRemaining > 0);
    }
    return _rewards.any((r) => r.mealsRemaining > 0 && r.createdAt.isAfter(_lastSeenTime!));
  }

  Future<void> markRewardsAsSeen() async {
    _lastSeenTime = DateTime.now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('referral_rewards_last_seen', _lastSeenTime!.toIso8601String());
    } catch (_) {}
  }

  Future<bool> allocateMeals({
    required int rewardId,
    required String entityType,
    required String entityId,
    int? mealsToClaim,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.allocateReferralMeals(
        rewardId: rewardId,
        entityType: entityType,
        entityId: entityId,
        mealsToClaim: mealsToClaim,
      );
      if (success) {
        await fetchRewards();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> allocateMultipleMeals({
    required String entityType,
    required String entityId,
    required int totalMealsToClaim,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.allocateMultipleReferralMeals(
        entityType: entityType,
        entityId: entityId,
        totalMealsToClaim: totalMealsToClaim,
      );
      if (success) {
        await fetchRewards();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      await fetchRewards();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
