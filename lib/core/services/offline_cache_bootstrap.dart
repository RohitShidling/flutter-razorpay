import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';


import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/core/services/network_status_service.dart';
/// Warms home-critical providers after login / cold start (minimal API set).
class OfflineCacheBootstrap {
  OfflineCacheBootstrap._();

  static bool _ranThisSession = false;

  static Future<void> warmIfNeeded(BuildContext context) async {
    if (_ranThisSession) return;
    if (!NetworkStatusService.instance.canAttemptApi) return;

    _ranThisSession = true;
    try {
      final meal = context.read<MealProvider>();
      final menu = context.read<MenuProvider>();
      final auth = context.read<AuthProvider>();
      final cart = context.read<CartProvider>();
      final home = context.read<HomepageProvider>();

      await auth.refreshMeProfile(silent: true);
      await Future.wait([
        meal.fetchSubscriptionStatus(silent: true),
        cart.fetchCart(silent: true),
        home.fetchHomepageEntries(force: true, silent: true),
        meal.fetchMealStatus(),
        meal.fetchAlerts(),
      ]);

      if (meal.isSubscribed) {
        await menu.fetchTodayMenu(silent: true);
      }
    } catch (_) {
      _ranThisSession = false;
    }
  }

  static void resetSession() {
    _ranThisSession = false;
  }

  /// Clears in-memory state of critical providers. Call this on logout or account switch.
  static void clearMemory(BuildContext context) {
    try {
      context.read<ChildrenProvider>().clearState();
      context.read<ProfileProvider>().clearState();
      context.read<MealProvider>().clearState();
      context.read<CartProvider>().resetLocal();
      context.read<SubscriptionProvider>().clearState();
      context.read<MenuProvider>().clearState();
      context.read<HomepageProvider>().clearState();
      context.read<BulkOrderProvider>().clearState();
      context.read<QuickServiceProvider>().clearState();
    } catch (_) {
      // Best effort memory clearing
    }
  }
}
