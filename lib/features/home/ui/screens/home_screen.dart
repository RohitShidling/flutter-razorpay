import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/ui/screens/children_management_screen.dart';
import 'package:meal_app/features/profile/ui/screens/teacher_management_screen.dart';
import 'package:meal_app/features/profile/ui/screens/professional_management_screen.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/view_all_plans_screen.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_hub_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/core/widgets/app_logo.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';
import 'package:meal_app/features/profile/providers/referral_provider.dart';
import 'package:meal_app/core/navigation/app_routes.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';
import 'package:in_app_update/in_app_update.dart';


import 'package:meal_app/core/services/network_status_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/services/offline_cache_bootstrap.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';
import 'package:meal_app/core/providers/announcement_provider.dart';
import 'package:meal_app/features/quick_service/ui/widgets/quick_order_section.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/core/services/app_update_service.dart';
import 'package:meal_app/features/quick_service/ui/screens/special_dishes_cart_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouteTracker.instance.setCurrent(AppScreen.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapHome();
      context.read<LookupProvider>().fetchContactUsInfo();
      context.read<AnnouncementProvider>().fetchAnnouncements(location: 'home', force: true);
      AppUpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRouteTracker.instance.clearIfCurrent(AppScreen.home);
    AppUpdateService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppUpdateService.checkPendingDownloadedUpdate(context);
    }
  }

  /// Cold start / return-to-home: cache-first essentials, then meal bundle only when online.
  Future<void> _bootstrapHome() async {
    if (!mounted) return;
    await OfflineCacheBootstrap.warmIfNeeded(context);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final forceFresh = auth.consumePendingDashboardRefresh();

    if (forceFresh) {
      await Future.wait([
        context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
        context.read<MenuProvider>().fetchTodayMenu(silent: true),
        context.read<CartProvider>().fetchCart(force: true, silent: true),
        context.read<AuthProvider>().refreshMeProfile(silent: true, forceNetwork: true),
        context.read<ReferralProvider>().fetchRewards(),
        context.read<QuickServiceProvider>().loadCartFromServer(),
        context.read<BulkOrderProvider>().loadCartFromServer(),
        context.read<QuickServiceProvider>().loadOneDayConfig(force: true),
        context.read<QuickServiceProvider>().loadSpecialConfig(force: true),
      ]);
    } else {
      await _loadAllData(); // already calls fetchTodayMenu internally
    }
    if (!mounted) return;
    await _refreshMealDataBundle();
    if (!mounted) return;
    await _maybePromptFourMealsLeftDialog();
    // HIGH-01: Removed the unconditional second fetchTodayMenu call here —
    // _loadAllData() already covers it, causing 2x requests on every cold start.
  }


  Future<void> _loadAllData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<HomepageProvider>().fetchHomepageEntries(silent: true),
      context.read<MenuProvider>().fetchTodayMenu(silent: true),
      context.read<CartProvider>().fetchCart(silent: true),
      context.read<AuthProvider>().refreshMeProfile(silent: true),
      context.read<ReferralProvider>().fetchRewards(),
      context.read<QuickServiceProvider>().loadCartFromServer(),
      context.read<BulkOrderProvider>().loadCartFromServer(),
      context.read<QuickServiceProvider>().loadOneDayConfig(),
      context.read<QuickServiceProvider>().loadSpecialConfig(),
    ]);
  }

  Future<void> _refreshMealDataBundle({bool force = false}) async {
    if (!mounted || !NetworkStatusService.instance.isOnline) return;
    final meal = context.read<MealProvider>();
    await Future.wait([
      meal.fetchAlerts(silent: true, force: force),
      meal.fetchMealStatus(silent: true, force: force),
      meal.fetchSubscriptionStatus(silent: true, force: force),
    ]);
  }

  static const _prefFourMealsDialogDay = 'four_meals_left_dialog_shown_ymd';

  /// In-app renewal nudge when any active line has exactly four meals left (once per session day).
  Future<void> _maybePromptFourMealsLeftDialog() async {
    if (!mounted || !NetworkStatusService.instance.isOnline) return;
    final meal = context.read<MealProvider>();
    final hasFourRow = meal.mealStatus.where((row) {
      if (row is! Map) return false;
      final r = row['remaining_meals'] ?? row['remainingMeals'];
      final n = int.tryParse('$r');
      return n == 4;
    }).firstOrNull;
    if (hasFourRow == null) return;

    final ymd = MealDate.sessionTodayYmd();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefFourMealsDialogDay$ymd';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('4 meals remaining'),
        content: const Text(
          'You have only four meals left on one of your active plans. Renew now so deliveries are not interrupted.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              final entityType = hasFourRow['entity_type']?.toString();
              final entityId = hasFourRow['entity_id']?.toString();
              if (entityType == 'child') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ChildrenManagementScreen(renewChildId: entityId),
                  ),
                );
              } else if (entityType == 'teacher') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => TeacherManagementScreen(renewProfileId: entityId),
                  ),
                );
              } else if (entityType == 'professional') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ProfessionalManagementScreen(renewProfileId: entityId),
                  ),
                );
              } else {
                _openUpgradeWithFirstProfile(context);
              }
            },
            child: const Text('View plans'),
          ),
        ],
      ),
    );
  }

  void _openUpgradeWithFirstProfile(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const SubscriptionManagementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookupProvider = context.watch<LookupProvider>();
    final showAbout = lookupProvider.contactUsInfo?.aboutActive != false;
    final isWide = ResponsiveHelper.isWide(context);
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    final hasPlans = statusData == null ||
        statusData['has_active_subscription'] == true ||
        statusData['has_upcoming_subscription'] == true;

    final quickProvider = context.watch<QuickServiceProvider>();
    final oneDayActive = quickProvider.oneDayConfig?['is_active'] == true;
    final specialActive = quickProvider.specialConfig?['is_active'] == true;
    final showQuickOrder = oneDayActive || specialActive;

    final mealProvider = context.watch<MealProvider>();
    final hasAlerts = mealProvider.alerts.isNotEmpty;
    final showRightColumn = showQuickOrder || hasAlerts;
    
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final navBarColor = isDark ? AppTheme.surfaceDark : pageBg;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: pageBg, isDark: isDark, navigationBarColor: navBarColor),
      child: Scaffold(
      backgroundColor: pageBg,
      bottomNavigationBar: BuuttiiFooterNav(
        currentIndex: 0,
        onHomeTap: () {},
        onWeekMenuTap: () {
          Navigator.of(context).pushNamed(AppRoutes.weeklyMenu);
        },
        onMealSkipTap: () {
          Navigator.of(context).pushNamed(AppRoutes.mealSkip);
        },
        onSettingsTap: () {
          Navigator.of(context).pushNamed(AppRoutes.settings);
        },
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  if (!mounted) return;
                  await Future.wait([
                    context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
                    context.read<MenuProvider>().fetchTodayMenu(force: true, silent: true),
                    context.read<CartProvider>().fetchCart(force: true, silent: true),
                    context.read<AuthProvider>().refreshMeProfile(
                      silent: true,
                      forceNetwork: NetworkStatusService.instance.isOnline,
                    ),
                    context.read<AnnouncementProvider>().fetchAnnouncements(location: 'home', force: true),
                    context.read<QuickServiceProvider>().loadCartFromServer(),
                    context.read<BulkOrderProvider>().loadCartFromServer(),
                    context.read<QuickServiceProvider>().loadOneDayConfig(force: true),
                    context.read<QuickServiceProvider>().loadSpecialConfig(force: true),
                    context.read<LookupProvider>().fetchContactUsInfo(),
                    context.read<LookupProvider>().fetchInitialData(force: true),
                  ]);
                  if (!mounted) return;
                  await _refreshMealDataBundle(force: true);
                  if (!mounted) return;
                  await _maybePromptFourMealsLeftDialog();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.paddingOf(context).top,
                        20,
                        10,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          HomeWelcomeHeader(
                            onCartNavigated: () => _refreshMealDataBundle(force: true),
                          ),
                          const SizedBox(height: 6),
                          const AppUpdateStatusCard(),
                          const SizedBox(height: 6),
                          if (isWide) ...[
                            if (hasPlans)
                              if (showRightColumn)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          UpcomingPlanCard(key: const ValueKey('upcoming_plan_landscape')),
                                          TodayMealCard(key: const ValueKey('today_meal_landscape')),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          QuickOrderSection(key: const ValueKey('quick_order_landscape'), forceVertical: true),
                                          AlertsBanner(key: const ValueKey('alerts_banner_landscape')),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
                                ResponsiveContainer(
                                  maxWidth: 650,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UpcomingPlanCard(key: const ValueKey('upcoming_plan_landscape_nocol')),
                                      TodayMealCard(key: const ValueKey('today_meal_landscape_nocol')),
                                    ],
                                  ),
                                )
                            else
                              ResponsiveContainer(
                                maxWidth: 650,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    QuickOrderSection(key: const ValueKey('quick_order_wide_noplans')),
                                    AlertsBanner(key: const ValueKey('alerts_banner_wide_noplans')),
                                  ],
                                ),
                              ),
                          ] else ...[
                            UpcomingPlanCard(key: const ValueKey('upcoming_plan_portrait')),
                            TodayMealCard(key: const ValueKey('today_meal_portrait')),
                            QuickOrderSection(key: const ValueKey('quick_order_portrait')),
                            AlertsBanner(key: const ValueKey('alerts_banner_portrait')),
                          ],
                          const SizedBox(height: 12),
                          const FeatureQuickLinks(),
                          const SizedBox(height: 12),
                          if (showAbout) const AboutBuuttiiCard(key: ValueKey('about_buuttii_footer')),
                          const SizedBox(height: 30),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: ColoredBox(color: pageBg),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─── EXTRACTED DECOUPLED UI WIDGETS FOR HIERARCHY PERFORMANCE ────────────────

