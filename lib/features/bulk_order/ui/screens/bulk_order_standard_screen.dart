import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

/// Standard bulk: pick delivery date first, preview that day's menu, then quantity.
class BulkOrderStandardScreen extends StatefulWidget {
  const BulkOrderStandardScreen({super.key});

  @override
  State<BulkOrderStandardScreen> createState() => _BulkOrderStandardScreenState();
}

class _BulkOrderStandardScreenState extends State<BulkOrderStandardScreen> {
  String? _selectedDate;
  int _qty = 10;

  @override
  void initState() {
    super.initState();
    final p = context.read<BulkOrderProvider>();
    final cfg = p.config;
    if (cfg != null) _qty = cfg.minQuantity;
    _selectedDate = p.standardDeliveryDate;
    if (_selectedDate != null && _selectedDate!.length >= 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BulkOrderProvider>().loadMenusForDate(_selectedDate!);
      });
    }
  }

  int _maxQty(BulkOrderConfig cfg) => cfg.tierThreshold - 1;

  Future<void> _pickDate(BulkOrderConfig cfg) async {
    final ymd = await pickBulkDeliveryDate(context, cfg, _selectedDate);
    if (ymd == null || !mounted) return;
    setState(() => _selectedDate = ymd);
    await context.read<BulkOrderProvider>().loadMenusForDate(ymd);
  }

  void _increment(BulkOrderConfig cfg) {
    if (_selectedDate != null && _qty < _maxQty(cfg)) setState(() => _qty++);
  }

  void _decrement(BulkOrderConfig cfg) {
    if (_selectedDate != null && _qty > cfg.minQuantity) setState(() => _qty--);
  }

  void _addToCart(BulkOrderProvider p, BulkOrderConfig cfg) {
    if (_selectedDate == null || _selectedDate!.length < 10) {
      ErrorHandler.showValidationError(context, 'Select a delivery date first');
      return;
    }
    if (_qty < cfg.minQuantity) {
      ErrorHandler.showValidationError(context, 'Minimum order is ${cfg.minQuantity} meals');
      return;
    }
    if (_qty >= cfg.tierThreshold) {
      ErrorHandler.showValidationError(context, 'For ${cfg.tierThreshold}+ meals, use the large event bulk option.');
      return;
    }
    if (p.deliveryMenu == null) {
      ErrorHandler.showValidationError(context, 'No menu available for the selected date.');
      return;
    }
    p.clearVarietyCart();
    p.setStandardDraft(_qty, deliveryDate: _selectedDate);
    ErrorHandler.showSuccess(context, 'Added $_qty meals to bulk cart');
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartTotal = p.bulkCartTotalMeals;

    if (cfg == null || (p.isLoading && !cfg.isStandardActive)) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Standard Bulk',
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
        ),
        body: Center(
          child: p.error != null
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        size: 48,
                        color: isDark ? Colors.orangeAccent : Colors.orange.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        p.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                        ),
                      ),
                    ],
                  ),
                )
              : const CupertinoActivityIndicator(),
        ),
      );
    }

    if (!cfg.isStandardActive) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Standard Bulk',
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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 48,
                  color: isDark ? Colors.white54 : const Color(0xFF8B7A66),
                ),
                const SizedBox(height: 16),
                Text(
                  'Standard bulk ordering is currently unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final maxQty = _maxQty(cfg);
    final menuPrice = p.deliveryMenu?.pricePerMeal;
    final pricePerMeal = (menuPrice != null && menuPrice > 0)
        ? menuPrice
        : cfg.pricePerMealUnderThreshold;
    final estimatedTotal = _qty * pricePerMeal;
    final canAdd = _selectedDate != null && p.deliveryMenu != null && !p.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        floatingActionButton: cartTotal > 0
            ? FloatingActionButton.extended(
                heroTag: 'standard_bulk_cart_fab',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
                ),
                icon: const Icon(CupertinoIcons.cart_fill),
                label: Text('Cart ($cartTotal)', style: const TextStyle(fontWeight: FontWeight.w800)),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Standard Bulk',
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
          systemOverlayStyle: AppTheme.overlayFor(
            background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
            Expanded(
            child: ResponsiveContainer(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    'Select your delivery date first to see the meal for that day, then choose how many meals you need.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),
                  BulkDeliveryDateTile(
                    deliveryDate: _selectedDate,
                    onTap: () => _pickDate(cfg),
                  ),
                  bulkInfoBanner(
                    isDark: isDark,
                    message: 'Order ${cfg.minQuantity} or more meals. For ${cfg.tierThreshold}+ meals use large event bulk.',
                  ),
                  const SizedBox(height: 20),
                  Text('Menu for selected date', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_selectedDate == null)
                    Text('Pick a date above to load the menu.', style: TextStyle(color: Colors.orange.shade700))
                  else if (p.isLoading && p.deliveryMenu == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (p.deliveryMenu != null)
                    AppleCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bulkMenuImage(p.deliveryMenu!.imageUrl),
                          if (p.deliveryMenu!.imageUrl != null && p.deliveryMenu!.imageUrl!.isNotEmpty)
                            const SizedBox(height: 10),
                          Text(p.deliveryMenu!.menuDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(p.deliveryMenu!.items),
                          const SizedBox(height: 8),
                          Text(
                            '₹${pricePerMeal.toStringAsFixed(2)} per meal',
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    Text('No menu available for this date.', style: TextStyle(color: Colors.red.shade700)),
                  // ── Quantity & price: only shown after a date is selected AND menu loaded ──
                  if (_selectedDate != null && p.deliveryMenu != null) ...[
                    const SizedBox(height: 20),
                    AppleCard(
                      child: Column(
                        children: [
                          Text('Number of Meals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StepperButton(
                                icon: CupertinoIcons.minus,
                                onTap: _qty > cfg.minQuantity ? () => _decrement(cfg) : null,
                              ),
                              const SizedBox(width: 24),
                              Container(
                                constraints: const BoxConstraints(minWidth: 80),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '$_qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              _StepperButton(
                                icon: CupertinoIcons.plus,
                                onTap: _qty < maxQty ? () => _increment(cfg) : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Min ${cfg.minQuantity} · Below ${cfg.tierThreshold}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_qty × ₹${pricePerMeal.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                          ),
                          Text(
                            '₹${estimatedTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          ),
          if (canAdd)
            Material(
              elevation: 12,
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _addToCart(p, cfg),
                      icon: const Icon(CupertinoIcons.cart_badge_plus, size: 20),
                      label: Text('Add $_qty Meals to Cart', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
      ),
    );
}
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? (isDark ? AppTheme.borderDark.withValues(alpha: 0.3) : const Color(0xFFF3EBE0)) : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: enabled 
                ? (isDark ? AppTheme.borderDark : AppTheme.borderLight) 
                : Colors.grey.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? (isDark ? Colors.white : const Color(0xFF5A4D42)) : Colors.grey,
          size: 22,
        ),
      ),
    );
  }
}
