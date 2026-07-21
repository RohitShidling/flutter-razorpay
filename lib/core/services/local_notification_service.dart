import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meal_app/core/services/firebase_messaging_service.dart';

/// Service to handle local notifications (especially in the foreground).
class LocalNotificationService {
  // Private constructor
  LocalNotificationService._();

  // Singleton instance
  static final LocalNotificationService _instance = LocalNotificationService._();

  // Public getter for instance
  static LocalNotificationService get instance => _instance;

  // Factory constructor
  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription =
      'This channel is used for displaying foreground push notifications.';

  /// Initializes the local notifications plugin and creates the Android channel.
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channel
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);
        dev.log('Android notification channel created successfully.');
      }
    } catch (e) {
      dev.log('Error initializing LocalNotificationService: $e');
    }
  }

  /// Handles user tapping on a notification.
  void _onNotificationTapped(NotificationResponse response) {
    dev.log('Local Notification Tapped: id=${response.id}, payload=${response.payload}');
    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(response.payload!));
        // Route this to the deep-link handler in FirebaseMessagingService
        FirebaseMessagingService().handleNotificationNavigationFromPayload(data);
      }
    } catch (e) {
      dev.log('Error parsing tapped notification payload: $e');
    }
  }

  /// Request permissions for Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    // For Android 13+ (API 33+)
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      dev.log('Android 13+ local notification permission granted: $granted');
      return granted ?? false;
    }

    // For iOS
    final iosPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      dev.log('iOS local notification permission granted: $granted');
      return granted ?? false;
    }

    return false;
  }

  /// Displays an incoming RemoteMessage as a local notification.
  Future<void> showNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final AppleNotification? ios = message.notification?.apple;
    final AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      final int id = notification.hashCode;
      final String title = notification.title ?? '';
      final String body = notification.body ?? '';

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: ios?.subtitle,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _localNotificationsPlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: jsonEncode(message.data),
        );
        dev.log('Foreground notification displayed: id=$id');
      } catch (e) {
        dev.log('Error displaying local notification: $e');
      }
    }
  }
}
