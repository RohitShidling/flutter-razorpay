import 'package:flutter/material.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/network/lookup_repository.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/storage/cache_store.dart';

class LookupProvider with ChangeNotifier {
  final LookupRepository _repository;
  static const _cacheKey = 'cache_lookup_initial_v1';

  LookupProvider(this._repository) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final raw = await CacheStore.getJson(_cacheKey);
      if (raw is! Map<String, dynamic>) return;
      final schools = raw['schools'];
      if (schools is List) {
        _schools = schools.map((e) => SchoolModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final standards = raw['standards'];
      if (standards is List) {
        _standards = standards.map((e) => StandardModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final divisions = raw['divisions'];
      if (divisions is List) {
        _divisions = divisions.map((e) => DivisionModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final mealSizes = raw['mealSizes'];
      if (mealSizes is List) {
        _mealSizes = mealSizes.map((e) => MealSizeModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final corps = raw['corporateLocations'];
      if (corps is List) {
        _corporateLocations = corps.map((e) => CorporateLocationModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final subs = raw['subscriptions'];
      if (subs is List) {
        _subscriptions = subs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final states = raw['states'];
      if (states is List) {
        _states = states.map((e) => StateModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final deliveryTimeSettings = raw['deliveryTimeSettings'];
      if (deliveryTimeSettings is Map) {
        _deliveryTimeSettings = DeliveryTimeSettingsModel.fromJson(Map<String, dynamic>.from(deliveryTimeSettings));
      }
      final contactUsInfo = raw['contactUsInfo'];
      if (contactUsInfo is Map) {
        _contactUsInfo = ContactUsModel.fromJson(Map<String, dynamic>.from(contactUsInfo));
      }
      notifyListeners();
    } catch (_) {
      // ignore cache parse errors
    }
  }

  Future<void> _persistCache() async {
    await CacheStore.setJson(_cacheKey, {
      'schools': _schools.map((e) => e.toJson()).toList(),
      'standards': _standards.map((e) => e.toJson()).toList(),
      'divisions': _divisions.map((e) => e.toJson()).toList(),
      'mealSizes': _mealSizes.map((e) => e.toJson()).toList(),
      'corporateLocations': _corporateLocations.map((e) => e.toJson()).toList(),
      'subscriptions': _subscriptions,
      'states': _states.map((e) => e.toJson()).toList(),
      'deliveryTimeSettings': _deliveryTimeSettings?.toJson(),
      'contactUsInfo': _contactUsInfo?.toJson(),
    }, ttl: const Duration(days: 7));
  }

  List<SchoolModel> _schools = [];
  List<StandardModel> _standards = [];
  List<DivisionModel> _divisions = [];
  List<MealSizeModel> _mealSizes = [];
  List<CorporateLocationModel> _corporateLocations = [];
  List<Map<String, dynamic>> _subscriptions = [];
  List<StateModel> _states = [];
  List<CityModel> _cities = [];
  List<CompanyModel> _companies = [];
  List<AllowedAddressModel> _allowedAddresses = [];
  ContactUsModel? _contactUsInfo;
  DeliveryTimeSettingsModel? _deliveryTimeSettings;
  List<LoginCarouselImageModel> _loginCarouselImages = [];
  bool _isReferralActive = true;

  bool _isLoading = false;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightInitialRequest;

  List<SchoolModel> get schools => _schools;
  List<StandardModel> get standards => _standards;
  List<DivisionModel> get divisions => _divisions;
  List<MealSizeModel> get mealSizes => _mealSizes;
  List<CorporateLocationModel> get corporateLocations => _corporateLocations;
  List<Map<String, dynamic>> get subscriptions => _subscriptions;
  List<StateModel> get states => _states;
  List<CityModel> get cities => _cities;
  List<CompanyModel> get companies => _companies;
  List<AllowedAddressModel> get allowedAddresses => _allowedAddresses;
  ContactUsModel? get contactUsInfo => _contactUsInfo;
  DeliveryTimeSettingsModel? get deliveryTimeSettings => _deliveryTimeSettings;
  List<LoginCarouselImageModel> get loginCarouselImages => _loginCarouselImages;
  bool get isReferralActive => _isReferralActive;
  bool get isLoading => _isLoading;


  Future<void> fetchInitialData({bool force = false}) async {
    if (!NetworkStatusService.instance.isOnline) {
      if (_schools.isNotEmpty) return;
      await _loadFromCache();
      return;
    }
    final isFresh = _lastFetchedAt != null && DateTime.now().difference(_lastFetchedAt!).inMinutes < 60;
    final canUseFreshOnly =
        !force &&
        _schools.isNotEmpty &&
        _standards.isNotEmpty &&
        isFresh;
    if (canUseFreshOnly) return;
    if (_inflightInitialRequest != null) return _inflightInitialRequest;
    if (_isLoading) return;

    final request = _doFetchInitialData();
    _inflightInitialRequest = request;
    try {
      await request;
    } finally {
      _inflightInitialRequest = null;
    }
  }

  Future<void> _doFetchInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSchools(),
        _repository.getStandards(),
        _repository.getMealSizes(),
        _repository.getCorporateLocations(),
        _repository.getSubscriptions(),
        _repository.getStates(),
        _repository.getDivisions(),
        _repository.getDeliveryTimeSettings(),
      ]);

      _schools = results[0] as List<SchoolModel>;
      _standards = results[1] as List<StandardModel>;
      _mealSizes = results[2] as List<MealSizeModel>;
      _corporateLocations = results[3] as List<CorporateLocationModel>;
      _subscriptions = results[4] as List<Map<String, dynamic>>;
      _states = results[5] as List<StateModel>;
      _divisions = results[6] as List<DivisionModel>;
      _deliveryTimeSettings = results[7] as DeliveryTimeSettingsModel?;
      _cities = [];
      _companies = [];
      _lastFetchedAt = DateTime.now();
      await _persistCache();
    } catch (e) {
      // keep old cached data for offline fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCitiesByState(int stateId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cities = await _repository.getCities(stateId: stateId);
      _companies = []; // Reset companies when state/city changes
      _allowedAddresses = []; // Reset allowed addresses when state changes
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCompaniesByCity(int cityId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _companies = await _repository.getCompanies(cityId: cityId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllowedAddressesByCity(int cityId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _allowedAddresses = await _repository.getAllowedAddresses(cityId: cityId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSchools(String query) async {
    try {
      _schools = await _repository.getSchools(search: query);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> fetchCorporateLocations() async {
    try {
      _corporateLocations = await _repository.getCorporateLocations();
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<ContactUsModel?> fetchContactUsInfo() async {
    final info = await _repository.getContactUsInfo();
    _contactUsInfo = info;
    notifyListeners();
    return info;
  }

  Future<DeliveryTimeSettingsModel?> fetchDeliveryTimeSettings({bool force = false}) async {
    if (!force && _deliveryTimeSettings != null && !NetworkStatusService.instance.isOnline) {
      return _deliveryTimeSettings;
    }
    final info = await _repository.getDeliveryTimeSettings();
    _deliveryTimeSettings = info;
    await _persistCache();
    notifyListeners();
    return info;
  }

  Future<void> fetchLoginCarousel() async {
    try {
      _loginCarouselImages = await _repository.getLoginCarouselImages();
      notifyListeners();
    } catch (_) {
      // ignore errors during login screen initialization
    }
  }

  Future<void> fetchReferralSettings() async {
    try {
      final res = await _repository.getPublicReferralSettings();
      _isReferralActive = res['isReferEarnActive'] == true;
      notifyListeners();
    } catch (_) {
      // ignore errors, keep default true
    }
  }
}