class HomeWelcomeHeader extends StatelessWidget {
  const HomeWelcomeHeader({
    super.key,
    this.onCartNavigated,
  });

  final VoidCallback? onCartNavigated;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = context.watch<AnnouncementProvider>().getUnreadCountForLocation('home');
    final hasBulkCartItems = context.watch<BulkOrderProvider>().hasBulkCartItems;
    final bulkCartTotalMeals = context.watch<BulkOrderProvider>().bulkCartTotalMeals;
    final cartItemCount = context.watch<CartProvider>().itemCount;
    final specialsCartItemCount = context.watch<QuickServiceProvider>().cartItemCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(0, -1),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Buuttii',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnnouncementsButton(context, isDark, unreadCount),
              const SizedBox(width: 4),
              if (hasBulkCartItems) ...[
                _buildBulkCartActionButton(context, isDark, bulkCartTotalMeals),
                const SizedBox(width: 4),
              ],
              if (specialsCartItemCount > 0) ...[
                _buildSpecialsCartActionButton(context, isDark, specialsCartItemCount),
                const SizedBox(width: 4),
              ],
              if (cartItemCount > 0) ...[
                _buildCartActionButton(context, isDark, cartItemCount),
                const SizedBox(width: 4),
              ],
              _buildPlansButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsButton(BuildContext context, bool isDark, int unreadCount) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.announcements);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              CupertinoIcons.bell,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              size: 24,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartActionButton(BuildContext context, bool isDark, int itemCount) {
    final badgeColor = Theme.of(context).colorScheme.error;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const CartScreen()),
        );
        onCartNavigated?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              CupertinoIcons.cart_fill,
              size: 24,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
            if (itemCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    itemCount > 99 ? '99+' : '$itemCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkCartActionButton(BuildContext context, bool isDark, int count) {
    final badgeColor = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
        );
        onCartNavigated?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              CupertinoIcons.bag_fill,
              size: 24,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const ViewAllPlansScreen()),
          );
          context.read<SubscriptionProvider>().fetchSubscriptions(silent: true).catchError((_) {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.square_list_fill, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text(
                'Plans',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    )
    .animate(onPlay: (controller) => controller.repeat())
    .shimmer(duration: 2500.ms, color: Colors.white.withValues(alpha: 0.4))
    .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.02, 1.02), curve: Curves.easeInOut);
  }

  Widget _buildSpecialsCartActionButton(BuildContext context, bool isDark, int count) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const SpecialDishesCartScreen()),
        );
        onCartNavigated?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              CupertinoIcons.star_circle_fill,
              size: 24,
              color: const Color(0xFFFF5722),
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UpcomingPlanCard extends StatelessWidget {
  const UpcomingPlanCard({super.key});

  String _formatUpcomingMessage(BuildContext context, Map<String, dynamic> row) {
    final startYmd = row['start_date']?.toString();
    if (startYmd == null) return '';
    final formattedDate = MealDate.formatDisplay(startYmd);

    // Determine name
    String name = '';
    final rawName = row['entity_name'] ?? row['name'] ?? row['child_name'];
    if (rawName != null && rawName.toString().trim().isNotEmpty) {
      name = rawName.toString().trim();
    } else {
      final entityType = row['entity_type']?.toString();
      final entityId = row['entity_id']?.toString();
      if (entityType == 'child' && entityId != null) {
        final child = context.read<ChildrenProvider>().children.where((c) => c.id?.toString() == entityId).firstOrNull;
        if (child != null) name = child.name;
      } else if (entityType == 'teacher') {
        final tp = context.read<ProfileProvider>().teacherProfile;
        if (tp != null) name = tp.name;
      } else if (entityType == 'professional') {
        final pp = context.read<ProfileProvider>().professionalProfile;
        if (pp != null) name = pp.name;
      }
    }

    if (name.isEmpty) {
      name = 'Profile';
    }

    return "$name will start receiving meals from $formattedDate";
  }

  void _showAllUpcomingPlansSheet(BuildContext context, List<Map<String, dynamic>> upcomingRows, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Upcoming Plans',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: upcomingRows.length,
                      itemBuilder: (context, index) {
                        final row = upcomingRows[index];
                        final message = _formatUpcomingMessage(context, row);
                        final planName = row['plan_name']?.toString() ?? 'Meal Plan';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.calendar_today,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (planName.isNotEmpty)
                                      Text(
                                        planName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    if (statusData == null) return const SizedBox.shrink();

    final list = statusData['entities'] is List
        ? statusData['entities'] as List
        : (statusData['data'] is List ? statusData['data'] as List : const []);

    final today = MealDate.sessionTodayYmd();
    final upcomingRows = list.whereType<Map<String, dynamic>>().where((row) {
      return SubscriptionStatusNormalizer.rowIsUpcoming(row, today);
    }).toList();

    if (upcomingRows.isEmpty) {
      return const SizedBox.shrink();
    }

    upcomingRows.sort((a, b) {
      final aStart = a['start_date']?.toString() ?? '';
      final bStart = b['start_date']?.toString() ?? '';
      return aStart.compareTo(bStart);
    });

    final firstRow = upcomingRows.first;
    final message = _formatUpcomingMessage(context, firstRow);
    if (message.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.calendar_today, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    if (upcomingRows.length > 1)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => _showAllUpcomingPlansSheet(context, upcomingRows, isDark),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Text(
                              '•  View all (${upcomingRows.length})',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayMealCard extends StatelessWidget {
  const TodayMealCard({super.key});

  Widget? _buildPlanStatusBadge(BuildContext context, bool isDark) {
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    if (statusData == null) return null;

    final hasActive = statusData['has_active_subscription'] == true;
    final hasUpcoming = statusData['has_upcoming_subscription'] == true;

    if (hasActive) return null;

    final Color bg;
    final String label;
    if (hasUpcoming) {
      bg = const Color(0xFFD97706);
      label = 'Upcoming Meal Plan';
    } else {
      bg = const Color(0xFF64748B);
      label = 'No Active Meal Plan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMealImage(BuildContext context, String? imageUrl, double height) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceDark
              : const Color(0xFFF7F2EA),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: height,
            fit: BoxFit.contain,
            placeholder: (_, __) => _buildMealPlaceholder(height),
            errorWidget: (_, __, ___) => _buildMealPlaceholder(height),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: _buildMealPlaceholder(height),
    );
  }

  Widget _buildMealPlaceholder(double height) {
    return SkeletonBone(
      height: height,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    final hasActive = statusData?['has_active_subscription'] == true;
    final hasUpcoming = statusData?['has_upcoming_subscription'] == true;

    if (statusData != null && !hasActive && !hasUpcoming) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuProvider = context.watch<MenuProvider>();
    final msg = menuProvider.homeMealMessage?.trim() ?? '';
    if (menuProvider.isLoading && menuProvider.todayMenu == null && msg.isEmpty) {
      return TodayMealCardSkeleton(isDark: isDark);
    }

    if (msg.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.info_circle_fill, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (menuProvider.todayMenu == null) return const SizedBox.shrink();

    final menu = menuProvider.todayMenu!;
    final imageUrl = menu['image_url']?.toString();
    final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Today\'s Meal';
    final nutritionPoints = (menu['nutrition_points'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];

    final planBadge = _buildPlanStatusBadge(context, isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      ImagePreviewDialog.show(context, imageUrl, title: items);
                    }
                  },
                  child: _buildMealImage(context, imageUrl, 180),
                ),
                if (planBadge != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: planBadge,
                  ),
                if (nutritionPoints.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: nutritionPoints.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          return Center(
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                nutritionPoints[i],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      items,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      "Today's Meal",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsBanner extends StatelessWidget {
  const AlertsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mealProvider = context.watch<MealProvider>();
    final alerts = mealProvider.alerts;
    
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
      children: alerts.map<Widget>((alert) {
        final message = alert['message']?.toString() ?? 'Meal Plan expiring soon';
        final remainingDays = alert['remaining_days'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2008) : const Color(0xFFFFF5E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF5C4010) : const Color(0xFFFFDFA6)),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    if (remainingDays != null)
                      Text(
                        '$remainingDays day(s) remaining',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  final entityType = alert['entity_type']?.toString();
                  final entityId = alert['entity_id']?.toString();
                  if (entityType == 'child') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => ChildrenManagementScreen(renewChildId: entityId),
                      ),
                    );
                  } else if (entityType == 'teacher') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => TeacherManagementScreen(renewProfileId: entityId),
                      ),
                    );
                  } else if (entityType == 'professional') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => ProfessionalManagementScreen(renewProfileId: entityId),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const SubscriptionManagementScreen()),
                    );
                  }
                },
                child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        ).animate().fadeIn().slideX(begin: -0.1, end: 0);
      }).toList(),
      ),
    );
  }
}

