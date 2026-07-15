import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';
import 'package:meal_app/core/navigation/app_routes.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';

/// Keys are `${entityType}_${entityId}` where type is child, teacher, or professional.
({String type, String id})? parseMealSkipEntityKey(String key) {
  const prefixes = <String>['child_', 'teacher_', 'professional_'];
  for (final p in prefixes) {
    if (key.startsWith(p)) {
      final id = key.substring(p.length);
      if (id.isEmpty) return null;
      return (type: p.substring(0, p.length - 1), id: id);
    }
  }
  return null;
}

class MealSkipScreen extends StatefulWidget {
  const MealSkipScreen({super.key});

  @override
  State<MealSkipScreen> createState() => _MealSkipScreenState();
}

class _MealSkipScreenState extends State<MealSkipScreen> {
  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.mealSkip);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      NetworkStatusService.instance.addBecameOnlineListener(_fetchAll);
    });
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeBecameOnlineListener(_fetchAll);
    AppRouteTracker.instance.clearIfCurrent(AppScreen.mealSkip);
    super.dispose();
  }

  // HIGH-04: Guard against concurrent fetch runs triggered by rapid reconnects.
  bool _fetchInFlight = false;

  void _fetchAll() {
    if (!mounted || _fetchInFlight) return;
    _fetchInFlight = true;
    final mealProvider = context.read<MealProvider>();
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    Future(() async {
      try {
        await Future.wait([
          mealProvider.fetchSkips(),
          mealProvider.fetchMealStatus(),
          mealProvider.fetchSkipPolicy(),
          childrenProvider.fetchChildren(),
          profileProvider.fetchProfiles(),
        ]);
      } finally {
        _fetchInFlight = false;
      }
    });
  }


  int _countSkippableMealDays(DateTime start, DateTime end, bool includeSaturday) {
    int count = 0;
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      final dow = cursor.weekday;
      final isSunday = dow == 7;
      final isSaturday = dow == 6;
      final isMealDay = !isSunday && (includeSaturday || !isSaturday);
      if (isMealDay) count++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = context.watch<MealProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showSpinner = mealProvider.isLoading &&
        mealProvider.mealStatus.isEmpty &&
        mealProvider.skips.isEmpty;

    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final navBarColor = isDark ? AppTheme.surfaceDark : pageBg;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(
          background: pageBg,
          isDark: isDark,
          navigationBarColor: navBarColor,
        ),
        child: Scaffold(
          backgroundColor: pageBg,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showSkipDialog(context),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(CupertinoIcons.calendar_badge_plus, color: Colors.white),
            label: const Text('New Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Text(
              'Meal Skips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF5A4D42),
              ),
            ),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            systemOverlayStyle: AppTheme.overlayFor(
              background: pageBg,
              isDark: isDark,
              navigationBarColor: navBarColor,
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [

                // Body
                Expanded(
                  child: showSpinner
                      ? const Center(child: CupertinoActivityIndicator())
                      : RefreshIndicator(
                          onRefresh: () async => _fetchAll(),
                          color: AppTheme.primaryColor,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // Meal Balances
                                if (mealProvider.mealStatus.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Meal Balances',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${mealProvider.mealStatus.length}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 125,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      itemCount: mealProvider.mealStatus.length,
                                      itemBuilder: (context, index) {
                                        final ms = mealProvider.mealStatus[index];
                                        final remaining = int.tryParse('${ms['remaining_meals'] ?? 0}') ?? 0;
                                        final total = int.tryParse('${ms['total_meals'] ?? 0}') ?? 1;
                                        final ratio = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
                                        final name = ms['entity_name']?.toString() ?? 'Profile';
                                        final type = ms['entity_type']?.toString() ?? '';
                                        final plan = ms['plan_name']?.toString() ?? 'No Plan';
                                        final startDateStr = ms['start_date']?.toString();
                                        bool isUpcoming = false;
                                        if (startDateStr != null) {
                                          try {
                                            final parsedStart = DateTime.parse(startDateStr);
                                            final now = DateTime.now();
                                            final todayDate = DateTime(now.year, now.month, now.day);
                                            if (parsedStart.isAfter(todayDate)) {
                                              isUpcoming = true;
                                            }
                                          } catch (_) {}
                                        }
                                        final planDisplay = isUpcoming && startDateStr != null
                                            ? 'Upcoming • Starts $startDateStr'
                                            : plan;

                                        Color typeColor;
                                        IconData typeIcon;
                                        if (type.toLowerCase() == 'child') {
                                          typeColor = const Color(0xFF3B82F6);
                                          typeIcon = CupertinoIcons.person_solid;
                                        } else if (type.toLowerCase() == 'teacher') {
                                          typeColor = const Color(0xFFD97706);
                                          typeIcon = CupertinoIcons.person_crop_square_fill;
                                        } else {
                                          typeColor = const Color(0xFF8B5CF6);
                                          typeIcon = CupertinoIcons.briefcase_fill;
                                        }

                                        return Container(
                                          width: 220,
                                          margin: const EdgeInsets.only(right: 14),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 52,
                                                    height: 52,
                                                    child: CircularProgressIndicator(
                                                      value: ratio,
                                                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                                      color: typeColor,
                                                      strokeWidth: 4.5,
                                                    ),
                                                  ),
                                                  Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        '$remaining',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 15,
                                                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                        ),
                                                      ),
                                                      Text(
                                                        '/$total',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(typeIcon, color: typeColor, size: 10),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            type.toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w800,
                                                              color: typeColor,
                                                              letterSpacing: 0.3,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13,
                                                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      planDisplay,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isUpcoming
                                                            ? const Color(0xFFD97706)
                                                            : (isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
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

                                // Skip History
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Skip History & Schedule',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (mealProvider.skips.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${mealProvider.skips.length}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                if (mealProvider.skips.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.calendar,
                                            size: 64,
                                            color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No meal skips scheduled',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 24),
                                            child: Text(
                                              'Tap "New Skip" below to select dates and schedule skips according to policy.',
                                              textAlign: TextAlign.center,
                                              softWrap: true,
                                              maxLines: 3,
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Builder(
                                    builder: (context) {
                                      final sortedSkips = List.from(mealProvider.skips)
                                        ..sort((a, b) {
                                          final statusA = a['status']?.toString().toLowerCase() ?? '';
                                          final statusB = b['status']?.toString().toLowerCase() ?? '';

                                          int getPriority(String status) {
                                            if (status == 'approved' || status == 'active') return 0;
                                            if (status == 'requested') return 1;
                                            if (status == 'cancelled') return 3;
                                            return 2;
                                          }

                                          return getPriority(statusA).compareTo(getPriority(statusB));
                                        });

                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                        itemCount: sortedSkips.length,
                                        itemBuilder: (context, index) {
                                          final skip = sortedSkips[index];
                                          final isCancelled = skip['status']?.toString().toLowerCase() == 'cancelled';
                                          final card = _buildSkipCard(context, skip, isDark, mealProvider);

                                          Widget item = card;
                                          if (isCancelled) {
                                            item = Dismissible(
                                              key: ValueKey('skip_${skip['id']}'),
                                              direction: DismissDirection.endToStart,
                                              background: Container(
                                                margin: const EdgeInsets.only(bottom: 14),
                                                padding: const EdgeInsets.only(right: 22),
                                                alignment: Alignment.centerRight,
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade400,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Icon(CupertinoIcons.delete_solid, color: Colors.white),
                                              ),
                                              confirmDismiss: (_) async {
                                                final id = skip['id'];
                                                if (id == null) return false;
                                                final skipId = id is int ? id : int.tryParse(id.toString()) ?? 0;
                                                return _confirmDeleteSkip(context, skipId, mealProvider);
                                              },
                                              child: card,
                                            );
                                          }

                                          return item
                                              .animate()
                                              .fadeIn(delay: (index * 80).ms)
                                              .slideX(begin: 0.05, end: 0);
                                        },
                                      );
                                    },
                                  ),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BuuttiiFooterNav(
            currentIndex: 2,
            onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            onWeekMenuTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.weeklyMenu),
            onMealSkipTap: () {},
            onSettingsTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.settings),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipCard(BuildContext context, Map<String, dynamic> skip, bool isDark, MealProvider mealProvider) {
    final entityName = skip['entity_name']?.toString() ?? 'Entity';
    final entityType = skip['entity_type']?.toString() ?? '';
    final status = skip['status']?.toString() ?? 'approved';
    final totalDays = skip['total_skip_days'] ?? 0;

    final startStr = skip['skip_start_date']?.toString() ?? '';
    final endStr = skip['skip_end_date']?.toString() ?? '';
    final DateTime? start = DateTime.tryParse(startStr);
    final DateTime? end = DateTime.tryParse(endStr);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = start != null && start.isAfter(today);
    final isCompleted = end != null && today.isAfter(end);
    final isActive = status == 'approved' || status == 'active';

    debugPrint('MEAL_SKIP_DEBUG: id=${skip['id']} start=$startStr->$start end=$endStr->$end today=$today isCompleted=$isCompleted status=$status');

    Color statusColor;
    IconData statusIcon;
    String statusLabel = status;
    if (status.toLowerCase() == 'cancelled') {
      statusColor = Colors.grey;
      statusIcon = CupertinoIcons.xmark_circle_fill;
      statusLabel = 'Cancelled';
    } else if (status.toLowerCase() == 'approved' || status.toLowerCase() == 'active') {
      if (isFuture) {
        statusColor = const Color(0xFFF59E0B);
        statusIcon = CupertinoIcons.clock_fill;
        statusLabel = 'Upcoming';
      } else if (isCompleted) {
        statusColor = Colors.grey;
        statusIcon = CupertinoIcons.checkmark_circle;
        statusLabel = 'Completed';
      } else {
        statusColor = const Color(0xFF10B981);
        statusIcon = CupertinoIcons.checkmark_circle_fill;
        statusLabel = 'Active';
      }
    } else {
      statusColor = const Color(0xFFEF4444);
      statusIcon = CupertinoIcons.info_circle_fill;
      statusLabel = status;
    }

    Color typeColor;
    IconData typeIcon;
    if (entityType.toLowerCase() == 'child') {
      typeColor = const Color(0xFF3B82F6);
      typeIcon = CupertinoIcons.person_solid;
    } else if (entityType.toLowerCase() == 'teacher') {
      typeColor = const Color(0xFFD97706);
      typeIcon = CupertinoIcons.person_crop_square_fill;
    } else {
      typeColor = const Color(0xFF8B5CF6);
      typeIcon = CupertinoIcons.briefcase_fill;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(typeIcon, color: typeColor, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entityName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  entityType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: typeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : const Color(0xFFFAF8F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Starts',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    start != null ? DateFormat('dd MMM yyyy').format(start) : '--',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                              ),
                              child: Text(
                                '$totalDays days',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Ends',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    end != null ? DateFormat('dd MMM yyyy').format(end) : '--',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isFuture && isActive) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _confirmCancelSkip(skip, mealProvider),
                              icon: const Icon(CupertinoIcons.xmark_circle, size: 14),
                              label: const Text('Cancel Skip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade200, width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancelSkip(Map<String, dynamic> skip, MealProvider mealProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Cancel Skip'),
        content: const Text('Are you sure you want to cancel this meal skip?'),
        actions: [
          CupertinoDialogAction(child: const Text('No'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final id = skip['id'];
              if (id != null) {
                final success = await mealProvider.cancelSkip(id is int ? id : int.tryParse(id.toString()) ?? 0);
                if (!mounted) return;
                if (success) {
                  ErrorHandler.showSuccess(context, 'Skip cancelled successfully');
                } else {
                  ErrorHandler.showError(context, mealProvider.error);
                }
              }
            },
            child: const Text('Cancel Skip'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteSkip(BuildContext context, int skipId, MealProvider mealProvider) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Skip'),
        content: const Text('Delete this skip from your history?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    final success = await mealProvider.deleteSkip(skipId);
    if (context.mounted) {
      if (success) {
        ErrorHandler.showSuccess(context, 'Skip deleted successfully');
      } else {
        ErrorHandler.showError(context, mealProvider.error);
      }
    }
    return success;
  }

  void _showSkipDialog(BuildContext context) {
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final mealProvider = context.read<MealProvider>();
    final messenger = ScaffoldMessenger.of(context);

    int resolveEntityRemainingMeals(String entityKey) {
      final parsed = parseMealSkipEntityKey(entityKey);
      if (parsed == null) return 0;
      final matches = mealProvider.mealStatus.where(
        (s) => s['entity_type'] == parsed.type && s['entity_id']?.toString() == parsed.id,
      );
      if (matches.isEmpty) return 0;
      int total = 0;
      for (final match in matches) {
        final remaining = match['remaining_meals'] ?? match['remainingMeals'];
        total += int.tryParse(remaining?.toString() ?? '0') ?? 0;
      }
      return total;
    }

    // Build entity list
    final List<Map<String, String>> entities = [];
    final statusData = mealProvider.subscriptionStatusData;
    for (final child in childrenProvider.children) {
      final state = SubscriptionStatusNormalizer.entityPlanState(statusData, 'child', child.id ?? '');
      if (state == 'active' || state == 'upcoming') {
        entities.add({'type': 'child', 'id': child.id!, 'name': child.name});
      }
    }
    for (final teacher in profileProvider.teacherProfiles) {
      final state = SubscriptionStatusNormalizer.entityPlanState(statusData, 'teacher', teacher.id ?? '');
      if (state == 'active' || state == 'upcoming') {
        entities.add({
          'type': 'teacher',
          'id': teacher.id!,
          'name': teacher.name,
        });
      }
    }
    for (final professional in profileProvider.professionalProfiles) {
      final state = SubscriptionStatusNormalizer.entityPlanState(statusData, 'professional', professional.id ?? '');
      if (state == 'active' || state == 'upcoming') {
        entities.add({
          'type': 'professional',
          'id': professional.id!,
          'name': professional.name,
        });
      }
    }

    if (entities.isEmpty) {
      ErrorHandler.showError(context, 'No active subscriptions found. Create or renew a subscription first.');
      return;
    }

    String? selectedEntity;
    DateTimeRange? selectedRange;
    String? sheetError;
    bool isSubmitting = false;
    final minSkipDays = int.tryParse(mealProvider.skipPolicy['min_skip_days']?.toString() ?? '') ?? 3;
    final minNoticeDays = int.tryParse(mealProvider.skipPolicy['min_notice_days']?.toString() ?? '') ?? 1;
    int skipType = minSkipDays >= 2 ? 1 : 0; // 0 for single day, 1 for multiple days

    bool resolveEntityIncludesSaturday(String entityKey) {
      final parsed = parseMealSkipEntityKey(entityKey);
      if (parsed == null) return true;
      final match = mealProvider.mealStatus.firstWhere(
        (s) => s['entity_type'] == parsed.type && s['entity_id']?.toString() == parsed.id,
        orElse: () => <String, dynamic>{},
      );
      if (match.isEmpty) return true;
      return match['include_saturday'] != false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(sheetCtx).viewInsets.bottom + MediaQuery.paddingOf(sheetCtx).bottom + 36,
              ),
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Text(
                      'Schedule a Meal Skip',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select who to skip for and choose the date range.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Profile selector
                    Text(
                      'Select Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entities.map((e) {
                        final key = '${e['type']}_${e['id']}';
                        final isSelected = selectedEntity == key;
                        return ChoiceChip(
                          label: Text(e['name'] ?? ''),
                          selected: isSelected,
                          onSelected: (_) => setSheetState(() {
                            selectedEntity = key;
                            selectedRange = null;
                            sheetError = null;
                          }),
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textPrimaryLight),
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Skip Type Toggle
                    if (minSkipDays == 1) ...[
                      Text(
                        'Skip Duration',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: skipType,
                          children: {
                            0: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Single Day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: skipType == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: skipType == 0 
                                      ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                      : (isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                ),
                              ),
                            ),
                            1: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Multiple Days',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: skipType == 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: skipType == 1 
                                      ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                      : (isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                ),
                              ),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              setSheetState(() {
                                skipType = val;
                                selectedRange = null;
                              });
                            }
                          },
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                          thumbColor: isDark ? const Color(0xFF333333) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Date range picker
                    Text(
                      skipType == 0 ? 'Skip Date' : 'Skip Dates',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: selectedEntity == null
                          ? null
                          : () async {
                              final remainingMeals = resolveEntityRemainingMeals(selectedEntity!);
                              if (remainingMeals <= 0) {
                                setSheetState(() => sheetError =
                                    'No remaining meals left for this profile. Please purchase or renew a plan.');
                                return;
                              }

                              final tomorrow = DateTime.now().add(Duration(days: minNoticeDays));
                              final includeSat = resolveEntityIncludesSaturday(selectedEntity!);

                              // lastDate = start + enough days to cover `remainingMeals` meal days
                              // We'll allow up to 90 calendar days as a generous upper bound
                              final lastDate = tomorrow.add(const Duration(days: 90));

                              DateTimeRange? range;

                              if (skipType == 0) {
                                final date = await showDatePicker(
                                  context: sheetCtx,
                                  initialDate: tomorrow,
                                  firstDate: tomorrow,
                                  lastDate: lastDate,
                                  helpText: 'Select skip date',
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: Theme.of(context).colorScheme.copyWith(
                                              primary: AppTheme.primaryColor,
                                            ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  range = DateTimeRange(start: date, end: date);
                                }
                              } else {
                                range = await showDateRangePicker(
                                  context: sheetCtx,
                                  firstDate: tomorrow,
                                  lastDate: lastDate,
                                  helpText: 'Select skip range (min $minSkipDays days)',
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: Theme.of(context).colorScheme.copyWith(
                                              primary: AppTheme.primaryColor,
                                            ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                              }

                              if (range == null) return;

                              final mealDays = _countSkippableMealDays(range.start, range.end, includeSat);
                              if (skipType == 1 && mealDays < minSkipDays) {
                                setSheetState(() => sheetError =
                                    'Minimum $minSkipDays meal days required for multiple days skip. Selected range has only $mealDays meal day(s).');
                                return;
                              }

                              setSheetState(() {
                                selectedRange = range;
                                sheetError = null;
                              });
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: selectedEntity == null
                              ? (isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey.shade100)
                              : (isDark ? AppTheme.surfaceDark : const Color(0xFFFDF7F4)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedEntity == null
                                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200)
                                : (selectedRange != null
                                    ? AppTheme.primaryColor
                                    : (isDark ? Colors.white10 : Colors.grey.shade300)),
                            width: selectedRange != null ? 2.0 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedEntity == null
                                    ? Colors.transparent
                                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.calendar,
                                color: selectedEntity == null
                                    ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                    : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Date Range',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedRange != null
                                        ? (skipType == 0
                                            ? DateFormat('dd MMM yyyy').format(selectedRange!.start)
                                            : '${DateFormat('dd MMM').format(selectedRange!.start)} – ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}')
                                        : (selectedEntity == null ? 'Select a profile first' : 'Tap to choose dates'),
                                    style: TextStyle(
                                      color: selectedRange != null
                                          ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                          : (selectedEntity == null
                                              ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                              : AppTheme.primaryColor),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedEntity != null)
                              Icon(
                                CupertinoIcons.chevron_right,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Summary info
                    if (selectedRange != null && selectedEntity != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (builderCtx) {
                          final includeSat = resolveEntityIncludesSaturday(selectedEntity!);
                          final mealDays = _countSkippableMealDays(selectedRange!.start, selectedRange!.end, includeSat);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total meals skipped: $mealDays day(s)',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Error
                    if (sheetError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sheetError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (selectedEntity != null && selectedRange != null && !isSubmitting)
                            ? () async {
                                final parsed = parseMealSkipEntityKey(selectedEntity!);
                                if (parsed == null) {
                                  setSheetState(() => sheetError = 'Invalid profile selection.');
                                  return;
                                }
                                final fmt = DateFormat('yyyy-MM-dd');

                                setSheetState(() {
                                  isSubmitting = true;
                                  sheetError = null;
                                });

                                final success = await mealProvider.skipMeal(
                                  entityType: parsed.type,
                                  entityId: parsed.id,
                                  startDate: fmt.format(selectedRange!.start),
                                  endDate: fmt.format(selectedRange!.end),
                                );

                                if (!sheetCtx.mounted) return;
                                if (success) {
                                  Navigator.pop(sheetCtx);
                                  messenger.showSnackBar(const SnackBar(
                                    content: Text('Meal skip scheduled successfully!'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                } else {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    sheetError = mealProvider.error ?? 'Failed to schedule skip';
                                  });
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.calendar_badge_plus, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm Skip Period',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.2),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
