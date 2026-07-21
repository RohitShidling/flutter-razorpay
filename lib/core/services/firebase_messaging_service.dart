import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/main.dart' show navigatorKey;
import 'package:meal_app/firebase_options.dart';
import 'package:meal_app/core/services/local_notification_service.dart';
import 'package:meal_app/core/network/notification_repository.dart';
import 'package:meal_app/core/storage/secure_storage.dart';
import 'package:meal_app/core/services/network_status_service.dart';

// Import target destination screens for deep linking
import 'package:meal_app/features/subscription/ui/screens/wallet_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/features/home/ui/screens/weekly_menu_screen.dart';
import 'package:meal_app/features/announcements/ui/screens/announcements_screen.dart';
import 'package:meal_app/features/profile/ui/screens/refer_earn_screen.dart';

/// Top-level background message handler for Firebase Messaging.
/// This must be a top-level or static function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dev.log('Handling background message: ${message.messageId}');
  } catch (e) {
    dev.log('Error initializing Firebase in background handler: $e');
  }
}

/// Service to handle Firebase Messaging configuration and setup.
class FirebaseMessagingService {
  // Private constructor
  FirebaseMessagingService._();

  // Singleton instance
  static final FirebaseMessagingService _instance = FirebaseMessagingService._();

  // Public getter for instance
  static FirebaseMessagingService get instance => _instance;

  // Factory constructor
  factory FirebaseMessagingService() => _instance;

  late final LocalNotificationService _localNotificationService;
  NotificationRepository? _notificationRepository;

  static const String _prefLastTokenKey = 'last_synced_fcm_token';
  static const String _prefLastSyncTimeKey = 'last_synced_fcm_time';
  static const String _prefPendingSyncKey = 'fcm_token_sync_pending';

  /// Sets the notification repository and triggers a synchronization attempt.
  void setNotificationRepository(NotificationRepository repository) {
    _notificationRepository = repository;
    dev.log('[FCM Service] NotificationRepository injected successfully.');
    // Trigger sync in case any registration is pending
    syncToken();
  }

  /// Initializes Firebase messaging, requests permissions, gets the token, and listens to messages.
  Future<void> init(LocalNotificationService localNotificationService) async {
    _localNotificationService = localNotificationService;
    try {
      // 1. Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      dev.log('FCM background message handler registered.');

      // 2. Request permissions
      await _requestPermissions();

      // 3. Obtain and log FCM token
      await _getAndLogFcmToken();

      // 4. Listen to FCM token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        dev.log('FCM Token Refreshed: $token');
        syncToken(force: true);
      });

