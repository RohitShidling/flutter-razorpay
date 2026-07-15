import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/providers/session_provider.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/services/offline_cache_bootstrap.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String txnId;
  final String orderId;

  /// Hint from caller — `'cart'` for cart checkout, `'single'` for buy-now.
  /// Used as fallback when backend has not yet returned `orderType` during
  /// early polling so we can still apply the correct cart-clear rule.
  final String? orderType;

  const PaymentStatusScreen({
    super.key,
    required this.txnId,
    required this.orderId,
    this.orderType,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  Map<String, dynamic>? _statusData;
  bool _isPolling = true;
  int _retryCount = 0;
  final int _maxRetries = 10;
  bool _postSuccessHandled = false;
  bool _pendingForceSyncAttempted = false;
  bool _abandonAttempted = false;
  String? _lastPollingError;
  // CRITICAL-02: Prevents concurrent polling loops when 'Check Again' is tapped
  // while a loop is already running.
  bool _pollingInFlight = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    // MEDIUM-06: Stop the polling loop when the screen is popped so we don't
    // continue firing network requests after the widget is gone.
    _isPolling = false;
    super.dispose();
  }

  Future<void> _startPolling() async {
    // CRITICAL-02: Guard against concurrent polling loops.
    if (_pollingInFlight) return;
    _pollingInFlight = true;
    final paymentProvider = context.read<PaymentProvider>();
    final sessionProvider = context.read<SessionProvider>();
    try {
    while (_isPolling && _retryCount < _maxRetries && mounted) {
      try {
        final data = await paymentProvider.checkStatus(widget.txnId);

        if (mounted) {
          setState(() {
            _statusData = data;
            _lastPollingError = data == null ? paymentProvider.error : null;
            if (data != null) {
              final status = _resolveStatus(data);
              if (status == 'SUCCESS' || status == 'FAILED') {
                _isPolling = false;
              }
            }
          });
        }
      } catch (e) {
        // Continue polling on error
        if (mounted) {
          setState(() {
            _lastPollingError = ErrorHandler.getErrorMessage(e);
          });
        }
      }

      if (_isPolling && mounted) {
        await Future.delayed(const Duration(seconds: 3));
        _retryCount++;
      }
    }

    if (mounted && _isPolling) {
      setState(() => _isPolling = false);
    }

    if (mounted && _currentStatus == 'PENDING' && !_pendingForceSyncAttempted && widget.txnId.isNotEmpty) {
      _pendingForceSyncAttempted = true;

      try {
        await paymentProvider.forceSyncPayment(widget.txnId);
        final synced = await paymentProvider.checkStatus(widget.txnId);
        if (mounted && synced != null) {
          setState(() => _statusData = synced);
        }
      } catch (e) {
        // Check for session expiry first.
        if (sessionProvider.isExpired) {
          _handle401Redirect(sessionProvider.reason);
          return;
        }
        // For other errors, show a user-facing message.
        if (mounted) {
          setState(() => _lastPollingError = 'Could not sync payment status. Please check your internet connection and try again.');
        }
      }
    }

    // After polling stops, if we resolved to SUCCESS, run the success-side effects.
    if (mounted && _currentStatus == 'SUCCESS' && !_postSuccessHandled) {
      _postSuccessHandled = true;
      // Schedule after current frame so providers have settled
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPaymentConfirmedSuccess());
    } else if (mounted && _currentStatus == 'FAILED') {
      await _abandonPendingIfNeeded();
    }
    } finally {
      _pollingInFlight = false;
    }
  }

  Future<void> _abandonPendingIfNeeded() async {
    if (_abandonAttempted || !mounted) return;
    if (_currentStatus == 'SUCCESS' || _currentStatus == 'PENDING') return;
    _abandonAttempted = true;
    try {
      await context.read<PaymentProvider>().abandonPendingPayment(
        orderId: widget.orderId,
        merchantTransactionId: widget.txnId,
      );
    } catch (_) {}
  }

  void _handle401Redirect(String? reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason ?? 'Session expired. Please log in again to view your active plan.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
    try {
      OfflineCacheBootstrap.clearMemory(context);
      context.read<AuthProvider>().logout();
    } catch (_) {}
    context.read<SessionProvider>().acknowledge();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Runs ONLY when the backend confirms the payment as SUCCESS.
  /// • For cart orders: clears the server-side cart (best-effort, then local).
  /// • Refreshes subscription/meal/payment providers so Home shows "Active Plan".
  Future<void> _onPaymentConfirmedSuccess() async {
    if (!mounted) return;

    final cart = context.read<CartProvider>();
    final meal = context.read<MealProvider>();
    final payment = context.read<PaymentProvider>();
    final subscriptions = context.read<SubscriptionProvider>();
    final session = context.read<SessionProvider>();
    final bulk = context.read<BulkOrderProvider>();
    final quick = context.read<QuickServiceProvider>();
    final profile = context.read<ProfileProvider>();
    final children = context.read<ChildrenProvider>();
    final menu = context.read<MenuProvider>();

    final orderType = (_statusData?['orderType']?.toString() ?? widget.orderType ?? '').toLowerCase();
    final isCartOrder = orderType == 'cart';
    final isBulkOrder = orderType == 'bulk';
    final isOneDayLunch = orderType == 'one_day_lunch';
    final isSpecialDish = orderType == 'special_dish';

    final orderStatus = (_statusData?['orderStatus']?.toString() ?? '').toLowerCase();
    if ((orderStatus == 'pending' || _statusData?['localStatus'] == 'pending') && widget.txnId.isNotEmpty) {
      try {
        await payment.forceSyncPayment(widget.txnId);
        final synced = await payment.checkStatus(widget.txnId);
        if (synced != null && mounted) {
          setState(() => _statusData = synced);
        }
      } catch (e) {
        // Check for session expiry.
        if (session.isExpired) {
          _handle401Redirect(session.reason);
          return;
        }
        // Non-fatal: best-effort sync in the success handler.
      }
    }

    if (session.isExpired) {
      _handle401Redirect(session.reason);
      return;
    }

    if (isBulkOrder) {
      try {
        bulk.clearBulkCart();
        await bulk.clearServerCart();
      } catch (_) {/* ignore */}
    }

    if (isOneDayLunch || isSpecialDish) {
      try {
        await quick.loadOneDayConfig();
        if (isSpecialDish) {
          await quick.loadCartFromServer();
        }
      } catch (_) {/* ignore */}
    }

    if (isCartOrder) {
      // Backend marks the cart as `checked_out` during finalization, so the
      // active GET /cart will return empty. Still call clearCart server-side
      // as a defensive cleanup — but if it fails, we always reset locally.
      try {
        await cart.clearCart();
      } catch (_) {/* ignore */}
      cart.resetLocal();
    } else {
      // Even for single-entity purchases, refetch in case server state changed.
      try {
        await cart.fetchCart();
      } catch (_) {/* ignore */}
    }

    if (session.isExpired) {
      _handle401Redirect(session.reason);
      return;
    }

    // Refresh dashboard-relevant data so Home and management screens stay in sync.
    // HIGH-03: Removed duplicate MealProvider.fetchTodayMenu — MenuProvider.fetchTodayMenu
    // covers the same endpoint. Also removed from the parallel batch to avoid a thundering
    // herd; MenuProvider fetch runs after the main batch settles.
    try {
      final futures = <Future<void>>[
        meal.fetchSubscriptionStatus(force: true),
        meal.fetchMealStatus(force: true),
        meal.fetchAlerts(force: true),
        payment.fetchActiveSubscriptions(),
        payment.fetchPaymentHistory(),
        subscriptions.fetchSubscriptions(force: true),
        profile.fetchProfiles(force: true),
        children.fetchChildren(force: true),
      ];
      await Future.wait(futures);
      if (mounted) {
        await menu.fetchTodayMenu(silent: true);
      }
    } catch (_) {/* ignore — these are best-effort refreshes */}

    if (session.isExpired) {
      _handle401Redirect(session.reason);
      return;
    }
  }

  /// Resolve payment status from the API response.
  /// API response fields: localStatus, gatewayState, orderStatus
  String _resolveStatus(Map<String, dynamic> data) {
    final localStatus = data['localStatus']?.toString().toLowerCase() ?? '';
    final gatewayState = data['gatewayState']?.toString().toUpperCase() ?? '';
    final orderStatus = data['orderStatus']?.toString().toLowerCase() ?? '';

    if (localStatus == 'success' || gatewayState == 'COMPLETED' || orderStatus == 'completed') {
      return 'SUCCESS';
    }
    if (localStatus == 'failed' || gatewayState == 'FAILED' || orderStatus == 'failed') {
      return 'FAILED';
    }
    return 'PENDING';
  }

  String get _currentStatus {
    if (_statusData == null) return 'PENDING';
    return _resolveStatus(_statusData!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _currentStatus;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && status != 'SUCCESS') {
          _abandonPendingIfNeeded();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _isPolling
                      ? _buildLoadingUI(isDark)
                      : (status == 'SUCCESS')
                          ? _buildSuccessUI(isDark)
                          : (status == 'FAILED')
                              ? _buildFailureUI(isDark)
                              : _buildPendingUI(isDark),
                ),
              ),
              if (!_isPolling)
                ElevatedButton(
                  onPressed: () async {
                    if (status != 'SUCCESS') {
                      await _abandonPendingIfNeeded();
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to App', style: TextStyle(fontWeight: FontWeight.w800)),
                ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildLoadingUI(bool isDark) {
    return Column(
      children: [
        const CupertinoActivityIndicator(radius: 20),
        const SizedBox(height: 24),
        Text(
          'Verifying Payment Status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 8),
        Text(
          'Please do not close the app or press back.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          'Attempt ${_retryCount + 1} of $_maxRetries',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade400),
        ),
        if (_lastPollingError != null) ...[
          const SizedBox(height: 14),
          Text(
            _lastPollingError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ],
    ).animate().fadeIn();
  }

  Widget _buildSuccessUI(bool isDark) {
    final data = _statusData!;
    final transactionId = data['transactionId']?.toString() ?? widget.txnId;
    final amountPaid = data['amountPaid']?.toString() ?? '0';
    final orderType = data['orderType']?.toString() ?? '';
    final entityName = data['entityName']?.toString() ?? '';
    final entityType = data['entityType']?.toString() ?? '';
    final planName = data['planName']?.toString() ?? '';
    final mealTiming = data['mealTiming']?.toString() ?? '';
    final List cartItems = data['cartItems'] ?? [];
    final Map<String, dynamic>? bulkOrder =
        data['bulkOrder'] is Map ? Map<String, dynamic>.from(data['bulkOrder'] as Map) : null;
    final List bulkItems = bulkOrder?['items'] is List ? bulkOrder!['items'] as List : [];

    final createdAtRaw = data['createdAt']?.toString() ?? '';
    String paymentTime = '';
    if (createdAtRaw.isNotEmpty) {
      final parsedDt = DateTime.tryParse(createdAtRaw);
      if (parsedDt != null) {
        paymentTime = DateFormat('d MMM yyyy, h:mm a').format(parsedDt.toLocal());
      } else {
        paymentTime = createdAtRaw;
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 40),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
          const SizedBox(height: 12),
          if (orderType == 'cart')
            Text(
              'Your cart order is now active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
            )
          else if (orderType == 'bulk')
            Text(
              'Your bulk meal order is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
            )
          else
            Text(
              entityName.isNotEmpty
                ? 'Meal Plan for $entityName ($planName) is now active.'
                : 'Your meal plan is now active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
            ),
          const SizedBox(height: 32),

          AppleCard(
            child: Column(
              children: [
                _buildStatusRow('Transaction ID', transactionId, isDark),
                _buildStatusRow('Amount Paid', '₹$amountPaid', isDark),
                if (paymentTime.isNotEmpty)
                  _buildStatusRow('Payment Date/Time', paymentTime, isDark),
                if (orderType.isNotEmpty)
                  _buildStatusRow('Order Type', orderType.toUpperCase(), isDark),
                if (orderType != 'cart' && planName.isNotEmpty)
                  _buildStatusRow('Plan', planName, isDark),
                if (orderType != 'cart' && entityName.isNotEmpty)
                  _buildStatusRow('For', '$entityName${entityType.isNotEmpty ? ' ($entityType)' : ''}', isDark),
                if (orderType != 'cart' && mealTiming.isNotEmpty)
                  _buildStatusRow('Meal Delivery Time', TimeUtils.formatToDisplay(mealTiming), isDark),
              ],
            ),
          ),

          if (bulkOrder != null) ...[
            const SizedBox(height: 12),
            AppleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    'Delivery',
                    '${bulkOrder['delivery_date'] ?? ''}'.length >= 10
                        ? '${bulkOrder['delivery_date']}'.substring(0, 10)
                        : '${bulkOrder['delivery_date']}',
                    isDark,
                  ),
                  _buildStatusRow('Meals', '${bulkOrder['total_quantity'] ?? ''}', isDark),
                ],
              ),
            ),
          ],
          if (bulkItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bulk order lines',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 12),
            ...bulkItems.map((item) {
              final row = Map<String, dynamic>.from(item as Map);
              final imageUrl = row['image_url']?.toString() ?? '';
              final menuItems = row['menu_items']?.toString() ?? '';
              return AppleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 100, maxHeight: 200),
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          alignment: Alignment.center,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    if (imageUrl.isNotEmpty) const SizedBox(height: 10),
                    Text('${row['menu_date']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (menuItems.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(menuItems, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text('Qty: ${row['quantity']} · ₹${row['line_total']}'),
                  ],
                ),
              );
            }),
          ],
          // Show cart items if this was a cart checkout
          if (cartItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Items Purchased',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 12),
            ...cartItems.map((item) => _buildCartItemCard(item, isDark)),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  /// Build a card for each cart item in the checkout response
  Widget _buildCartItemCard(Map<String, dynamic> item, bool isDark) {
    final entityName = item['entity_name']?.toString() ?? '';
    final entityType = item['entity_type']?.toString() ?? '';
    final planName = item['plan_name']?.toString() ?? '';
    final unitPrice = item['unit_price']?.toString() ?? '0';
    final startDate = item['start_date']?.toString() ?? '';
    final mealSizeName = item['meal_size_name']?.toString() ?? '';
    final mealTiming = item['meal_timing']?.toString() ?? '';

    IconData icon;
    Color color;
    switch (entityType) {
      case 'child':
        icon = CupertinoIcons.person_3_fill;
        color = Colors.blue;
        break;
      case 'teacher':
        icon = CupertinoIcons.book_fill;
        color = Colors.green;
        break;
      case 'professional':
        icon = CupertinoIcons.briefcase_fill;
        color = Colors.orange;
        break;
      default:
        icon = CupertinoIcons.person_fill;
        color = AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entityName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                Text('$planName • ${entityType.toUpperCase()}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                if (mealSizeName.isNotEmpty)
                  Text('Meal Size: $mealSizeName', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                if (mealTiming.isNotEmpty)
                  Text('Delivery: ${TimeUtils.formatToDisplay(mealTiming)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                if (startDate.isNotEmpty)
                  Text('Start: ${MealDate.formatDisplay(startDate)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
              ],
            ),
          ),
          Text('₹$unitPrice', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildFailureUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 40),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Payment Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 12),
        Text(
          'Something went wrong with your transaction. Your cart has been kept so you can try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
        ),
        if (widget.txnId.isNotEmpty) ...[
          const SizedBox(height: 24),
          AppleCard(child: _buildStatusRow('Transaction ID', widget.txnId, isDark)),
        ],
      ],
    ).animate().fadeIn();
  }

  Widget _buildPendingUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.clock, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        Text(
          'Payment is Pending',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 12),
        Text(
          'We are still waiting for confirmation from your bank. It should update shortly. Your cart is preserved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
        ),
        if (_lastPollingError != null) ...[
          const SizedBox(height: 16),
          Text(
            _lastPollingError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            // CRITICAL-02: _startPolling() has an in-flight guard — calling it
            // while a loop is running is a no-op.
            setState(() {
              _isPolling = true;
              _retryCount = 0;
            });
            _startPolling();
          },
          icon: const Icon(CupertinoIcons.refresh, size: 16),
          label: const Text('Check Again', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
