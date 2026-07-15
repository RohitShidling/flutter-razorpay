import 'package:flutter/material.dart';
import 'package:meal_app/core/models/announcement_model.dart';
import 'package:meal_app/core/network/announcement_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/storage/secure_storage.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementRepository _repository;

  AnnouncementProvider(this._repository) {
    // Load persisted read IDs immediately on startup so the badge
    // reflects the correct unread count before the first fetch completes.
    _loadReadAnnouncements();
    _loadCachedAnnouncements();
  }

  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;
  DateTime? _lastFetchedAt;
  Set<String> _readAnnouncementIds = {};
  String? _currentUserPhone;

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;

  List<AnnouncementModel> getAnnouncementsForLocation(String location) {
    final filtered = _announcements
        .where((a) => a.displayLocation == location || a.displayLocation == 'all')
        .where((a) => a.isActive)
        .toList();
    _sortAnnouncements(filtered);
    return filtered;
  }

  List<AnnouncementModel> getUnreadAnnouncementsForLocation(String location) {
    return getAnnouncementsForLocation(location)
        .where((a) => !_readAnnouncementIds.contains(a.id))
        .toList();
  }

  int getUnreadCountForLocation(String location) {
    return getUnreadAnnouncementsForLocation(location).length;
  }

  Future<void> _ensureUserLoaded() async {
    try {
      final secureStorage = SecureStorage();
      final phone = await secureStorage.getPhoneNumber();
      if (phone != _currentUserPhone) {
        _currentUserPhone = phone;
        if (phone != null && phone.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final key = 'read_announcements_$phone';
          final hasKey = prefs.containsKey(key);
          final readIds = prefs.getStringList(key);
          if (readIds != null) {
            _readAnnouncementIds = readIds.toSet();
          } else {
            _readAnnouncementIds = {};
          }

          // Smart Fallback for fresh login / reinstall:
          // If the user-specific key doesn't exist in SharedPreferences,
          // mark currently fetched announcements older than 24 hours as read
          // to prevent showing a massive unread badge for historical items.
          if (!hasKey && _announcements.isNotEmpty) {
            final now = DateTime.now();
            for (final a in _announcements) {
              final time = a.createdAt ?? a.startDate;
              if (now.difference(time).inHours >= 24) {
                _readAnnouncementIds.add(a.id);
              }
            }
            await prefs.setStringList(key, _readAnnouncementIds.toList());
          }
          notifyListeners();
        } else {
          _readAnnouncementIds = {};
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadReadAnnouncements() async {
    try {
      final secureStorage = SecureStorage();
      final phone = await secureStorage.getPhoneNumber();
      _currentUserPhone = phone;
      final prefs = await SharedPreferences.getInstance();
      if (phone != null && phone.isNotEmpty) {
        final key = 'read_announcements_$phone';
        final readIds = prefs.getStringList(key);
        if (readIds != null) {
          _readAnnouncementIds = readIds.toSet();
          // AUDIT-034 fix: defer notifyListeners to post-frame to avoid build-phase crash
          WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
          return;
        }
      }

      // Fallback to legacy/generic key if any
      final readIds = prefs.getStringList('read_announcement_ids');
      if (readIds != null) {
        _readAnnouncementIds = readIds.toSet();
        // AUDIT-034 fix: defer notifyListeners to post-frame to avoid build-phase crash
        WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      }
    } catch (_) {}
  }

  Future<void> _loadCachedAnnouncements() async {
    try {
      final cached = await CacheStore.getJson('announcements_v1');
      if (cached is List) {
        final loaded = cached.map((a) => AnnouncementModel.fromJson(Map<String, dynamic>.from(a))).toList();
        _sortAnnouncements(loaded);
        _announcements = loaded;
        // AUDIT-034 fix: defer notifyListeners to post-frame to avoid build-phase crash
        WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      }
    } catch (_) {}
  }

  Future<void> _saveReadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserPhone != null && _currentUserPhone!.isNotEmpty) {
        final key = 'read_announcements_$_currentUserPhone';
        await prefs.setStringList(
          key,
          _readAnnouncementIds.toList(),
        );
      } else {
        await prefs.setStringList(
          'read_announcement_ids',
          _readAnnouncementIds.toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String announcementId) async {
    await _ensureUserLoaded();
    if (!_readAnnouncementIds.contains(announcementId)) {
      _readAnnouncementIds.add(announcementId);
      await _saveReadAnnouncements();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    await _ensureUserLoaded();
    final before = _readAnnouncementIds.length;
    for (final a in _announcements) {
      _readAnnouncementIds.add(a.id);
    }
    if (_readAnnouncementIds.length != before) {
      await _saveReadAnnouncements();
      notifyListeners();
    }
  }

  /// Fetches announcements. Pass [force] = true to always hit the network
  /// (e.g. when the user opens the bell or when a new announcement may exist).
  Future<void> fetchAnnouncements({String? location, bool force = false}) async {
    // Ensure we load the user's read state first in case they just logged in
    await _ensureUserLoaded();

    // Skip if recently fetched and not forced — avoids hammering the API
    if (!force && !shouldRefresh()) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await _repository.getAnnouncements(location: location);
      _sortAnnouncements(fetched);
      _announcements = fetched;
      _lastFetchedAt = DateTime.now();

      // Keep read IDs persisted as read to avoid race conditions clearing them
      // when temporary token refreshes or partial fetches happen.
      final serialized = fetched.map((a) => a.toJson()).toList();
      await CacheStore.setJson('announcements_v1', serialized, ttl: const Duration(hours: 6));

      // After fetching, if the user-specific key does not exist yet, initialize it
      if (_currentUserPhone != null && _currentUserPhone!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'read_announcements_$_currentUserPhone';
        if (!prefs.containsKey(key)) {
          final now = DateTime.now();
          for (final a in _announcements) {
            final time = a.createdAt ?? a.startDate;
            if (now.difference(time).inHours >= 24) {
              _readAnnouncementIds.add(a.id);
            }
          }
          await prefs.setStringList(key, _readAnnouncementIds.toList());
        }
      }
    } catch (_) {
      // Keep old data on error — announcements are non-critical
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true if data is stale (older than 5 minutes) or not yet loaded.
  bool shouldRefresh() {
    if (_lastFetchedAt == null) return true;
    return DateTime.now().difference(_lastFetchedAt!).inMinutes >= 5;
  }

  void _sortAnnouncements(List<AnnouncementModel> list) {
    list.sort((a, b) {
      final timeA = a.createdAt ?? a.startDate;
      final timeB = b.createdAt ?? b.startDate;
      return timeB.compareTo(timeA);
    });
  }
}
