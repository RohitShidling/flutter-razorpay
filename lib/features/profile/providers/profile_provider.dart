import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/offline_queue.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
import 'package:meal_app/features/profile/data/repositories/profile_repository.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileRepository _repository;

  ProfileProvider(this._repository) {
    _loadFromCache();
    NetworkStatusService.instance.addQueueReplayedListener(_onQueueReplayed);
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeQueueReplayedListener(_onQueueReplayed);
    super.dispose();
  }

  void _onQueueReplayed() {
    _lastFetchedAt = null;
    CacheStore.remove('teacher_profiles');
    CacheStore.remove('teacher_profile');
    CacheStore.remove('professional_profiles');
    CacheStore.remove('professional_profile');
    fetchProfiles(force: true, silent: true);
  }

  List<TeacherProfileModel> _teacherProfiles = [];
  List<ProfessionalProfileModel> _professionalProfiles = [];
  Map<String, dynamic>? _profileStatus;
  
  bool _isLoading = false;
  /// Stores the raw error object (DioException or String) so ErrorHandler
  /// can extract the proper server message instead of a raw toString().
  dynamic _error;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightRequest;

  List<TeacherProfileModel> get teacherProfiles => _teacherProfiles;
  List<ProfessionalProfileModel> get professionalProfiles => _professionalProfiles;

  TeacherProfileModel? get teacherProfile => _teacherProfiles.isNotEmpty ? _teacherProfiles.first : null;
  ProfessionalProfileModel? get professionalProfile => _professionalProfiles.isNotEmpty ? _professionalProfiles.first : null;
  Map<String, dynamic>? get profileStatus => _profileStatus;
  bool get isLoading => _isLoading;
  dynamic get error => _error;

  Future<void> _loadFromCache() async {
    try {
      final teacherList = await CacheStore.getJson('teacher_profiles');
      if (teacherList is List) {
        _teacherProfiles = teacherList
            .map((item) => TeacherProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else {
        final teacher = await CacheStore.getJson('teacher_profile');
        if (teacher is Map) {
          _teacherProfiles = [TeacherProfileModel.fromJson(Map<String, dynamic>.from(teacher))];
        }
      }

      final professionalList = await CacheStore.getJson('professional_profiles');
      if (professionalList is List) {
        _professionalProfiles = professionalList
            .map((item) => ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else {
        final professional = await CacheStore.getJson('professional_profile');
        if (professional is Map) {
          _professionalProfiles = [
            ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(professional))
          ];
        }
      }
      notifyListeners();
    } catch (_) {
      // ignore cache read errors
    }
  }

  Future<void> fetchProfiles({bool force = false, bool silent = false}) async {
    final hasAnyProfile = _teacherProfiles.isNotEmpty || _professionalProfiles.isNotEmpty;
    final isFresh = _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inMinutes < 10;
    // Skip if data is fresh in memory (online or offline), unless forced
    if (!force && hasAnyProfile && isFresh) return;
    if (_inflightRequest != null) return _inflightRequest;

    final request = _doFetch(silent: silent);
    _inflightRequest = request;
    try {
      await request;
    } finally {
      _inflightRequest = null;
    }
  }

  Future<void> _doFetch({bool silent = false}) async {
    final hasCachedProfile = _teacherProfiles.isNotEmpty || _professionalProfiles.isNotEmpty;
    if (!silent) {
      if (_teacherProfiles.isEmpty && _professionalProfiles.isEmpty) {
        _isLoading = true;
      }
      _error = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repository.getTeacherProfiles(),
        _repository.getProfessionalProfiles(),
        _repository.getProfileStatus(),
      ]);

      _teacherProfiles = results[0] as List<TeacherProfileModel>;
      _professionalProfiles = results[1] as List<ProfessionalProfileModel>;
      _profileStatus = results[2] as Map<String, dynamic>?;

      await CacheStore.setJson(
        'teacher_profiles',
        _teacherProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      await CacheStore.setJson(
        'professional_profiles',
        _professionalProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );

      _lastFetchedAt = DateTime.now();
    } catch (e) {
      // Keep using cached profile silently in offline mode.
      _error = hasCachedProfile ? null : e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTeacherProfile(TeacherProfileModel profile) async {
    final isUpdate = profile.id != null && profile.id!.isNotEmpty && !profile.id!.startsWith('local-');
    if (!NetworkStatusService.instance.isOnline) {
      final id = profile.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
      final newProfile = TeacherProfileModel(
        id: id,
        name: profile.name,
        schoolCollegeName: profile.schoolCollegeName,
        city: profile.city,
        state: profile.state,
        location: profile.location,
        status: profile.status,
        mealSizeId: profile.mealSizeId,
        mealTime: profile.mealTime,
        standardId: profile.standardId,
        standardName: profile.standardName,
        divisionId: profile.divisionId,
        divisionName: profile.divisionName,
        phoneNumber: profile.phoneNumber,
      );

      await OfflineQueue.enqueue(
        method: isUpdate ? 'PUT' : 'POST',
        path: isUpdate ? ApiEndpoints.teacherProfileWithId(id) : ApiEndpoints.teacherProfiles,
        data: profile.toJson(),
      );

      if (isUpdate) {
        final idx = _teacherProfiles.indexWhere((e) => e.id == id);
        if (idx != -1) {
          _teacherProfiles[idx] = newProfile;
        } else {
          _teacherProfiles.add(newProfile);
        }
      } else {
        _teacherProfiles.add(newProfile);
      }

      notifyListeners();
      await CacheStore.setJson(
        'teacher_profiles',
        _teacherProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _repository.saveTeacherProfileWithId(
        profile,
        isUpdate: isUpdate,
      );
      if (saved != null) {
        if (isUpdate) {
          final idx = _teacherProfiles.indexWhere((e) => e.id == saved.id);
          if (idx != -1) {
            _teacherProfiles[idx] = saved;
          } else {
            _teacherProfiles.add(saved);
          }
        } else {
          _teacherProfiles.add(saved);
        }
        _lastFetchedAt = DateTime.now();
        notifyListeners();
        await fetchProfiles(force: true, silent: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTeacherProfile({String? profileId}) async {
    final id = profileId ?? teacherProfile?.id;
    if (id == null) return false;

    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.teacherProfileWithId(id),
      );
      _teacherProfiles.removeWhere((e) => e.id == id);
      notifyListeners();
      await CacheStore.setJson(
        'teacher_profiles',
        _teacherProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteTeacherProfileWithId(id);
      if (success) {
        _teacherProfiles.removeWhere((e) => e.id == id);
        await CacheStore.setJson(
          'teacher_profiles',
          _teacherProfiles.map((e) => e.toJson()).toList(),
          ttl: const Duration(hours: 12),
        );
        _lastFetchedAt = null; // force fresh fetch next time
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfessionalProfile(ProfessionalProfileModel profile) async {
    final isUpdate = profile.id != null && profile.id!.isNotEmpty && !profile.id!.startsWith('local-');
    if (!NetworkStatusService.instance.isOnline) {
      final id = profile.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
      final newProfile = ProfessionalProfileModel(
        id: id,
        name: profile.name,
        companyName: profile.companyName,
        corporateLocationId: profile.corporateLocationId,
        city: profile.city,
        state: profile.state,
        lunchTime: profile.lunchTime,
        corporateLocationName: profile.corporateLocationName,
        mealSizeId: profile.mealSizeId,
        phoneNumber: profile.phoneNumber,
      );

      await OfflineQueue.enqueue(
        method: isUpdate ? 'PUT' : 'POST',
        path: isUpdate ? ApiEndpoints.professionalProfileWithId(id) : ApiEndpoints.professionalProfiles,
        data: profile.toJson(),
      );

      if (isUpdate) {
        final idx = _professionalProfiles.indexWhere((e) => e.id == id);
        if (idx != -1) {
          _professionalProfiles[idx] = newProfile;
        } else {
          _professionalProfiles.add(newProfile);
        }
      } else {
        _professionalProfiles.add(newProfile);
      }

      notifyListeners();
      await CacheStore.setJson(
        'professional_profiles',
        _professionalProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _repository.saveProfessionalProfileWithId(
        profile,
        isUpdate: isUpdate,
      );
      if (saved != null) {
        if (isUpdate) {
          final idx = _professionalProfiles.indexWhere((e) => e.id == saved.id);
          if (idx != -1) {
            _professionalProfiles[idx] = saved;
          } else {
            _professionalProfiles.add(saved);
          }
        } else {
          _professionalProfiles.add(saved);
        }
        _lastFetchedAt = DateTime.now();
        notifyListeners();
        await fetchProfiles(force: true, silent: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteProfessionalProfile({String? profileId}) async {
    final id = profileId ?? professionalProfile?.id;
    if (id == null) return false;

    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.professionalProfileWithId(id),
      );
      _professionalProfiles.removeWhere((e) => e.id == id);
      notifyListeners();
      await CacheStore.setJson(
        'professional_profiles',
        _professionalProfiles.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteProfessionalProfileWithId(id);
      if (success) {
        _professionalProfiles.removeWhere((e) => e.id == id);
        await CacheStore.setJson(
          'professional_profiles',
          _professionalProfiles.map((e) => e.toJson()).toList(),
          ttl: const Duration(hours: 12),
        );
        _lastFetchedAt = null; // force fresh fetch next time
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearState() {
    _teacherProfiles = [];
    _professionalProfiles = [];
    _profileStatus = null;
    _lastFetchedAt = null;
    _error = null;
    notifyListeners();
  }
}
