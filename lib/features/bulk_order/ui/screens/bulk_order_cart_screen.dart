import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_variety_categories_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_checkout.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_payment_sheet.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

/// Review bulk cart (standard + large variety) and pay with delivery details at checkout.
class BulkOrderCartScreen extends StatefulWidget {
  const BulkOrderCartScreen({super.key});

  @override
  State<BulkOrderCartScreen> createState() => _BulkOrderCartScreenState();
}

class _BulkOrderCartScreenState extends State<BulkOrderCartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<BulkOrderProvider>();
      if (provider.config == null) {
        await provider.loadConfig();
      }
      if (!mounted) return;
      await provider.loadCartFromServer();
      if (!mounted) return;
      final date = provider.standardDeliveryDate;
      if ((provider.standardQty ?? 0) > 0 && date != null && date.length >= 10) {
        await provider.loadMenusForDate(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cfg == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(
          background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          isDark: isDark,
          navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Text(
              'Bulk Cart',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF5A4D42),
              ),
            ),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
              onPressed: () => Navigator.pop(context),
            ),
            systemOverlayStyle: AppTheme.overlayFor(
              background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
              isDark: isDark,
              navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final standardQty = p.standardQty ?? 0;
    final varietyLines = p.varietyQty.entries.where((e) => e.value > 0).toList();
    final isVariety = varietyLines.isNotEmpty;
    final isStandard = standardQty > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : Colors.white,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Bulk Cart',
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
            if (p.hasBulkCartItems)
              TextButton(
                onPressed: () {
                  p.clearBulkCart();
                  Navigator.pop(context);
                },
                child: Text(
                  'Clear',
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
            navigationBarColor: isDark ? AppTheme.surfaceDark : Colors.white,
          ),
        ),
        body: !p.hasBulkCartItems
            ? SafeArea(child: _buildEmptyCart(isDark))
            : ResponsiveContainer(
                maxWidth: 1000.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (isStandard) ...[
                                  _sectionHeader(
                                    context,
                                    'Standard Bulk',
                                    CupertinoIcons.person_3_fill,
                                    AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 10),
                                  _StandardCartCard(
                                    menuName: p.deliveryMenu?.items ?? 'Daily menu',
                                    imageUrl: p.deliveryMenu?.imageUrl,
                                    quantity: standardQty,
                                    pricePerMeal: (p.deliveryMenu?.pricePerMeal != null &&
                                            p.deliveryMenu!.pricePerMeal! > 0)
                                        ? p.deliveryMenu!.pricePerMeal!
                                        : cfg.pricePerMealUnderThreshold,
                                    isDark: isDark,
                                    deliveryDate: p.standardDeliveryDate,
                                    onIncrement: () => p.setStandardDraft(standardQty + 1),
                                    onDecrement: () {
                                      if (standardQty > 1) p.setStandardDraft(standardQty - 1);
                                    },
                                    onRemove: () => p.setStandardDraft(0),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (isVariety) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _sectionHeader(
                                          context,
                                          'Large Event Bulk',
                                          CupertinoIcons.square_stack_3d_up_fill,
                                          Colors.deepOrange,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => const BulkOrderVarietyCategoriesScreen(),
                                          ),
                                        ),
                                        icon: const Icon(CupertinoIcons.plus_circle, size: 16),
                                        label: const Text('Add more'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...varietyLines.map((e) {
                                    final meal = p.mealById(e.key);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _VarietyCartCard(
                                        mealName: meal?.items ?? e.key,
                                        imageUrl: meal?.imageUrl,
                                        categoryName: p.categoryNameForMeal(e.key),
                                        quantity: e.value,
                                        pricePerMeal: meal?.pricePerMeal,
                                        isDark: isDark,
                                        onIncrement: () => p.setVarietyQty(e.key, e.value + 1),
                                        onDecrement: () {
                                          if (e.value > 1) {
                                            p.setVarietyQty(e.key, e.value - 1);
                                          }
                                        },
                                        onRemove: () => p.setVarietyQty(e.key, 0),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  _totalPortionsInfo(p.varietyLineSum, cfg.tierThreshold, isDark),
                                ],
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _PriceSummary(provider: p, config: cfg, isDark: isDark),
                                  const SizedBox(height: 20),
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
                                    child: _BottomPayBar(
                                      totalMeals: p.bulkCartTotalMeals,
                                      isLoading: p.isLoading,
                                      onPay: () => _startPay(p, cfg),
                                      isDark: isDark,
                                      isWide: true,
                                    ),
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
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (isStandard) ...[
                                  _sectionHeader(
                                    context,
                                    'Standard Bulk',
                                    CupertinoIcons.person_3_fill,
                                    AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 10),
                                  _StandardCartCard(
                                    menuName: p.deliveryMenu?.items ?? 'Daily menu',
                                    imageUrl: p.deliveryMenu?.imageUrl,
                                    quantity: standardQty,
                                    pricePerMeal: (p.deliveryMenu?.pricePerMeal != null &&
                                            p.deliveryMenu!.pricePerMeal! > 0)
                                        ? p.deliveryMenu!.pricePerMeal!
                                        : cfg.pricePerMealUnderThreshold,
                                    isDark: isDark,
                                    deliveryDate: p.standardDeliveryDate,
                                    onIncrement: () => p.setStandardDraft(standardQty + 1),
                                    onDecrement: () {
                                      if (standardQty > 1) p.setStandardDraft(standardQty - 1);
                                    },
                                    onRemove: () => p.setStandardDraft(0),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (isVariety) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _sectionHeader(
                                          context,
                                          'Large Event Bulk',
                                          CupertinoIcons.square_stack_3d_up_fill,
                                          Colors.deepOrange,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => const BulkOrderVarietyCategoriesScreen(),
                                          ),
                                        ),
                                        icon: const Icon(CupertinoIcons.plus_circle, size: 16),
                                        label: const Text('Add more'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...varietyLines.map((e) {
                                    final meal = p.mealById(e.key);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _VarietyCartCard(
                                        mealName: meal?.items ?? e.key,
                                        imageUrl: meal?.imageUrl,
                                        categoryName: p.categoryNameForMeal(e.key),
                                        quantity: e.value,
                                        pricePerMeal: meal?.pricePerMeal,
                                        isDark: isDark,
                                        onIncrement: () => p.setVarietyQty(e.key, e.value + 1),
                                        onDecrement: () {
                                          if (e.value > 1) {
                                            p.setVarietyQty(e.key, e.value - 1);
                                          }
                                        },
                                        onRemove: () => p.setVarietyQty(e.key, 0),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  _totalPortionsInfo(p.varietyLineSum, cfg.tierThreshold, isDark),
                                ],
                                const SizedBox(height: 16),
                                _PriceSummary(provider: p, config: cfg, isDark: isDark),
                              ],
                            ),
                          ),
                          _BottomPayBar(
                            totalMeals: p.bulkCartTotalMeals,
                            isLoading: p.isLoading,
                            onPay: () => _startPay(p, cfg),
                            isDark: isDark,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.cart, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Your bulk cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add meals from standard or large event bulk.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }

  Widget _totalPortionsInfo(int sum, int minThreshold, bool isDark) {
    final isValid = sum >= minThreshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isValid ? Colors.green : Colors.orange).withValues(
          alpha: isDark ? 0.15 : 0.08,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isValid ? Colors.green : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.exclamationmark_triangle_fill,
            color: isValid ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'Total: $sum portions (min $minThreshold)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPay(BulkOrderProvider p, cfg) async {
    if (p.standardQty != null && p.standardQty! > 0) {
      final err = p.validateStandardDraft(cfg);
      if (err != null) {
        ErrorHandler.showError(context, err);
        return;
      }
    }
    if (p.varietyLineSum > 0) {
      final err = p.validateVarietyCart(cfg, forPayment: true);
      if (err != null) {
        ErrorHandler.showError(context, err);
        return;
      }
    }

    final isVariety = p.varietyLineSum > 0;
    final isStandard = (p.standardQty ?? 0) > 0;
    final initialDate = p.standardDeliveryDate;

    await BulkOrderPaymentSheet.show(
      context,
      config: cfg,
      initialDeliveryDate: initialDate,
      isStandardBulk: isStandard,
      onConfirm: (deliveryDate) async {
        if (isStandard && isVariety) {
          await p.loadMenusForDate(deliveryDate);
          if (!mounted) return;
          if (p.deliveryMenu == null) {
            ErrorHandler.showError(context, 'No menu available for this delivery date');
            return;
          }

          final summaryParts = <String>[
            'Standard: ${p.deliveryMenu!.items} x ${p.standardQty}',
          ];
          summaryParts.addAll(
            p.varietyQty.entries.where((e) => e.value > 0).map((e) {
              final cat = p.categoryNameForMeal(e.key);
              final name = p.mealById(e.key)?.items ?? e.key;
              return cat != null ? '$cat - $name x ${e.value}' : '$name x ${e.value}';
            }),
          );

          await BulkOrderCheckout.pay(
            context: context,
            provider: p,
            deliveryDate: deliveryDate,
            items: const [],
            totalMeals: p.bulkCartTotalMeals,
            summaryLines: summaryParts.join('\n'),
            useBundle: true,
          );
          return;
        }

        if (isStandard) {
          final dateForMenu = p.standardDeliveryDate ?? deliveryDate;
          await p.loadMenusForDate(dateForMenu);
          if (!mounted) return;
          if (p.deliveryMenu == null) {
            ErrorHandler.showError(context, 'No menu available for this delivery date');
            return;
          }

          final items = [
            {'dailyMenuId': p.deliveryMenu!.id, 'quantity': p.standardQty!},
          ];
          await BulkOrderCheckout.pay(
            context: context,
            provider: p,
            deliveryDate: dateForMenu,
            items: items,
            totalMeals: p.standardQty!,
            summaryLines: p.deliveryMenu!.items,
          );
          return;
        }

        final items = p.varietyQty.entries
            .where((e) => e.value > 0)
            .map((e) => {'bulkMealId': e.key, 'quantity': e.value})
            .toList();
        final summary = p.varietyQty.entries.where((e) => e.value > 0).map((e) {
          final cat = p.categoryNameForMeal(e.key);
          final name = p.mealById(e.key)?.items ?? e.key;
          return cat != null ? '$cat - $name x ${e.value}' : '$name x ${e.value}';
        }).join('\n');

        await BulkOrderCheckout.pay(
          context: context,
          provider: p,
          deliveryDate: deliveryDate,
          items: items,
          totalMeals: p.varietyLineSum,
          summaryLines: summary,
        );
      },
    );
  }
}

class _StandardCartCard extends StatelessWidget {
  const _StandardCartCard({
    required this.menuName,
    this.imageUrl,
    required this.quantity,
    required this.pricePerMeal,
    required this.isDark,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.deliveryDate,
  });

  final String menuName;
  final String? imageUrl;
  final int quantity;
  final double pricePerMeal;
  final bool isDark;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final String? deliveryDate;

  @override
  Widget build(BuildContext context) {
    final subtotal = pricePerMeal * quantity;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: getFullImageUrl(imageUrl!),
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        child: const Center(child: CupertinoActivityIndicator()),
                      ),
                      errorWidget: (_, __, ___) => _placeholderIcon(),
                    )
                  : _placeholderIcon(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menuName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deliveryDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Delivery Date: $deliveryDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Rs ${pricePerMeal.toStringAsFixed(2)} per meal',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyButton(CupertinoIcons.minus, onDecrement, quantity <= 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _qtyButton(CupertinoIcons.plus, onIncrement, false),
                      const Spacer(),
                      Text(
                        'Rs ${subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: Colors.red.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: disabled
              ? Colors.grey.withValues(alpha: 0.1)
              : AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? Colors.grey : AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _VarietyCartCard extends StatelessWidget {
  const _VarietyCartCard({
    required this.mealName,
    this.imageUrl,
    this.categoryName,
    required this.quantity,
    this.pricePerMeal,
    required this.isDark,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final String mealName;
  final String? imageUrl;
  final String? categoryName;
  final int quantity;
  final double? pricePerMeal;
  final bool isDark;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtotal = pricePerMeal != null ? pricePerMeal! * quantity : null;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 80,
              height: 80,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: getFullImageUrl(imageUrl!),
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(
                        color: Colors.deepOrange.withValues(alpha: 0.06),
                        child: const Center(child: CupertinoActivityIndicator()),
                      ),
                      errorWidget: (_, __, ___) => _placeholderIcon(),
                    )
                  : _placeholderIcon(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (categoryName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      categoryName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (pricePerMeal != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Rs ${pricePerMeal!.toStringAsFixed(2)}/meal',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _qtyButton(CupertinoIcons.minus, onDecrement, quantity <= 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _qtyButton(CupertinoIcons.plus, onIncrement, false),
                      const Spacer(),
                      if (subtotal != null)
                        Text(
                          'Rs ${subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.deepOrange,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: Colors.red.withValues(alpha: 0.6),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: Colors.deepOrange.withValues(alpha: 0.06),
      child: const Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: disabled
              ? Colors.grey.withValues(alpha: 0.1)
              : Colors.deepOrange.withValues(alpha: 0.12),
        ),
        child: Icon(
          icon,
          size: 14,
          color: disabled ? Colors.grey : Colors.deepOrange,
        ),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.provider,
    required this.config,
    required this.isDark,
  });

  final BulkOrderProvider provider;
  final BulkOrderConfig config;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final standardQty = provider.standardQty ?? 0;
    final varietyLines = provider.varietyQty.entries.where((e) => e.value > 0).toList();

    double estimatedTotal = 0;
    if (standardQty > 0) {
      final standardPrice = (provider.deliveryMenu?.pricePerMeal != null &&
              provider.deliveryMenu!.pricePerMeal! > 0)
          ? provider.deliveryMenu!.pricePerMeal!
          : config.pricePerMealUnderThreshold;
      estimatedTotal += standardQty * standardPrice;
    }
    for (final e in varietyLines) {
      final meal = provider.mealById(e.key);
      if (meal?.pricePerMeal != null) {
        estimatedTotal += meal!.pricePerMeal! * e.value;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          _row('Total meals', '${provider.bulkCartTotalMeals}', isDark),
          if (estimatedTotal > 0) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _row('Estimated total', 'Rs ${estimatedTotal.toStringAsFixed(0)}', isDark, bold: true),
            const SizedBox(height: 4),
            Text(
              'Final price confirmed at checkout',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, bool isDark, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: FontWeight.w900,
            color: bold ? AppTheme.primaryColor : (isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({
    required this.totalMeals,
    required this.isLoading,
    required this.onPay,
    required this.isDark,
    this.isWide = false,
  });

  final int totalMeals;
  final bool isLoading;
  final VoidCallback onPay;
  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPay,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Proceed to Pay ($totalMeals meals)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );

    if (isWide) {
      return button;
    }

    return Material(
      elevation: 12,
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: button,
        ),
      ),
    );
  }
}
