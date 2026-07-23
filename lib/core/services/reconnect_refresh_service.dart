import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';

/// Refreshes only the APIs relevant to the screen the user is currently viewing.
class ReconnectRefreshCoordinator extends StatefulWidget {
  final Widget child;

  const ReconnectRefreshCoordinator({super.key, required this.child});

  @override
  State<ReconnectRefreshCoordinator> createState() => _ReconnectRefreshCoordinatorState();
}

class _ReconnectRefreshCoordinatorState extends State<ReconnectRefreshCoordinator> {
  bool _refreshing = false;
  late final DateTime _appStartTime;

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now();
    NetworkStatusService.instance.addBecameOnlineListener(_onBecameOnline);
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeBecameOnlineListener(_onBecameOnline);
    super.dispose();
  }

  void _onBecameOnline() {
    if (!mounted || _refreshing) return;
    // Guard against redundant force-refreshing immediately after cold start bootstrap
    if (DateTime.now().difference(_appStartTime).inSeconds < 10) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshForCurrentScreen());
  }

  Future<void> _refreshForCurrentScreen() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      final cart = context.read<CartProvider>();
      final meal = context.read<MealProvider>();
      final menu = context.read<MenuProvider>();
      final auth = context.read<AuthProvider>();
      final home = context.read<HomepageProvider>();
      final children = context.read<ChildrenProvider>();
      final profile = context.read<ProfileProvider>();
      final payment = context.read<PaymentProvider>();
      final lookup = context.read<LookupProvider>();
      final quick = context.read<QuickServiceProvider>();

      await NetworkStatusService.instance.refreshNow();
      if (!mounted) return;
      if (!NetworkStatusService.instance.isBackendReachable) return;

      await cart.syncOfflineItemsIfAny();

      // All per-screen API calls are in a single consolidated batch.
      // Previously there was an unawaited pre-fetch group above the switch that
      // duplicated cart / children / meal-status / subscriptionStatus calls —
      // this caused 2x simultaneous requests on every reconnect (CRITICAL-03).
      final screen = AppRouteTracker.instance.current;

      switch (screen) {
        case AppScreen.home:
          await Future.wait([
            auth.refreshMeProfile(silent: true),
            home.fetchHomepageEntries(force: true, silent: true),
            cart.fetchCart(force: true, silent: true),
            meal.fetchSubscriptionStatus(silent: true),
            meal.fetchMealStatus(silent: true),
            meal.fetchAlerts(silent: true),
            quick.loadOneDayConfig(force: true),
            quick.loadSpecialConfig(force: true),
          ]);
          if (meal.isSubscribed) {
            await menu.fetchTodayMenu(silent: true);
          }
          break;


        case AppScreen.subscriptionManagement:
          await meal.fetchSubscriptionStatus(silent: true);
          await Future.wait([
            payment.fetchActiveSubscriptions(),
            payment.fetchPaymentHistory(),
            children.fetchChildren(force: true),
            profile.fetchProfiles(force: true),
          ]);
          break;

        case AppScreen.cart:
          await cart.fetchCart(force: true);
          await meal.fetchSubscriptionStatus(silent: true);
          break;

        case AppScreen.children:
          await Future.wait([
            children.fetchChildren(force: true),
            lookup.fetchChildrenLookups(force: true),
            meal.fetchSubscriptionStatus(silent: true),
          ]);
          break;

        case AppScreen.teacherProfile:
          await Future.wait([
            profile.fetchProfiles(force: true),
            lookup.fetchTeacherLookups(force: true),
            meal.fetchSubscriptionStatus(silent: true),
            cart.fetchCart(force: true, silent: true),
          ]);
          break;

        case AppScreen.professionalProfile:
          await Future.wait([
            profile.fetchProfiles(force: true),
            lookup.fetchProfessionalLookups(force: true),
            meal.fetchSubscriptionStatus(silent: true),
            cart.fetchCart(force: true, silent: true),
          ]);
          break;

        case AppScreen.mealSkip:
          await Future.wait([
            meal.fetchSubscriptionStatus(silent: true),
            meal.fetchSkips(),
            meal.fetchMealStatus(),
          ]);
          break;

        case AppScreen.weeklyMenu:
          await meal.fetchSubscriptionStatus(silent: true);
          await menu.fetchWeeklyMenu();
          break;

        case AppScreen.settings:
        case AppScreen.other:
          await meal.fetchSubscriptionStatus(silent: true);
          break;
      }
    } catch (_) {
      // Best-effort per-screen refresh.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
