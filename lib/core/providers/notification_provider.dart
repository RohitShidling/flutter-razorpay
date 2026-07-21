import 'package:flutter/material.dart';
import 'package:meal_app/core/network/notification_repository.dart';
import 'package:meal_app/core/models/notification_model.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repository;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  NotificationProvider(this._repository);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _notifications = await _repository.getNotifications();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final success = await _repository.markAsRead(id);
      if (success) {
        // Update locally
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          category: _notifications[index].category,
          payload: _notifications[index].payload,
          isRead: true,
          readAt: DateTime.now(),
          createdAt: _notifications[index].createdAt,
        );
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = _notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    for (final id in unreadIds) {
      await markRead(id);
    }
  }
}
