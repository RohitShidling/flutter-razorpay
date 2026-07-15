import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/quick_service/ui/screens/special_dishes_cart_screen.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

class SpecialDishesScreen extends StatefulWidget {
  const SpecialDishesScreen({super.key});

  @override
  State<SpecialDishesScreen> createState() => _SpecialDishesScreenState();
}

class _SpecialDishesScreenState extends State<SpecialDishesScreen> {
  String? _selectedCategoryId;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = context.read<QuickServiceProvider>();
      await p.loadCategories();
      if (!mounted) return;
      await p.loadCartFromServer();
      if (!mounted) return;
      final bulk = context.read<BulkOrderProvider>();
      await bulk.loadSavedDeliveryAddress();
      if (!mounted) return;
      final backendAddr = await p.loadSavedDeliveryAddress();
      if (!mounted) return;
      final addr = backendAddr ?? bulk.deliveryAddress;
      if (addr != null) {
        bulk.setDeliveryAddress(addr);
        p.setAddress(addr);
      }
      
      // Load 'all' items by default
      setState(() => _selectedCategoryId = 'all');
      await p.loadItems('all');
      if (mounted) {
        setState(() => _initialLoading = false);
      }
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const SpecialDishesCartScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<QuickServiceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text(
          'Buuttii Specials',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: p.cartItemCount > 0
          ? FloatingActionButton.extended(
              heroTag: 'special_dishes_cart_fab',
              onPressed: _openCart,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(CupertinoIcons.cart_fill),
              label: Text(
                'Cart (${p.cartItemCount})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            )
          : null,
      body: SafeArea(
        top: false,
        child: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveContainer(
                maxWidth: 1100.0,
                child: Column(
                  children: [
                    // Categories scroll bar
                    if (p.categories.isNotEmpty)
                      Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: p.categories.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final bool selected;
                            final String title;
                            final VoidCallback onTap;

                            if (i == 0) {
                              selected = _selectedCategoryId == 'all';
                              title = 'All';
                              onTap = () async {
                                setState(() => _selectedCategoryId = 'all');
                                await p.loadItems('all');
                              };
                            } else {
                              final cat = p.categories[i - 1];
                              final id = cat['id']?.toString() ?? '';
                              selected = id == _selectedCategoryId;
                              title = cat['name']?.toString() ?? 'Category';
                              onTap = () async {
                                setState(() => _selectedCategoryId = id);
                                await p.loadItems(id);
                              };
                            }

                            return ChoiceChip(
                              label: Text(
                                title,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              selected: selected,
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF1EDE9),
                              checkmarkColor: Colors.white,
                              onSelected: (_) => onTap(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected ? AppTheme.primaryColor : Colors.transparent,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Menu list
                    // Use a LayoutBuilder to check width
                    Expanded(
                      child: p.isLoading && p.items.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : p.items.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.square_list,
                                        size: 64,
                                        color: Colors.grey.withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No special dishes found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth > 750;
                                    if (isWide) {
                                      final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(
                                        context,
                                        mobileCount: 1,
                                        tabletCount: 2,
                                        desktopCount: 3,
                                      );
                                      return GridView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          mainAxisExtent: 350,
                                        ),
                                        itemCount: p.items.length,
                                        itemBuilder: (context, i) {
                                          return _buildMealCard(context, Map<String, dynamic>.from(p.items[i]), p, isDark);
                                        },
                                      );
                                    } else {
                                      return Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 600),
                                          child: ListView.separated(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            itemCount: p.items.length,
                                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                                            itemBuilder: (context, i) {
                                              return _buildMealCard(context, Map<String, dynamic>.from(p.items[i]), p, isDark);
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, Map<String, dynamic> item, QuickServiceProvider p, bool isDark) {
    final id = item['id']?.toString() ?? '';
    final qty = p.cartQty[id] ?? 0;
    final price = double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
    final description = item['description']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFEFECE9),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 180,
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                child: const Center(child: CupertinoActivityIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 180,
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                child: const Icon(CupertinoIcons.photo, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']?.toString() ?? 'Item',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1B1C1C),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildQtySelector(id, qty, p, isDark, context),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF584235),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtySelector(String id, int qty, QuickServiceProvider p, bool isDark, BuildContext context) {
    if (qty == 0) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => p.setCartQty(id, 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            foregroundColor: AppTheme.primaryColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
          child: const Text(
            'ADD',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => p.setCartQty(id, qty - 1),
            icon: const Icon(CupertinoIcons.minus, size: 14, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            splashRadius: 18,
          ),
          Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: Colors.white,
                selectionColor: Colors.white24,
                selectionHandleColor: Colors.white,
              ),
            ),
            child: SizedBox(
              width: 40,
              child: TextFormField(
                initialValue: '$qty',
                key: ValueKey('qty_${id}_$qty'),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.white,
                ),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                onFieldSubmitted: (val) {
                  final newQty = int.tryParse(val) ?? qty;
                  p.setCartQty(id, newQty);
                },
              ),
            ),
          ),
          IconButton(
            onPressed: () => p.setCartQty(id, qty + 1),
            icon: const Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
