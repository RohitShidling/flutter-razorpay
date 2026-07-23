import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/utils/error_handler.dart';

import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/widgets/wallet_checkout_section.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _useWallet = true;
  bool _loadingWalletPreview = false;
  double? _walletApplied;
  double? _gatewayAmount;
  CartProvider? _cartProvider;
  String? _localError;

  bool _isInitialized = false;

  static double _parseMoney(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  double _getExtraAmount(CartItem item) {
    final lookup = context.read<LookupProvider>();
    if (item.entityType == 'child') {
      final childrenProvider = context.read<ChildrenProvider>();
      final child = childrenProvider.children.where((c) => c.id == item.entityId).firstOrNull;
      if (child != null) {
        final school = lookup.schools.where((s) => s.id == child.schoolId).firstOrNull;
        return school?.extraAmount ?? 0.0;
      }
    } else if (item.entityType == 'teacher') {
      final profileProvider = context.read<ProfileProvider>();
      final teacher = profileProvider.teacherProfiles.where((t) => t.id == item.entityId).firstOrNull;
      if (teacher != null) {
        // AUDIT-056: Prefer stable school_id lookup; fall back to name-match for
        // legacy profiles that pre-date the school_id field.
        final school = (teacher.schoolId != null && teacher.schoolId!.isNotEmpty)
             ? lookup.schools.where((s) => s.id == teacher.schoolId).firstOrNull ??
               lookup.schools.where((s) => s.name == teacher.schoolCollegeName).firstOrNull
             : lookup.schools.where((s) => s.name == teacher.schoolCollegeName).firstOrNull;
        return school?.extraAmount ?? 0.0;
      }
    } else if (item.entityType == 'professional') {
      final profileProvider = context.read<ProfileProvider>();
      final professional = profileProvider.professionalProfiles.where((p) => p.id == item.entityId).firstOrNull;
      if (professional != null) {
        final loc = lookup.corporateLocations.where((c) => c.id == professional.corporateLocationId).firstOrNull;
        return loc?.extraAmount ?? 0.0;
      }
    }
    return 0.0;
  }

  @override
  void dispose() {
    _cartProvider?.removeListener(_scheduleWalletPreview);
    AppRouteTracker.instance.clearIfCurrent(AppScreen.cart);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.cart);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NetworkStatusService.instance.refreshNow();
      if (!mounted) return;
      final cart = context.read<CartProvider>();
      _cartProvider = cart;
      cart.addListener(_scheduleWalletPreview);
      await context.read<PaymentProvider>().fetchWallet(silent: true);
      await cart.fetchCart(force: false);
      cart.syncOfflineItemsIfAny();
      if (!mounted) return;
      context.read<SubscriptionProvider>().fetchSubscriptions(force: false, silent: true);
      _refreshWalletPreview(cart);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  void _scheduleWalletPreview() {
    if (!mounted || _cartProvider == null) return;
    _refreshWalletPreview(_cartProvider!);
  }

  Future<void> _refreshWalletPreview(CartProvider cart) async {
    if (!mounted) return;
    final total = cart.totalAmount;
    if (total <= 0) {
      setState(() {
        _walletApplied = 0;
        _gatewayAmount = 0;
      });
      return;
    }

    setState(() => _loadingWalletPreview = true);
    try {
      final pay = context.read<PaymentProvider>();
      final preview = await pay.previewWalletForTotal(total, useWallet: _useWallet);
      if (!mounted) return;
      setState(() {
        _walletApplied = _parseMoney(preview['walletApplied']);
        _gatewayAmount = _parseMoney(preview['gatewayAmount']);
      });
    } catch (_) {
      // Preview is optional — checkout still works without breakdown.
    } finally {
      if (mounted) setState(() => _loadingWalletPreview = false);
    }
  }

  void _onUseWalletChanged(bool value) {
    final total = _cartProvider?.totalAmount ?? 0;
    setState(() {
      _useWallet = value;
      if (!value) {
        _walletApplied = 0;
        _gatewayAmount = total;
      }
    });
    if (_cartProvider != null) _refreshWalletPreview(_cartProvider!);
  }

  double _amountDueNow(CartProvider cart) {
    if (!_useWallet) return cart.totalAmount;
    if (_gatewayAmount != null) return _gatewayAmount!;
    return cart.totalAmount;
  }

  /// Match cart line to catalog plan so we can show per-variant duration (with vs without Saturday).
  SubscriptionModel? _planForItem(CartItem item, List<SubscriptionModel> plans) {
    final sid = item.subscriptionId?.trim();
    if (sid == null || sid.isEmpty) return null;
    for (final p in plans) {
      if (p.id == sid) return p;
    }
    return null;
  }

  int? _durationDaysForCartLine(CartItem item, SubscriptionModel? plan) {
    if (plan == null) return null;
    final d = item.includeSaturday
        ? (plan.durationDaysWithSaturday ?? plan.durationDays)
        : (plan.durationDaysWithoutSaturday ?? plan.durationDays);
    if (d <= 0) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final subscriptionPlans = context.watch<SubscriptionProvider>().subscriptions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = cartProvider.items;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Cart',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (items.isNotEmpty)
              TextButton(
                onPressed: () => _confirmClearCart(context, cartProvider),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF8B7A66),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          systemOverlayStyle: AppTheme.overlayFor(
            background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
          ),
        ),
      body: (!_isInitialized || (cartProvider.isLoading && items.isEmpty))
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _buildEmptyCart(isDark)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: RefreshIndicator(
                              onRefresh: () => cartProvider.fetchCart(force: true),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return _buildCartItem(
                                        context,
                                        items[index],
                                        index,
                                        isDark,
                                        cartProvider,
                                        _planForItem(items[index], subscriptionPlans),
                                      )
                                      .animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
                                },
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final displayError = _localError ?? cartProvider.error;
                                      if (displayError != null && displayError.isNotEmpty) {
                                        return _buildErrorBanner(displayError, isDark);
                                      }
                                      return const SizedBox.shrink();
                                    }
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _buildCheckoutBarContent(context, cartProvider, isDark),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () => cartProvider.fetchCart(force: true),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return _buildCartItem(
                                        context,
                                        items[index],
                                        index,
                                        isDark,
                                        cartProvider,
                                        _planForItem(items[index], subscriptionPlans),
                                      )
                                      .animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
                                },
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final displayError = _localError ?? cartProvider.error;
                              if (displayError != null && displayError.isNotEmpty) {
                                return _buildErrorBanner(displayError, isDark);
                              }
                              return const SizedBox.shrink();
                            }
                          ),
                          _buildCheckoutBar(context, cartProvider, isDark),
                        ],
                      );
                    }
                  },
                ),
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cart, size: 80, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
            ),
            const SizedBox(height: 8),
            Text(
              'Add subscriptions from the Resize meal pack screen',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, int index, bool isDark, CartProvider cartProvider, SubscriptionModel? matchedPlan) {
    IconData entityIcon;
    Color entityColor;
    switch (item.entityType) {
      case 'child':
        entityIcon = CupertinoIcons.person_3_fill;
        entityColor = Colors.blue;
        break;
      case 'teacher':
        entityIcon = CupertinoIcons.book_fill;
        entityColor = Colors.green;
        break;
      case 'professional':
        entityIcon = CupertinoIcons.briefcase_fill;
        entityColor = Colors.orange;
        break;
      default:
        entityIcon = CupertinoIcons.person_fill;
        entityColor = AppTheme.primaryColor;
    }

    return Dismissible(
      key: ValueKey('cart_item_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(20)),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final success = await cartProvider.removeItem(item.id);
        if (!success && mounted) {
          setState(() {
            _localError = cartProvider.error ?? 'Could not remove item';
          });
        }
        return false; // Don't animate dismiss — fetchCart will refresh the list
      },
      child: AppleCard(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: entityColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(entityIcon, color: entityColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.entityName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                      Text(item.entityType.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : AppTheme.textSecondaryLight, letterSpacing: 0.8)),
                    ],
                  ),
                ),
                Builder(
                  builder: (ctx) {
                    final extra = _getExtraAmount(item);
                    final basePrice = item.unitPrice - extra;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${basePrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.primaryColor)),
                        if (extra != 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${extra > 0 ? "+" : "-"}₹${extra.abs().toStringAsFixed(0)} Adjustment',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: extra > 0 ? AppTheme.primaryColor : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Plan', item.planName, isDark),
            _buildDetailRow('Variant', item.includeSaturday ? 'Including Sat' : 'Excluding Sat', isDark),
            if (_durationDaysForCartLine(item, matchedPlan) != null)
              _buildDetailRow(
                'Plan length',
                '${_durationDaysForCartLine(item, matchedPlan)} days',
                isDark,
              ),
            if ((item.mealSizeName ?? '').isNotEmpty)
              _buildDetailRow('Meal Size', item.mealSizeName!, isDark),
            if ((item.mealTiming ?? '').isNotEmpty)
              _buildDetailRow('Meal Delivery Time', TimeUtils.formatToDisplay(item.mealTiming), isDark),
            _buildStartDateRow(context, item, isDark, cartProvider),
            const SizedBox(height: 8),
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmRemoveItem(context, item, cartProvider),
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateRow(BuildContext context, CartItem item, bool isDark, CartProvider cartProvider) {
    final hasNoDate = item.startDate == null || item.startDate!.trim().isEmpty;
    final value = hasNoDate ? 'Choose start date' : MealDate.formatDisplay(item.startDate);
    final isFlagged = hasNoDate || !MealDate.isValidFutureStartDate(item.startDate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Start Date', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : AppTheme.textSecondaryLight)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFlagged ? Colors.orange.shade600 : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: cartProvider.isLoading ? null : () => _changeStartDate(item, cartProvider),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(88, 0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.45), width: 1.5),
              ),
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStartDate(CartItem item, CartProvider cartProvider) async {
    final first = MealDate.firstSelectableStartDate();
    final last = MealDate.lastSelectableStartDate();
    final initial = MealDate.parseOrTomorrow(item.startDate);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (date) => date.weekday != DateTime.sunday,
      helpText: 'Select Meal Start Date',
      confirmText: 'SAVE',
    );
    if (selectedDate == null || !mounted) return;
    final dateStr = MealDate.formatYmd(selectedDate);
    final ok = await cartProvider.updateItemStartDate(item.id, dateStr);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final invalid = cartProvider.items.where((i) => i.startDate == null || i.startDate!.trim().isEmpty).toList();
        if (invalid.isEmpty) {
          _localError = null;
        } else if (_localError == 'Please select a start date for all items in your cart.') {
          _localError = 'Please select a start date for all items in your cart.';
        }
      });
      ErrorHandler.showSuccess(context, 'Start date updated');
    } else if (cartProvider.error != null) {
      setState(() {
        _localError = cartProvider.error;
      });
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartProvider cartProvider, bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding > 0 ? bottomPadding + 10 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.orange.withValues(alpha: 0.4) : AppTheme.primaryColor,
            width: 2.0,
          ),
        ),
      ),
      child: _buildCheckoutBarContent(context, cartProvider, isDark),
    );
  }

  Widget _buildCheckoutBarContent(BuildContext context, CartProvider cartProvider, bool isDark) {
    final pay = context.watch<PaymentProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            InkWell(
              onTap: () => _showBillDetailsBottomSheet(context, cartProvider, isDark),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WalletCheckoutSection(
          useWallet: _useWallet,
          onUseWalletChanged: _onUseWalletChanged,
          walletBalance: pay.walletBalance,
          walletApplied: _walletApplied,
          gatewayAmount: _gatewayAmount,
          totalAmount: cartProvider.totalAmount,
          loadingPreview: _loadingWalletPreview,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_useWallet && (_walletApplied ?? 0) > 0) ...[
                  Text(
                    'Order total ₹${cartProvider.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  _useWallet && (_walletApplied ?? 0) > 0 ? 'You pay now' : 'Total amount',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                ),
                Text(
                  '₹${_amountDueNow(cartProvider).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: cartProvider.isLoading ? null : () => _handleCheckout(cartProvider),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Text(
              _amountDueNow(cartProvider) <= 0.009 && _useWallet
                  ? 'Complete with wallet'
                  : 'Pay ₹${_amountDueNow(cartProvider).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  void _handleCheckout(CartProvider cartProvider) async {
    final invalid = cartProvider.items.where((i) => i.startDate == null || i.startDate!.trim().isEmpty).toList();
    if (invalid.isNotEmpty) {
      setState(() {
        _localError = 'Please select a start date for all items in your cart.';
      });
      return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(20)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [CupertinoActivityIndicator(radius: 14), SizedBox(height: 16), Text('Processing checkout...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
        ),
      ),
    );

    var result = await cartProvider.checkoutAll(
      isSandbox: ApiEndpoints.isTestModePayment,
      useWallet: _useWallet,
    );
    if (result == null && mounted) {
      final err = cartProvider.error ?? '';
      if (err.toLowerCase().contains('pending')) {
        await context.read<PaymentProvider>().abandonPendingPayment(cancelPendingCart: true);
        if (mounted) {
          await cartProvider.fetchCart(force: true);
          if (!mounted) return;
          result = await cartProvider.checkoutAll(
            isSandbox: ApiEndpoints.isTestModePayment,
            useWallet: _useWallet,
          );
        }
      }
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted || result == null) {
      if (mounted && cartProvider.error != null) {
        setState(() {
          _localError = cartProvider.error;
        });
      }
      return;
    }

    final pay = context.read<PaymentProvider>();
    final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
    final txnId = result['merchantTransactionId']?.toString() ?? '';
    final orderId = result['orderId']?.toString() ?? '';

    // ── Handle each SDK outcome ─────────────────────────────────────────────
    if (sdkStatus == 'SUCCESS') {
      // Razorpay confirmed payment on-device. Navigate to status screen
      // where backend signature verification + webhook confirm it.
      await pay.fetchWallet(silent: true);
      if (!mounted) return;
      if (txnId.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentStatusScreen(txnId: txnId, orderId: orderId, orderType: 'cart'),
          ),
        );
      }
    } else if (sdkStatus == 'EXTERNAL_WALLET') {
      // User was redirected to an external wallet app (PhonePe, GPay, etc.).
      // The payment may still complete — webhook will handle it.
      // Navigate to status screen to poll for the result.
      if (!mounted) return;
      if (txnId.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentStatusScreen(txnId: txnId, orderId: orderId, orderType: 'cart'),
          ),
        );
      }
    } else if (sdkStatus == 'CANCELLED') {
      // User explicitly dismissed the Razorpay checkout.
      // Abandon the pending order and restore wallet balance.
      await pay.abandonPendingPayment(
        orderId: orderId.isNotEmpty ? orderId : null,
        merchantTransactionId: txnId.isNotEmpty ? txnId : null,
      );
      if (!mounted) return;
      setState(() {
        _localError = 'Payment cancelled.';
      });
    } else {
      // FAILURE — Razorpay reported an error (network, bank decline, etc.)
      await pay.abandonPendingPayment(
        orderId: orderId.isNotEmpty ? orderId : null,
        merchantTransactionId: txnId.isNotEmpty ? txnId : null,
      );
      if (!mounted) return;
      final errorMsg = result['sdkError']?.toString();
      setState(() {
        _localError = (errorMsg != null && errorMsg.isNotEmpty && errorMsg != 'null')
            ? errorMsg
            : 'Payment failed. Please try again.';
      });
    }
  }

  void _confirmRemoveItem(BuildContext context, CartItem item, CartProvider cartProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.entityName} from your cart?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final ok = await cartProvider.removeItem(item.id);
              if (context.mounted) {
                setState(() {
                  if (!ok && cartProvider.error != null) {
                    _localError = cartProvider.error;
                  } else {
                    final invalid = cartProvider.items.where((i) => i.startDate == null || i.startDate!.trim().isEmpty).toList();
                    if (invalid.isEmpty) {
                      _localError = null;
                    } else if (_localError == 'Please select a start date for all items in your cart.') {
                      _localError = 'Please select a start date for all items in your cart.';
                    }
                  }
                });
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(BuildContext context, CartProvider cartProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final ok = await cartProvider.clearCart();
              if (context.mounted) {
                setState(() {
                  if (!ok && cartProvider.error != null) {
                    _localError = cartProvider.error;
                  } else {
                    _localError = null;
                  }
                });
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, bool isDark) {
    final isSelectStartDate = message.toLowerCase().contains('select a start date') ||
        message.toLowerCase().contains('select start date');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSelectStartDate ? 8 : 12),
      decoration: isSelectStartDate
          ? null
          : BoxDecoration(
              color: isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFEE2E2),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF3A1A1A) : Colors.red.shade200,
                  width: 1,
                ),
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF3A1A1A) : Colors.red.shade200,
                  width: 1,
                ),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: isSelectStartDate
                ? Colors.orange.shade700
                : (isDark ? Colors.red.shade400 : Colors.red.shade700),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: isSelectStartDate
                    ? (isDark ? Colors.orange.shade300 : Colors.orange.shade800)
                    : (isDark ? Colors.red.shade200 : Colors.red.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBillDetailsBottomSheet(BuildContext context, CartProvider cartProvider, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Detailed Bill Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cartProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = cartProvider.items[index];
                      final extra = _getExtraAmount(item);
                      final basePrice = item.unitPrice - extra;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262629) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.entityName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.entityType.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildBottomSheetRow('Base Plan Price', '₹${basePrice.toStringAsFixed(0)}', isDark),
                            if (extra != 0) ...[
                              const SizedBox(height: 4),
                              _buildBottomSheetRow(
                                'Adjustment',
                                '${extra > 0 ? "+" : "-"}₹${extra.abs().toStringAsFixed(0)}',
                                isDark,
                                valueColor: extra > 0
                                    ? AppTheme.primaryColor
                                    : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                              ),
                            ],
                            const Divider(height: 16),
                            _buildBottomSheetRow('Item Total', '₹${item.unitPrice.toStringAsFixed(0)}', isDark, bold: true),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(thickness: 1),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    double totalBasePrice = 0;
                    double totalAdjustment = 0;
                    for (final item in cartProvider.items) {
                      final extra = _getExtraAmount(item);
                      totalBasePrice += (item.unitPrice - extra);
                      totalAdjustment += extra;
                    }
                    return Column(
                      children: [
                        _buildBottomSheetRow('Total Base Plan', '₹${totalBasePrice.toStringAsFixed(0)}', isDark),
                        const SizedBox(height: 4),
                        _buildBottomSheetRow(
                          'Total Adjustment',
                          '${totalAdjustment >= 0 ? "+" : "-"}₹${totalAdjustment.abs().toStringAsFixed(0)}',
                          isDark,
                          valueColor: totalAdjustment >= 0
                              ? AppTheme.primaryColor
                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                        ),
                        const SizedBox(height: 6),
                        _buildBottomSheetRow(
                          'Total Order Price',
                          '₹${cartProvider.totalAmount.toStringAsFixed(0)}',
                          isDark,
                          bold: true,
                          fontSize: 15,
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetRow(String label, String value, bool isDark, {bool bold = false, double fontSize = 13, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}
