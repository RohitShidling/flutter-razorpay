import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class LookupRepository {
  final DioClient _dioClient;

  LookupRepository(this._dioClient);

  Future<List<SchoolModel>> getSchools({String? search, int? page, int? limit}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.schools,
        queryParameters: {
          if (search != null) 'search': search,
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
        },
      );
      
      if (response.data['success'] == true) {
        final List schools = response.data['data']['schools'];
        return schools.map((s) => SchoolModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<StandardModel>> getStandards() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.standards);
      if (response.data['success'] == true) {
        final List standards = response.data['data']['standards'];
        return standards.map((s) => StandardModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MealSizeModel>> getMealSizes() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSizes);
      if (response.data['success'] == true) {
        final List sizes = response.data['data']['mealSizes'];
        return sizes.map((s) => MealSizeModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<CorporateLocationModel>> getCorporateLocations() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.corporateLocations);
      if (response.data['success'] == true) {
        final List locations = response.data['data'];
        return locations.map((l) => CorporateLocationModel.fromJson(l)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptions);
      if (response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<StateModel>> getStates() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.states);
      if (response.data['success'] == true) {
        final List states = response.data['data'];
        return states.map((s) => StateModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<CityModel>> getCities({int? stateId}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.cities,
        queryParameters: {
          if (stateId != null) 'stateId': stateId,
        },
      );
      if (response.data['success'] == true) {
        final List cities = response.data['data'];
        return cities.map((c) => CityModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<AllowedAddressModel>> getAllowedAddresses({int? cityId}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.allowedAddresses,
        queryParameters: {
          if (cityId != null) 'cityId': cityId,
        },
      );
      if (response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((a) => AllowedAddressModel.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<CompanyModel>> getCompanies({int? cityId}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.companies,
        queryParameters: {
          if (cityId != null) 'cityId': cityId,
        },
      );
      if (response.data['success'] == true) {
        final List companies = response.data['data'];
        return companies.map((c) => CompanyModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<DivisionModel>> getDivisions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.divisions);
      if (response.data['success'] == true) {
        final List divisions = response.data['data']['divisions'];
        return divisions.map((d) => DivisionModel.fromJson(d)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<ContactUsModel?> getContactUsInfo() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.contactUsInfo);
      if (response.data['success'] == true) {
        return ContactUsModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<DeliveryTimeSettingsModel?> getDeliveryTimeSettings() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.deliveryTimeSettings);
      if (response.data['success'] == true) {
        return DeliveryTimeSettingsModel.fromJson(Map<String, dynamic>.from(response.data['data'] ?? {}));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<LoginCarouselImageModel>> getLoginCarouselImages() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.loginCarousel);
      if (response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((img) => LoginCarouselImageModel.fromJson(img)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPublicReferralSettings() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.publicReferralSettings);
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data'] ?? {});
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
