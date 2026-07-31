import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/services/connectivity_service.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/features/profile/ui/screens/contact_us_screen.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ConnectivityService? _connectivityService;
  bool _wasOnline = true;
  // HIGH-05: Prevents concurrent duplicate fetches when connectivity bounces.
  bool _reconnectFetchInFlight = false;

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.subscriptionManagement);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future.wait([
          context.read<PaymentProvider>().fetchActiveSubscriptions(),
          context.read<PaymentProvider>().fetchPaymentHistory(silent: true),
        ]).catchError((_) => []),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<ConnectivityService>();
    if (_connectivityService == service) return;
    _connectivityService?.removeListener(_handleConnectivityChange);
    _connectivityService = service;
    _wasOnline = _connectivityService?.isOnline ?? true;
    _connectivityService?.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.subscriptionManagement);
    _connectivityService?.removeListener(_handleConnectivityChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectivityChange() async {
    final online = _connectivityService?.isOnline ?? true;
    if (online && !_wasOnline && mounted && !_reconnectFetchInFlight) {
      _reconnectFetchInFlight = true;
      try {
        await Future.wait([
          context.read<PaymentProvider>().fetchActiveSubscriptions(),
          context.read<PaymentProvider>().fetchPaymentHistory(),
        ]);
      } finally {
        _reconnectFetchInFlight = false;
      }
    }
    _wasOnline = online;
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          tabs: const [
            Tab(text: 'Active Plans'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildActivePlans(paymentProvider, isDark),
            _buildHistory(paymentProvider, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlans(PaymentProvider provider, bool isDark) {
    // Show spinner only on first load with no cached data
    if (provider.isLoading && provider.activeSubscriptions.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // If error but we have cached data, show cached data with a small banner
    if (provider.error != null && provider.activeSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Could not load meal plans',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.fetchActiveSubscriptions(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.activeSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.creditcard, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No active meal plans found.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      );
    }

    final sessionToday = MealDate.parseYmdLocal(MealDate.sessionTodayYmd());
    final sortedSubs = [...provider.activeSubscriptions];
    sortedSubs.sort((a, b) {
      final aStart = MealDate.parseYmdLocal(a['start_date']?.toString());
      final bStart = MealDate.parseYmdLocal(b['start_date']?.toString());
      final aUpcoming = sessionToday != null && aStart != null && aStart.isAfter(sessionToday);
      final bUpcoming = sessionToday != null && bStart != null && bStart.isAfter(sessionToday);
      if (aUpcoming != bUpcoming) return aUpcoming ? -1 : 1;
      final aStartStr = a['start_date']?.toString() ?? '';
      final bStartStr = b['start_date']?.toString() ?? '';
      return aStartStr.compareTo(bStartStr);
    });

    return RefreshIndicator(
      onRefresh: () => provider.fetchActiveSubscriptions(force: true),
      child: ResponsiveContainer(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: sortedSubs.length,
      itemBuilder: (context, index) {
        final sub = sortedSubs[index];
        
        // Safe type conversion for all fields
        final planName = _safeString(sub['plan_name'], 'PLAN');
        final entityName = _safeString(sub['entity_name'], 'Profile');
        final entityType = _safeString(sub['entity_type'], '');
        final amountPaid = _safeString(sub['amount_paid'], '');
        final remainingMeals = sub['remaining_meals'];
        final includeSaturday = sub['include_saturday'] == null ? true : sub['include_saturday'] == true;
        final mealSizeName = _safeString(sub['meal_size_name'], '');
        final mealTimingRaw = _safeString(sub['meal_timing'], '');
        final mealTiming = mealTimingRaw.isEmpty ? '' : TimeUtils.formatToDisplay(mealTimingRaw);
        final startDateStr = _safeString(sub['start_date'], '');
        final startDate = startDateStr.isNotEmpty ? MealDate.parseYmdLocal(startDateStr) : null;

        final isUpcoming = sessionToday != null && startDate != null && startDate.isAfter(sessionToday);

        return AppleCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      planName.toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: isUpcoming ? Colors.orange : const Color(0xFF22C55E),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entityName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              if (entityType.isNotEmpty && entityType.toLowerCase().trim() != 'cart')
                Text(
                  entityType.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              // Meta details — compact column of label/value pairs
              if (startDate != null)
                _buildMetaRow('Start Date', DateFormat('dd MMM yyyy').format(startDate), isDark),
              if (amountPaid.isNotEmpty)
                _buildMetaRow('Amount Paid', '₹$amountPaid', isDark),
              _buildMetaRow('Variant', includeSaturday ? 'Including Sat' : 'Excluding Sat', isDark),
              if (mealSizeName.isNotEmpty)
                _buildMetaRow('Meal Size', mealSizeName, isDark),
              if (mealTiming.isNotEmpty)
                _buildMetaRow('Meal Delivery Time', mealTiming, isDark),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      if (remainingMeals != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${remainingMeals.toString()} meals left',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final sessionToday = MealDate.parseYmdLocal(MealDate.sessionTodayYmd());
                          final isUpcoming = startDate != null &&
                              sessionToday != null &&
                              startDate.isAfter(sessionToday);

                          return Text(
                            (isUpcoming ? 'UPCOMING' : 'ACTIVE').toUpperCase(),
                            style: TextStyle(
                              color: isUpcoming ? const Color(0xFFEAB308) : const Color(0xFF22C55E),
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const ContactUsScreen()),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble_2_fill,
                      size: 14,
                      color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Want to cancel? Contact Support',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        decoration: TextDecoration.underline,
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
    );
  }


  Widget _buildHistory(PaymentProvider provider, bool isDark) {
    if (provider.isLoading && provider.paymentHistory.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    
    if (provider.error != null && provider.paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Could not load payment history',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.fetchPaymentHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.paymentHistory.isEmpty) {
      return Center(
        child: Text(
          'No payment history found.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchPaymentHistory(force: true),
      child: ResponsiveContainer(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: provider.paymentHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == provider.paymentHistory.length) {
          // End-of-list footer
          if (provider.hasMoreHistory) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: provider.isLoadingMore
                    ? const CupertinoActivityIndicator()
                    : OutlinedButton.icon(
                        onPressed: provider.loadMorePaymentHistory,
                        icon: const Icon(CupertinoIcons.arrow_down_circle, size: 16),
                        label: const Text('Load More'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                      ),
              ),
            );
          }
          // All items loaded — show a subtle end-of-list marker
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Center(
              child: Text(
                '— End of history —',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        final payment = provider.paymentHistory[index];
        
        // Safe type conversion — prevents "type X is not a subtype of type String"
        final orderType = (payment['order_type'] ?? payment['orderType'] ?? '')
            .toString()
            .toLowerCase();
        
        String planName = '';
        if (orderType == 'one_day_lunch') {
          planName = 'One Day Lunch';
        } else if (orderType == 'special_dish') {
          planName = _safeString(payment['plan_name'] ?? payment['entity_name'], 'Buuttii Specials');
          if (planName.isEmpty || planName == 'Subscription' || planName == 'Meal Plan' || planName == 'null') {
            planName = 'Buuttii Specials';
          }
        } else if (orderType == 'bulk') {
          planName = 'Bulk Order';
        } else if (orderType == 'meal_size_upgrade') {
          final changeLabel = _safeString(payment['size_change_label'], '');
          planName = changeLabel.isNotEmpty ? 'Meal Pack Upgrade ($changeLabel)' : 'Meal Pack Upgrade';
        } else if (orderType == 'meal_size_downgrade') {
          final changeLabel = _safeString(payment['size_change_label'], '');
          planName = changeLabel.isNotEmpty ? 'Meal Pack Downgrade ($changeLabel)' : 'Meal Pack Downgrade (wallet)';
        } else if (orderType == 'referral_reward') {
          planName = _safeString(payment['plan_name'], 'Referral Reward');
        } else if (orderType == 'referral_applied') {
          planName = _safeString(payment['plan_name'], 'Referral Applied');
        } else {
          planName = _safeString(payment['plan_name'] ?? payment['entity_name'], 'Meal Plan');
        }
        final entityName = _safeString(payment['entity_name'], '');
        final entityType = _safeString(payment['entity_type'] ?? payment['entityType'], '');
        final amount = _safeNumString(payment['amount']);
        final walletApplied = _parseMoney(payment['wallet_amount_applied']);
        final gatewayAmount = _parseMoney(payment['gateway_amount']);
        final pStatus = _safeString(
          payment['payment_status'] ?? payment['order_status'] ?? payment['status'],
          'PENDING',
        ).toUpperCase();
        final includeSaturday = payment['include_saturday'] == null ? true : payment['include_saturday'] == true;
        final mealSizeName = _safeString(payment['meal_size_name'], '');
        final mealTimingRaw = _safeString(payment['meal_timing'], '');
        final isSuccess = pStatus == 'COMPLETED' || pStatus == 'SUCCESS';
        final phone = _safeString(payment['phone_number'], '');
        final altPhone = _safeString(payment['alt_phone_number'], '');
        final addressLine = _safeString(payment['address_line'], '');
        final pincode = _safeString(payment['pincode'], '');
        final cityName = _safeString(payment['city_name'], '');
        final stateName = _safeString(payment['state_name'], '');
        final deliveryCustomerName = _safeString(payment['customer_name'], '');
        final deliveryTime = _safeString(payment['delivery_time'], '');
        final deliveryDate = _safeString(payment['delivery_date'], '');
        final quantity = payment['quantity'] ?? 1;

        String? formattedDeliveryDate;
        if (deliveryDate.isNotEmpty) {
          try {
            final parsedDate = DateTime.parse(deliveryDate);
            formattedDeliveryDate = DateFormat('dd MMM yyyy').format(parsedDate);
          } catch (_) {
            formattedDeliveryDate = deliveryDate;
          }
        }

        String fallbackEntityName = 'System / Referral';
        if (orderType == 'bulk') {
          fallbackEntityName = 'Bulk Order';
        } else if (orderType == 'one_day_lunch') {
          fallbackEntityName = 'One Day Lunch';
        } else if (orderType == 'special_dish') {
          fallbackEntityName = 'Buuttii Specials';
        } else if (orderType == 'meal_size_upgrade' || orderType == 'meal_size_downgrade') {
          fallbackEntityName = 'Resizer Pack';
        }

        final showSaturday = orderType != 'special_dish' &&
            orderType != 'one_day_lunch' &&
            orderType != 'bulk' &&
            orderType != 'meal_size_upgrade' &&
            orderType != 'meal_size_downgrade';

        final metaList = [
          if (showSaturday) includeSaturday ? 'Including Sat' : 'Excluding Sat',
          if (mealSizeName.isNotEmpty) mealSizeName,
          if (mealTimingRaw.isNotEmpty) TimeUtils.formatToDisplay(mealTimingRaw),
        ];
        final metaText = metaList.join(' • ');

        final dateStr = _safeString(payment['created_at'] ?? payment['payment_date'], '');
        DateTime date = DateTime.now();
        if (dateStr.isNotEmpty) {
          date = DateTime.tryParse(dateStr) ?? DateTime.now();
        }

        return AppleCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Plan Name and Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      planName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isSuccess ? const Color(0xFF22C55E) : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pStatus,
                      style: TextStyle(
                        color: isSuccess ? const Color(0xFF22C55E) : Colors.orange,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Second row: amount
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (orderType != 'referral_reward' && orderType != 'referral_applied')
                    Text(
                      '₹$amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        orderType == 'referral_reward' ? 'REWARD' : 'DISCOUNT',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
              
              const Divider(height: 16),
              
              // Profile Section (For whom was this bought?)
              Row(
                children: [
                  Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 16,
                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entityName.isNotEmpty ? entityName : fallbackEntityName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entityType.isNotEmpty &&
                      entityType.toLowerCase().trim() != 'cart' &&
                      entityType.toLowerCase().trim() != 'one_day_lunch' &&
                      entityType.toLowerCase().trim() != 'special_dish') ...[
                    const SizedBox(width: 8),
                    _buildRoleBadge(entityType, isDark),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(date),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Third block: Meta details if applicable (Saturday option, Size, Time etc.)
              if (orderType != 'referral_reward' && orderType != 'referral_applied' && metaText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle,
                      size: 14,
                      color: isDark ? Colors.white38 : AppTheme.textSecondaryLight.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        metaText,
                        style: TextStyle(
                          color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Payment breakdown / split if wallet was applied
              if (walletApplied > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.creditcard,
                        size: 12,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          gatewayAmount > 0
                              ? 'Wallet ₹${walletApplied.toStringAsFixed(0)} • Razorpay ₹${gatewayAmount.toStringAsFixed(0)}'
                              : 'Paid fully from wallet',
                          style: TextStyle(
                            color: isDark ? Colors.green.shade400 : Colors.green.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (addressLine.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 14,
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (formattedDeliveryDate != null)
                        _buildMetaRow('Delivery Date', formattedDeliveryDate, isDark),
                      if (orderType == 'one_day_lunch' || orderType == 'special_dish' || orderType == 'bulk')
                        _buildMetaRow('Quantity', '$quantity', isDark),
                      if (deliveryCustomerName.isNotEmpty)
                        _buildMetaRow('Recipient', deliveryCustomerName, isDark),
                      if (phone.isNotEmpty)
                        _buildMetaRow('Phone', altPhone.isNotEmpty ? '$phone / $altPhone' : phone, isDark),
                      if (deliveryTime.isNotEmpty)
                        _buildMetaRow('Timing', TimeUtils.formatToDisplay(deliveryTime), isDark),
                      _buildMetaRow('Address', '$addressLine, $cityName, $stateName - $pincode', isDark),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      ),
      ),
    );
  }

  Widget _buildRoleBadge(String entityType, bool isDark) {
    final cleanType = entityType.toLowerCase().trim();
    String text = 'PROFILE';
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF475569);

    if (cleanType == 'child') {
      text = 'STUDENT';
      bgColor = isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
      textColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
    } else if (cleanType == 'teacher') {
      text = 'TEACHER';
      bgColor = isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF);
      textColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8);
    } else if (cleanType == 'professional') {
      text = 'PROFESSIONAL';
      bgColor = isDark ? const Color(0xFF14532D) : const Color(0xFFF0FDF4);
      textColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    } else if (cleanType == 'bulk') {
      text = 'BULK ORDER';
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    } else if (cleanType == 'cart') {
      text = 'CART ORDER';
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    } else if (cleanType == 'referral') {
      text = 'REFERRAL';
      bgColor = isDark ? const Color(0xFF14532D) : const Color(0xFFECFDF5);
      textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
    } else {
      text = cleanType.toUpperCase();
      if (isDark) {
        bgColor = const Color(0xFF1E293B);
        textColor = const Color(0xFF94A3B8);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Compact label/value row used inside the active-plan card.
  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Safely convert any dynamic value to String, avoiding type cast errors.
  String _safeString(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString();
  }

  /// Safely convert numeric amount to display string.
  String _safeNumString(dynamic value) {
    if (value == null) return '0';
    if (value is num) return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return value.toString();
  }

  double _parseMoney(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }
}
