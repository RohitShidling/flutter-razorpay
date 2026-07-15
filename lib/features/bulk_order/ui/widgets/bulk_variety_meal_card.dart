import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';

/// Variety meal card with quantity entry and explicit add-to-cart action.
class BulkVarietyMealCard extends StatefulWidget {
  const BulkVarietyMealCard({
    super.key,
    required this.meal,
    required this.cfg,
    required this.cartQuantity,
    required this.isDark,
    required this.menuImage,
    required this.perMealMin,
    required this.orderMinTotal,
    required this.singleMealOnly,
    required this.onBeforeEdit,
    required this.onAddToCart,
  });

  final BulkMenuOption meal;
  final BulkOrderConfig cfg;
  final int cartQuantity;
  final bool isDark;
  final Widget menuImage;
  /// Per-meal minimum when ordering multiple types together.
  final int perMealMin;
  /// Order-wide minimum (e.g. 50) for single-meal-only mode.
  final int orderMinTotal;
  final bool singleMealOnly;
  final VoidCallback onBeforeEdit;
  final bool Function(int quantity) onAddToCart;

  @override
  State<BulkVarietyMealCard> createState() => BulkVarietyMealCardState();
}

class BulkVarietyMealCardState extends State<BulkVarietyMealCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textForQty(widget.cartQuantity));
  }

  @override
  void didUpdateWidget(covariant BulkVarietyMealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cartQuantity != oldWidget.cartQuantity) {
      final nextText = _textForQty(widget.cartQuantity);
      if (_controller.text != nextText) {
        _controller.text = nextText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _textForQty(int q) => q > 0 ? '$q' : '';

  int? _readQty() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 0;
    return int.tryParse(trimmed);
  }

  void _adjust(int delta) {
    final base = widget.cartQuantity > 0 ? widget.cartQuantity : (_readQty() ?? 0);
    int next;
    if (widget.singleMealOnly && base == 0 && delta > 0) {
      next = widget.orderMinTotal;
    } else {
      next = base + delta;
    }
    if (next < 0) next = 0;
    _controller.text = next > 0 ? '$next' : '';
    setState(() {});
  }

  void _submit() {
    final parsed = _readQty();
    if (parsed == null) return;
    final ok = widget.onAddToCart(parsed);
    if (ok && mounted) {
      _controller.text = _textForQty(widget.cartQuantity);
      setState(() {});
    }
  }

  void commitNow() {
    final parsed = _readQty();
    if (parsed != null && parsed != widget.cartQuantity) {
      widget.onAddToCart(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final inCart = widget.cartQuantity > 0;
    final isDark = widget.isDark;
    final multi = widget.cfg.allowMultipleVarietyMeals && !widget.singleMealOnly;

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: inCart ? Border.all(color: isDark ? Colors.white70 : AppTheme.textPrimaryLight, width: 2) : null,
        ),
        padding: inCart ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.menuImage,
            if (m.imageUrl != null && m.imageUrl!.isNotEmpty) const SizedBox(height: 10),
            Text(
              m.items,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (m.pricePerMeal != null) ...[
              const SizedBox(height: 6),
              Text(
                '₹${m.pricePerMeal!.toStringAsFixed(2)} per meal',
                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
              ),
            ],
            if (multi && widget.perMealMin > 1) ...[
              const SizedBox(height: 4),
              Text(
                'Min ${widget.perMealMin} per meal when you combine types',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
            if (widget.singleMealOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Min ${widget.orderMinTotal} portions for this order',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _adjust(-1),
                  icon: Icon(
                    CupertinoIcons.minus_circle,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  onPressed: () => _adjust(1),
                  icon: const Icon(CupertinoIcons.plus_circle_fill, color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  inCart
                      ? (widget.cartQuantity == (_readQty() ?? widget.cartQuantity)
                          ? 'In cart (${widget.cartQuantity})'
                          : 'Update cart')
                      : 'Add to cart',
                ),
              ),
            ),
            if (inCart && m.pricePerMeal != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Line subtotal ₹${(m.pricePerMeal! * widget.cartQuantity).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
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
