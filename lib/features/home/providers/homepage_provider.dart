import 'package:flutter/material.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/home/data/models/homepage_entry.dart';
import 'package:meal_app/features/home/data/repositories/homepage_repository.dart';

class HomepageProvider with ChangeNotifier {
  final HomepageRepository _repository;

  bool _isLoading = false;
  String _errorMessage = '';
  List<HomepageEntry> _entries = [];
  DateTime? _lastFetchedAt;
  Future<void>? _inflightRequest;
  bool _hasInitiallyLoaded = false;

  HomepageProvider(this._repository) {
    _loadFromCache();
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<HomepageEntry> get entries => _entries;
  bool get hasInitiallyLoaded => _hasInitiallyLoaded;

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheStore.getJsonList('homepage_entries');
      if (cached.isNotEmpty) {
        _entries = cached.map((j) => HomepageEntry.fromJson(j)).toList();
        _hasInitiallyLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // ignore cache read errors
    }
  }

  Future<void> fetchHomepageEntries({bool force = false, bool silent = false}) async {
    final isFresh = _lastFetchedAt != null && DateTime.now().difference(_lastFetchedAt!).inSeconds < 120;
    if (!force && _entries.isNotEmpty && isFresh) return;
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
      // Only show loading if we have no cached data yet.
      if (_entries.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = '';
      notifyListeners();
    }

    try {
      final fresh = await _repository.getHomepageEntries();
      _entries = fresh;
      _lastFetchedAt = DateTime.now();
      _hasInitiallyLoaded = true;
    } catch (e) {
      // Keep cached data on error; don't clear it. Avoid noisy errors when offline
      // but we still have a usable homepage from disk.
      if (_entries.isEmpty) {
        _errorMessage = ErrorHandler.getErrorMessage(e);
      } else {
        _errorMessage = '';
      }
    } finally {
      if (!silent || _entries.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearState() {
    _entries = [];
    _lastFetchedAt = null;
    _hasInitiallyLoaded = false;
    _errorMessage = '';
    notifyListeners();
  }
}
