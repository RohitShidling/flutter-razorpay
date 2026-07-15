import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/offline_queue.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/features/children/data/models/child_model.dart';
import 'package:meal_app/features/children/data/repositories/children_repository.dart';

class ChildrenProvider with ChangeNotifier {
  final ChildrenRepository _repository;

  ChildrenProvider(this._repository) {
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
    CacheStore.remove('children_list');
    fetchChildren(force: true, silent: true);
  }

  List<ChildModel> _children = [];
  bool _isLoading = false;
  /// Stores the raw error object (DioException or String) so ErrorHandler
  /// can extract the proper server message.
  dynamic _error;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightRequest;

  List<ChildModel> get children => _children;
  bool get isLoading => _isLoading;
  dynamic get error => _error;

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheStore.getJsonList('children_list');
      if (cached.isNotEmpty) {
        _children = cached.map(ChildModel.fromJson).toList();
        notifyListeners();
      }
    } catch (_) {
      // ignore cache issues
    }
  }

  Future<void> fetchChildren({bool force = false, bool silent = false}) async {
    final isFresh = _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inMinutes < 5;
    // Skip if data is fresh in memory (online or offline), unless forced
    if (!force && _children.isNotEmpty && isFresh) return;
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
    if (!silent) {
      if (_children.isEmpty) _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _children = await _repository.getChildren();
      _lastFetchedAt = DateTime.now();
      // Persist to cache so data is available offline
      await CacheStore.setJson(
        'children_list',
        _children.map((c) => c.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addChild(ChildModel child) async {
    if (!NetworkStatusService.instance.isOnline) {
      // Queue write for later replay.
      await OfflineQueue.enqueue(
        method: 'POST',
        path: ApiEndpoints.children,
        data: {
          'children': [child.toJson()],
        },
      );

      // Optimistic local update (temporary id until synced).
      final optimistic = ChildModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: child.name,
        rollNumber: child.rollNumber,
        schoolId: child.schoolId,
        standardId: child.standardId,
        mealSizeId: child.mealSizeId,
        mealTime: child.mealTime,
        schoolName: child.schoolName,
        standardName: child.standardName,
        mealSizeName: child.mealSizeName,
        divisionId: child.divisionId,
        divisionName: child.divisionName,
        phoneNumber: child.phoneNumber,
      );
      _children = [..._children, optimistic];
      notifyListeners();
      
      await CacheStore.setJson(
        'children_list',
        _children.map((c) => c.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final registeredChildren = await _repository.registerChildren([child]);
      if (registeredChildren.isNotEmpty) {
        await fetchChildren(force: true);
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

  Future<bool> updateChild(String id, ChildModel child) async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'PUT',
        path: ApiEndpoints.child(id),
        data: child.toJson(),
      );

      _children = _children
          .map((c) => c.id == id
              ? ChildModel(
                  id: id,
                  name: child.name,
                  rollNumber: child.rollNumber,
                  schoolId: child.schoolId,
                  standardId: child.standardId,
                  mealSizeId: child.mealSizeId,
                  mealTime: child.mealTime,
                  schoolName: child.schoolName ?? c.schoolName,
                  standardName: child.standardName ?? c.standardName,
                  mealSizeName: child.mealSizeName ?? c.mealSizeName,
                  divisionId: child.divisionId ?? c.divisionId,
                  divisionName: child.divisionName ?? c.divisionName,
                  phoneNumber: child.phoneNumber ?? c.phoneNumber,
                )
              : c)
          .toList();
      notifyListeners();
      
      await CacheStore.setJson(
        'children_list',
        _children.map((c) => c.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.updateChild(id, child);
      if (success) {
        await fetchChildren(force: true);
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

  Future<bool> deleteChild(String id) async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.child(id),
      );
      _children = _children.where((c) => c.id != id).toList();
      notifyListeners();
      
      await CacheStore.setJson(
        'children_list',
        _children.map((c) => c.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteChild(id);
      if (success) {
        await fetchChildren(force: true);
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
    _children = [];
    _lastFetchedAt = null;
    _error = null;
    notifyListeners();
  }
}