class FeatureQuickLinks extends StatelessWidget {
  const FeatureQuickLinks({super.key});

  Widget _buildQuickLinkCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = context.watch<HomepageProvider>().entries;

    final List<MapEntry<int, Widget>> orderedCards = [];
    final Set<String> addedTypes = {};

    for (final entry in entries) {
      final name = (entry.entityName ?? '').trim().toLowerCase();
      final order = entry.displayOrder;

      if ((name == 'child' || name == 'children') && !addedTypes.contains('child')) {
        addedTypes.add('child');
        orderedCards.add(MapEntry(
          order,
          _buildQuickLinkCard(
            context: context,
            title: 'Manage Child',
            icon: CupertinoIcons.person_3_fill,
            bgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
            iconColor: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()));
              if (NetworkStatusService.instance.isOnline) context.read<ChildrenProvider>().fetchChildren(silent: true);
            },
          ),
        ));
      } else if (name == 'teacher' && !addedTypes.contains('teacher')) {
        addedTypes.add('teacher');
        orderedCards.add(MapEntry(
          order,
          _buildQuickLinkCard(
            context: context,
            title: 'Teacher Plan',
            icon: CupertinoIcons.book_fill,
            bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
            iconColor: const Color(0xFFD97706),
            isDark: isDark,
            onTap: () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const TeacherManagementScreen()));
              if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
            },
          ),
        ));
      } else if ((name == 'professional' || name == 'profile') && !addedTypes.contains('professional')) {
        addedTypes.add('professional');
        orderedCards.add(MapEntry(
          order,
          _buildQuickLinkCard(
            context: context,
            title: 'Professional Plan',
            icon: CupertinoIcons.briefcase_fill,
            bgColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF),
            iconColor: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfessionalManagementScreen()));
              if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
            },
          ),
        ));
      } else if ((name == 'bulk' || name == 'bulk order' || name == 'bulk_order' || name == 'corporate') && !addedTypes.contains('bulk')) {
        addedTypes.add('bulk');
        orderedCards.add(MapEntry(
          order,
          _buildQuickLinkCard(
            context: context,
            title: 'Bulk Order',
            icon: CupertinoIcons.square_stack_3d_up_fill,
            bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const BulkOrderHubScreen()));
            },
          ),
        ));
      }
    }

    // Sort the cards by display order
    orderedCards.sort((a, b) => a.key.compareTo(b.key));
    final List<Widget> visibleCards = orderedCards.map((e) => e.value).toList();

    if (visibleCards.isEmpty) {
      return const SizedBox.shrink();
    }

    // Partition into rows based on dynamic parent width using Wrap
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Plans',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final parentWidth = constraints.maxWidth;
              final int columnsCount = parentWidth > 900 ? 4 : (parentWidth > 600 ? 3 : 2);
              final double spacing = 12.0;
              final double totalSpacing = (columnsCount - 1) * spacing;
              final double cardWidth = (parentWidth - totalSpacing) / columnsCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                children: visibleCards.map((card) {
                  return SizedBox(
                    width: cardWidth,
                    child: card,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AboutBuuttiiCard extends StatelessWidget {
  const AboutBuuttiiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LookupProvider>();
    final contactInfo = provider.contactUsInfo;
    final aboutTitle = contactInfo?.aboutTitle.trim();
    final aboutDescription = contactInfo?.aboutDescription.trim();
    final title = aboutTitle != null && aboutTitle.isNotEmpty ? aboutTitle : 'About Us';
    final description = aboutDescription != null && aboutDescription.isNotEmpty
        ? aboutDescription
        : "We're committed to healthy, joyful eating for all.";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: AppLogo(
                    height: 48,
                    showFallbackText: false,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF8B7A66),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppUpdateStatusCard extends StatelessWidget {
  const AppUpdateStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<InstallStatus?>(
      valueListenable: AppUpdateService.installStatusNotifier,
      builder: (context, status, child) {
        if (status == null ||
            status == InstallStatus.unknown ||
            status == InstallStatus.installed ||
            status == InstallStatus.canceled) {
          return const SizedBox.shrink();
        }

        final Color cardBg;
        final Color borderCol;
        final Widget leadingIcon;
        final String titleText;
        final String bodyText;
        Widget? actionWidget;

        if (status == InstallStatus.downloading || status == InstallStatus.pending) {
          cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
          borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE);
          leadingIcon = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          );
          titleText = 'Downloading App Update';
          bodyText = 'A new version of the app is downloading in the background. You can continue using the app.';
        } else if (status == InstallStatus.downloaded) {
          cardBg = isDark ? const Color(0xFF2E2008) : const Color(0xFFFFF5E6);
          borderCol = isDark ? const Color(0xFF5C4010) : const Color(0xFFFFDFA6);
          leadingIcon = const Icon(CupertinoIcons.arrow_down_to_line_alt, color: Colors.orange, size: 22);
          titleText = 'Update Ready to Install';
          bodyText = 'The update has been downloaded. Restart the app to apply changes.';
          actionWidget = Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await InAppUpdate.completeFlexibleUpdate();
                } catch (e) {
                  debugPrint('[AppUpdate] Failed to complete flexible update: $e');
                }
              },
              icon: const Icon(CupertinoIcons.refresh_thin, size: 16),
              label: const Text('RESTART NOW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        } else if (status == InstallStatus.failed) {
          cardBg = isDark ? const Color(0xFF2D1F1F) : const Color(0xFFFEF2F2);
          borderCol = isDark ? const Color(0xFF5A2C2C) : const Color(0xFFFCA5A5);
          leadingIcon = const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red, size: 22);
          titleText = 'Update Failed';
          bodyText = 'The update download failed. We will retry later.';
          actionWidget = TextButton(
            onPressed: () => AppUpdateService.checkForUpdate(context),
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
          );
        } else {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: leadingIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (status == InstallStatus.downloading || status == InstallStatus.pending) ...[
                        _DownloadingProgressWidget(isDark: isDark),
                      ] else ...[
                        Text(
                          bodyText,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                      if (actionWidget != null) actionWidget,
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.05, end: 0),
        );
      },
    );
  }
}

class _DownloadingProgressWidget extends StatefulWidget {
  const _DownloadingProgressWidget({required this.isDark});
  final bool isDark;

  @override
  State<_DownloadingProgressWidget> createState() => _DownloadingProgressWidgetState();
}

class _DownloadingProgressWidgetState extends State<_DownloadingProgressWidget> {
  double _progress = 0.05;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) return;
      setState(() {
        if (_progress < 0.65) {
          _progress += 0.05;
        } else if (_progress < 0.88) {
          _progress += 0.02;
        } else if (_progress < 0.98) {
          _progress += 0.005;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading update: $percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white70 : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: widget.isDark ? Colors.white10 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}


