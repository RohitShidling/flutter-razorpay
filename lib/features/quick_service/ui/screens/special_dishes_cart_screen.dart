import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/quick_service/ui/widgets/quick_service_checkout.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

/// Review specials cart and pay with delivery details at checkout.
class SpecialDishesCartScreen extends StatefulWidget {
  const SpecialDishesCartScreen({super.key});

  @override
  State<SpecialDishesCartScreen> createState() => _SpecialDishesCartScreenState();
}

class _SpecialDishesCartScreenState extends State<SpecialDishesCartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuickServiceProvider>().loadCartFromServer();
    });
  }

  Future<void> _startPay(BuildContext context, QuickServiceProvider p) async {
    await QuickServiceCheckout.paySpecialDishes(context, skipAddressPrompt: false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<QuickServiceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cartItems = p.cartQty.entries.where((e) => e.value > 0).toList();
    final hasItems = cartItems.isNotEmpty;
    final detailsLoaded = !hasItems || cartItems.every((e) => p.itemCache.containsKey(e.key));
    final showLoading = p.isLoading && !detailsLoaded;

    final appBarBg = isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: appBarBg,
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : Colors.white,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: appBarBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Specials Cart',
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
            if (hasItems)
              TextButton(
                onPressed: () {
                  p.clearCart();
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
            background: appBarBg,
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : Colors.white,
          ),
        ),
        body: showLoading
            ? const Center(child: CircularProgressIndicator())
            : !hasItems
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
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: cartItems.length,
                                  itemBuilder: (context, i) {
                                    final id = cartItems[i].key;
                                    final qty = cartItems[i].value;
                                    final item = p.itemCache[id] ?? {};
                                    return _buildCartItemCard(context, id, qty, item, p, isDark);
                                  },
                                ),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      _PriceSummary(provider: p, isDark: isDark),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Ready to Checkout?',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: FilledButton(
                                                onPressed: p.isLoading ? null : () => _startPay(context, p),
                                                style: FilledButton.styleFrom(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                ),
                                                child: p.isLoading
                                                    ? const SizedBox(
                                                        height: 22,
                                                        width: 22,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                      )
                                                    : Text(
                                                        'Proceed to Pay (${p.cartItemCount} items)',
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                                      ),
                                              ),
                                            ),
                                          ],
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
                                    ...cartItems.map((e) {
                                      final id = e.key;
                                      final qty = e.value;
                                      final item = p.itemCache[id] ?? {};
                                      return _buildCartItemCard(context, id, qty, item, p, isDark);
                                    }),
                                    const SizedBox(height: 16),
                                    _PriceSummary(provider: p, isDark: isDark),
                                  ],
                                ),
                              ),
                              _BottomPayBar(
                                totalItems: p.cartItemCount,
                                isLoading: p.isLoading,
                                onPay: () => _startPay(context, p),
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

  Widget _buildCartItemCard(BuildContext context, String id, int qty, Map<dynamic, dynamic> item, QuickServiceProvider p, bool isDark) {
    final name = item['name']?.toString() ?? 'Special Dish';
    final imageUrl = item['image_url']?.toString() ?? '';
    final price = double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
    final subtotal = price * qty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1.5,
          ),
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
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
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
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${price.toStringAsFixed(0)} each',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _qtyButton(
                          CupertinoIcons.minus,
                          () => p.setCartQty(id, qty - 1),
                          qty <= 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$qty',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        _qtyButton(
                          CupertinoIcons.plus,
                          () => p.setCartQty(id, qty + 1),
                          false,
                        ),
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
              onPressed: () => p.setCartQty(id, 0),
              icon: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: Colors.red.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
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
              'Your specials cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add dishes from the Buttii Specials menu.',
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

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.provider,
    required this.isDark,
  });

  final QuickServiceProvider provider;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          _row('Total Items', '${provider.cartItemCount}', isDark),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _row('Estimated Total', 'Rs ${provider.cartTotalAmount.toStringAsFixed(0)}', isDark, bold: true),
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
    required this.totalItems,
    required this.isLoading,
    required this.onPay,
    required this.isDark,
  });

  final int totalItems;
  final bool isLoading;
  final VoidCallback onPay;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
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
                      'Proceed to Pay ($totalItems items)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
