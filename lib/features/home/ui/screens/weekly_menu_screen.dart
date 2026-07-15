import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/navigation/app_routes.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';


class WeeklyMenuScreen extends StatefulWidget {
  const WeeklyMenuScreen({super.key});

  @override
  State<WeeklyMenuScreen> createState() => _WeeklyMenuScreenState();
}

class _WeeklyMenuScreenState extends State<WeeklyMenuScreen> {
  List<String> _nutritionPointsFrom(dynamic menu) {
    final raw = menu is Map ? menu['nutrition_points'] : null;
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return [];
      try {
        final decoded = jsonDecode(text);
        return _nutritionPointsFrom({'nutrition_points': decoded});
      } catch (_) {
        return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map) {
            final text = e['nutrition_text'] ?? e['text'] ?? e['point'] ?? e['label'] ?? e['name'];
            return text?.toString() ?? '';
          }
          return e.toString();
        })
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.weeklyMenu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().fetchWeeklyMenuSilent(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.weeklyMenu);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final navBarColor = isDark ? AppTheme.surfaceDark : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(background: pageBg, isDark: isDark, navigationBarColor: navBarColor),
        child: Scaffold(
          backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : AppTheme.textPrimaryLight,
          scrolledUnderElevation: 0,
          toolbarHeight: 84,
          centerTitle: false,
          titleSpacing: 20,
          title: Text(
            'Weekly Menu',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.2,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<MenuProvider>().fetchWeeklyMenu(forceRefresh: true),
          child: _buildBody(context, menuProvider, isDark),
        ),
        bottomNavigationBar: BuuttiiFooterNav(
          currentIndex: 1,
          onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          onWeekMenuTap: () {},
          onMealSkipTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.mealSkip),
          onSettingsTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.settings),
        ),
       ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MenuProvider menuProvider, bool isDark) {
    if (menuProvider.isLoading && menuProvider.weeklyMenu.isEmpty) {
      final width = MediaQuery.sizeOf(context).width;
      final int cols = width > 1150 ? 3 : (width > 750 ? 2 : 1);

      if (cols == 1) {
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          itemCount: 5,
          itemBuilder: (context, index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: WeeklyMealCardSkeleton(),
            );
          },
        );
      } else {
        final totalSkeletons = cols * 2;
        final rowsCount = (totalSkeletons / cols).ceil();
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          itemCount: rowsCount,
          itemBuilder: (context, rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(cols, (_) => const Expanded(
                    child: WeeklyMealCardSkeleton(),
                  )),
                ),
              ),
            );
          },
        );
      }
    }

    if (menuProvider.error != null && menuProvider.weeklyMenu.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.black.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<MenuProvider>().fetchWeeklyMenu(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final mealProvider = context.watch<MealProvider>();
    final canViewWeekly = menuProvider.isSubscribed ||
        SubscriptionStatusNormalizer.accountHasOnlyUpcoming(mealProvider.subscriptionStatusData);

    if (!canViewWeekly) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.lock_fill, size: 48, color: isDark ? Colors.white38 : Colors.black.withValues(alpha: 0.35)),
                  const SizedBox(height: 16),
                  Text(
                    'Meal Plan Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Buy a meal plan to view the weekly menu.',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.55)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (menuProvider.weeklyMenu.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.calendar, size: 48, color: isDark ? Colors.white38 : Colors.black.withValues(alpha: 0.35)),
                  const SizedBox(height: 16),
                  Text(
                    'No weekly menu available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final int cols = width > 1150 ? 3 : (width > 750 ? 2 : 1);

    if (cols == 1) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        itemCount: menuProvider.weeklyMenu.length,
        itemBuilder: (context, index) {
          final menu = menuProvider.weeklyMenu[index];
          return _buildWeeklyMealCard(context, menu, index, isDark, menuProvider.isLoading);
        },
      );
    }

    final menuItems = menuProvider.weeklyMenu;
    final List<List<dynamic>> rows = [];
    for (var i = 0; i < menuItems.length; i += cols) {
      final List<dynamic> row = [];
      for (var j = 0; j < cols; j++) {
        if (i + j < menuItems.length) {
          row.add(menuItems[i + j]);
        }
      }
      rows.add(row);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      children: rows.map((rowItems) {
        final rowIndex = rows.indexOf(rowItems);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...rowItems.map((menu) {
                  final index = rowIndex * cols + rowItems.indexOf(menu);
                  return Expanded(
                    child: _buildWeeklyMealCard(context, menu, index, isDark, menuProvider.isLoading),
                  );
                }),
                if (rowItems.length < cols)
                  ...List.generate(cols - rowItems.length, (_) => const Expanded(child: SizedBox.shrink())),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyMealCard(BuildContext context, dynamic menu, int index, bool isDark, bool isLoading) {
    final imageUrl = menu['image_url']?.toString();
    final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Meal';
    final menuDateRaw = menu['menu_date']?.toString() ?? '';
    final nutritionPoints = _nutritionPointsFrom(menu);

    String formattedDate = menuDateRaw;
    String dayLabel = 'Day ${index + 1}';
    if (menuDateRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(menuDateRaw);
      if (parsed != null) {
        dayLabel = DateFormat('EEE').format(parsed);
        formattedDate = DateFormat('dd MMM yyyy').format(parsed);
      }
    }

    final width = MediaQuery.sizeOf(context).width;
    final bool useVerticalLayout = width > 750;

    if (useVerticalLayout) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: imageUrl != null && imageUrl.isNotEmpty
                  ? () => ImagePreviewDialog.show(context, imageUrl, title: '$dayLabel — $items')
                  : null,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  color: isDark ? const Color(0xFF2A241E) : const Color(0xFFF4EFE4),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SkeletonBone(
                            height: 180,
                            width: double.infinity,
                            borderRadius: BorderRadius.zero,
                          ),
                          errorWidget: (_, __, ___) => const SkeletonBone(
                            height: 180,
                            width: double.infinity,
                            borderRadius: BorderRadius.zero,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dayLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    items,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  if (nutritionPoints.isNotEmpty)
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: nutritionPoints.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E2420) : const Color(0xFFF2ECE0),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark ? const Color(0xFF42342C) : const Color(0xFFE6DBC5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              nutritionPoints[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.03, end: 0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: imageUrl != null && imageUrl.isNotEmpty
                  ? () => ImagePreviewDialog.show(context, imageUrl, title: '$dayLabel — $items')
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: isDark ? const Color(0xFF2A241E) : const Color(0xFFF4EFE4),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SkeletonBone(
                            height: 112,
                            width: 112,
                            borderRadius: BorderRadius.zero,
                          ),
                          errorWidget: (_, __, ___) => const SkeletonBone(
                            height: 112,
                            width: 112,
                            borderRadius: BorderRadius.zero,
                          ),
                        )
                      : const SizedBox(width: 112, height: 112),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dayLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    items,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  if (nutritionPoints.isNotEmpty)
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: nutritionPoints.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E2420) : const Color(0xFFF2ECE0),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark ? const Color(0xFF42342C) : const Color(0xFFE6DBC5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              nutritionPoints[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.03, end: 0);
  }
}
