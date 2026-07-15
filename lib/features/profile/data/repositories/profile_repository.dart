
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';

class ProfileRepository {
  final DioClient _dioClient;

  ProfileRepository(this._dioClient);

  // Teacher Profile
  Future<TeacherProfileModel?> getTeacherProfile() async {
    const cacheKey = 'teacher_profile';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.teacherProfile);
      if (response.data['success'] == true && response.data['data'] != null) {
        await CacheStore.setJson(cacheKey, response.data['data']);
        return TeacherProfileModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is Map) {
        return TeacherProfileModel.fromJson(Map<String, dynamic>.from(cached));
      }
      return null;
    }
  }

  Future<TeacherProfileModel?> saveTeacherProfile(TeacherProfileModel profile, {bool isUpdate = false}) async {
    try {
      final response = isUpdate 
        ? await _dioClient.dio.put(ApiEndpoints.teacherProfile, data: profile.toJson())
        : await _dioClient.dio.post(ApiEndpoints.teacherProfile, data: profile.toJson());
      if (response.data['success'] == true && response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        await CacheStore.setJson('teacher_profile', data);
        return TeacherProfileModel.fromJson(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTeacherProfile() async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.teacherProfile);
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  // Professional Profile
  Future<ProfessionalProfileModel?> getProfessionalProfile() async {
    const cacheKey = 'professional_profile';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.professionalProfile);
      if (response.data['success'] == true && response.data['data'] != null) {
        await CacheStore.setJson(cacheKey, response.data['data']);
        return ProfessionalProfileModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is Map) {
        return ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(cached));
      }
      return null;
    }
  }

  Future<ProfessionalProfileModel?> saveProfessionalProfile(ProfessionalProfileModel profile, {bool isUpdate = false}) async {
    try {
      final response = isUpdate 
        ? await _dioClient.dio.put(ApiEndpoints.professionalProfile, data: profile.toJson())
        : await _dioClient.dio.post(ApiEndpoints.professionalProfile, data: profile.toJson());
      if (response.data['success'] == true && response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        await CacheStore.setJson('professional_profile', data);
        return ProfessionalProfileModel.fromJson(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteProfessionalProfile() async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.professionalProfile);
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  // Plural Teacher Profiles
  Future<List<TeacherProfileModel>> getTeacherProfiles() async {
    const cacheKey = 'teacher_profiles';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.teacherProfiles);
      if (response.data['success'] == true && response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((item) => TeacherProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        await CacheStore.setJson(cacheKey, response.data['data']);
        return list;
      }
      return [];
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is List) {
        return cached
            .map((item) => TeacherProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    }
  }

  Future<TeacherProfileModel?> saveTeacherProfileWithId(TeacherProfileModel profile, {bool isUpdate = false}) async {
    try {
      final url = isUpdate 
        ? ApiEndpoints.teacherProfileWithId(profile.id ?? '')
        : ApiEndpoints.teacherProfiles;
      final response = isUpdate 
        ? await _dioClient.dio.put(url, data: profile.toJson())
        : await _dioClient.dio.post(url, data: profile.toJson());
      if (response.data['success'] == true && response.data['data'] != null) {
        return TeacherProfileModel.fromJson(Map<String, dynamic>.from(response.data['data']));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTeacherProfileWithId(String id) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.teacherProfileWithId(id));
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  // Plural Professional Profiles
  Future<List<ProfessionalProfileModel>> getProfessionalProfiles() async {
    const cacheKey = 'professional_profiles';
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.professionalProfiles);
      if (response.data['success'] == true && response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((item) => ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        await CacheStore.setJson(cacheKey, response.data['data']);
        return list;
      }
      return [];
    } catch (e) {
      final cached = await CacheStore.getJson(cacheKey);
      if (cached is List) {
        return cached
            .map((item) => ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    }
  }

  Future<ProfessionalProfileModel?> saveProfessionalProfileWithId(ProfessionalProfileModel profile, {bool isUpdate = false}) async {
    try {
      final url = isUpdate 
        ? ApiEndpoints.professionalProfileWithId(profile.id ?? '')
        : ApiEndpoints.professionalProfiles;
      final response = isUpdate 
        ? await _dioClient.dio.put(url, data: profile.toJson())
        : await _dioClient.dio.post(url, data: profile.toJson());
      if (response.data['success'] == true && response.data['data'] != null) {
        return ProfessionalProfileModel.fromJson(Map<String, dynamic>.from(response.data['data']));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteProfessionalProfileWithId(String id) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.professionalProfileWithId(id));
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfileStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.me);
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