      // 5. Configure foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Listen for foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        dev.log('Received foreground message: messageId=${message.messageId}');
        _localNotificationService.showNotification(message);
      });

      // 7. Handle notification taps when app is opened from a notification (background state)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        dev.log('FCM message opened app: messageId=${message.messageId}');
        handleNotificationNavigation(message);
      });

      // 8. Handle terminated-app notification launches
      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        dev.log('App launched from terminated state via notification: messageId=${initialMessage.messageId}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(initialMessage);
        });
      }

      // 9. Listen to network connectivity changes for offline retry
      NetworkStatusService.instance.addListener(_onNetworkStatusChanged);
    } catch (e) {
      dev.log('Error during FirebaseMessagingService initialization: $e');
    }
  }

  /// Callback when device goes online. Attempts to retry any pending token sync.
  void _onNetworkStatusChanged() {
    if (NetworkStatusService.instance.isOnline) {
      syncToken();
    }
  }

  /// Request notification permissions for Firebase and local notifications.
  Future<void> _requestPermissions() async {
    try {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      dev.log('FCM authorization status: ${settings.authorizationStatus}');

      // Request permissions on LocalNotificationService for local trigger/Android 13+
      await _localNotificationService.requestPermissions();
    } catch (e) {
      dev.log('Error requesting notification permissions: $e');
    }
  }

  /// Obtains and logs the Firebase Cloud Messaging device token.
  Future<void> _getAndLogFcmToken() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        dev.log('FCM Token: $token');
      } else {
        dev.log('FCM Token is null');
      }
    } catch (e) {
      dev.log('Error obtaining FCM token: $e');
    }
  }

  /// Synchronizes the current FCM token with the backend server.
  /// Skips unnecessary uploads if the token is already synchronized and hasn't changed.
  /// Handles offline status by queuing the synchronization for automatic retry.
  Future<void> syncToken({bool force = false}) async {
    try {
      final secureStorage = SecureStorage();
      final accessToken = await secureStorage.getAccessToken();
      
      // Do not upload if the user is not authenticated
      if (accessToken == null || accessToken.isEmpty) {
        dev.log('[FCM Sync] User not authenticated. Skipping FCM token sync.');
        return;
      }

      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        dev.log('[FCM Sync] Cannot obtain FCM token. Skipping sync.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final String? lastSyncedToken = prefs.getString(_prefLastTokenKey);
      final int lastSyncedTime = prefs.getInt(_prefLastSyncTimeKey) ?? 0;
      final bool pendingSync = prefs.getBool(_prefPendingSyncKey) ?? false;

      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Verify if token is synchronized or needs an update (every 12 hours to update last_seen_at)
      final bool needsSync = force ||
          pendingSync ||
          token != lastSyncedToken ||
          (now - lastSyncedTime) > 12 * 60 * 60 * 1000;

      if (!needsSync) {
        dev.log('[FCM Sync] Token is already synchronized. Skipping API upload.');
        return;
      }

      // Offline Support: if offline, queue the registration for auto-retry
      if (!NetworkStatusService.instance.isOnline) {
        dev.log('[FCM Sync] Device is offline. Queuing FCM token sync.');
        await prefs.setBool(_prefPendingSyncKey, true);
        return;
      }

      // If repository isn't injected yet, defer sync
      if (_notificationRepository == null) {
        dev.log('[FCM Sync] NotificationRepository not ready. Queuing sync.');
        await prefs.setBool(_prefPendingSyncKey, true);
        return;
      }

      final String platform = Platform.isAndroid ? 'android' : 'ios';
      
      dev.log('[FCM Sync] Synchronizing FCM token with backend...');
      final success = await _notificationRepository!.registerToken(
        token: token,
        platform: platform,
      );

      if (success) {
        await prefs.setString(_prefLastTokenKey, token);
        await prefs.setInt(_prefLastSyncTimeKey, now);
        await prefs.setBool(_prefPendingSyncKey, false);
        dev.log('[FCM Sync] FCM token successfully synchronized with backend.');
      } else {
        dev.log('[FCM Sync] FCM token synchronization failed. Queued for retry.');
        await prefs.setBool(_prefPendingSyncKey, true);
      }
    } catch (e) {
      dev.log('[FCM Sync] Error synchronizing FCM token: $e');
    }
  }

  /// Inform the backend that the token should be unregistered, and clear local cache.
  Future<void> handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLastTokenKey);
      await prefs.remove(_prefLastSyncTimeKey);
      await prefs.remove(_prefPendingSyncKey);

      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty && _notificationRepository != null) {
        // Discard session token on server side
        await _notificationRepository!.unregisterToken(token: token);
        dev.log('[FCM Sync] FCM token successfully unregistered from backend.');
      }
    } catch (e) {
      dev.log('[FCM Sync] Error during unregistration on logout: $e');
    }
  }

  /// Routes users to the correct screen based on target categories/types inside custom data payload.
  void handleNotificationNavigation(RemoteMessage message) {
    handleNotificationNavigationFromPayload(message.data);
  }

  /// Routes users to the correct screen based on target categories/types inside custom data payload.
  void handleNotificationNavigationFromPayload(Map<String, dynamic> data) {
    try {
      final category = data['category'] ?? data['type'];
      if (category == null) return;

      dev.log('[FCM Routing] Handling notification payload navigation: Category/Type: $category');

      final context = navigatorKey.currentContext;
      if (context == null) {
        dev.log('[FCM Routing] Navigator context is null. Deferring navigation.');
        return;
      }

      Widget? destination;
      if (category == 'payment' || category == 'wallet') {
        destination = const WalletScreen();
      } else if (category == 'order' || category == 'subscription') {
        destination = const SubscriptionManagementScreen();
      } else if (category == 'weekly_menu') {
        destination = const WeeklyMenuScreen();
      } else if (category == 'announcement') {
        destination = const AnnouncementsScreen();
      } else if (category == 'referral') {
        destination = const ReferEarnScreen();
      }

      if (destination != null) {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => destination!),
        );
      } else {
        dev.log('[FCM Routing] Unknown navigation category/type: $category');
      }
    } catch (e) {
      dev.log('[FCM Routing] Error executing deep link navigation: $e');
    }
  }
}
