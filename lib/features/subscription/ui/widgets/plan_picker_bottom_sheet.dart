import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/money_format.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';
import 'package:meal_app/features/subscription/ui/widgets/plan_features_row.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';

/// Bottom-sheet plan picker: regular plans first, then trial; with/without Saturday per plan.
class PlanPickerBottomSheet {
  PlanPickerBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required String entityName,
    required int mealSizeId,
  }) async {
    await context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true);
    if (!context.mounted) return;

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 650.0; // Responsive breakpoint matching Mobile

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
            child: _PlanPickerSheet(
              entityType: entityType,
              entityId: entityId,
              entityName: entityName,
              mealSizeId: mealSizeId,
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PlanPickerSheet(
          entityType: entityType,
          entityId: entityId,
          entityName: entityName,
          mealSizeId: mealSizeId,
          isDialog: false,
        ),
      );
    }
  }
}

class _PlanPickerSheet extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityName;
  final int mealSizeId;
  final bool isDialog;

  const _PlanPickerSheet({
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.mealSizeId,
    required this.isDialog,
  });

  @override
  State<_PlanPickerSheet> createState() => _PlanPickerSheetState();
}

class _PlanPickerSheetState extends State<_PlanPickerSheet> {
  bool _adding = false;

  List<SubscriptionModel> _plansForSize(List<SubscriptionModel> all) {
    return all
        .where((p) => p.mealSizeId == widget.mealSizeId)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  String _mealSizeLabel() {
    final sizes = context.read<LookupProvider>().mealSizes;
    final match = sizes.where((m) => m.id == widget.mealSizeId).firstOrNull;
    return match?.displayName ?? 'Meal size ${widget.mealSizeId}';
  }

  int _durationDays(SubscriptionModel plan, bool includeSaturday) {
    if (includeSaturday) {
      return plan.durationDaysWithSaturday ?? plan.durationDays;
    }
    return plan.durationDaysWithoutSaturday ?? plan.durationDays;
  }

  double _getExtraAmount() {
    final lookup = context.read<LookupProvider>();
    if (widget.entityType == 'child') {
      final childrenProvider = context.read<ChildrenProvider>();
      final child = childrenProvider.children.where((c) => c.id == widget.entityId).firstOrNull;
      if (child != null) {
        final school = lookup.schools.where((s) => s.id == child.schoolId).firstOrNull;
        return school?.extraAmount ?? 0.0;
      }
    } else if (widget.entityType == 'teacher') {
      final profileProvider = context.read<ProfileProvider>();
      final teacher = profileProvider.teacherProfiles.where((p) => p.id == widget.entityId).firstOrNull;
      if (teacher != null) {
        // AUDIT-056: Prefer stable school_id lookup; fall back to name-match for
        // legacy profiles that pre-date the school_id field.
        final school = (teacher.schoolId != null && teacher.schoolId!.isNotEmpty)
            ? lookup.schools.where((s) => s.id == teacher.schoolId).firstOrNull ??
              lookup.schools.where((s) => s.name == teacher.schoolCollegeName).firstOrNull
            : lookup.schools.where((s) => s.name == teacher.schoolCollegeName).firstOrNull;
        return school?.extraAmount ?? 0.0;
      }
    } else if (widget.entityType == 'professional') {
      final profileProvider = context.read<ProfileProvider>();
      final professional = profileProvider.professionalProfiles.where((p) => p.id == widget.entityId).firstOrNull;
      if (professional != null) {
        final loc = lookup.corporateLocations.where((c) => c.id == professional.corporateLocationId).firstOrNull;
        return loc?.extraAmount ?? 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _addPlan(SubscriptionModel plan, bool includeSaturday) async {
    if (_adding) return;
    setState(() => _adding = true);
    final cart = context.read<CartProvider>();
    final priceStr = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final double extra = _getExtraAmount();
    final double baseVal = MoneyFormat.parseAmount(priceStr);
    final double finalVal = baseVal + extra;
    final ok = await cart.addItem(
      subscriptionId: plan.id,
      entityType: widget.entityType,
      entityId: widget.entityId,
      includeSaturday: includeSaturday,
      startDate: null,
      entityName: widget.entityName,
      planName: plan.planName,
      unitPrice: finalVal,
      mealSizeId: plan.mealSizeId,
      mealSizeName: _mealSizeLabel(),
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (ok) {
      await cart.fetchCart(silent: true);
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ErrorHandler.showError(context, cart.error ?? 'Could not add to cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return _buildContent(context, null);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return _buildContent(context, scrollController);
      },
    );
  }

  Widget _buildContent(BuildContext context, ScrollController? scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subProvider = context.watch<SubscriptionProvider>();
    final all = subProvider.subscriptions;
    final forSize = _plansForSize(all);
    final regular = forSize.where((p) => p.trialDays == 0).toList();
    final trial = forSize.where((p) => p.trialDays > 0).toList();
    final loading = forSize.isEmpty && subProvider.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          if (!widget.isDialog)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Meal Plan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.entityName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _mealSizeLabel(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
          ),
          if (_adding)
            const LinearProgressIndicator(minHeight: 2, color: AppTheme.primaryColor),
          Expanded(
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: PlanCatalogSkeleton(isDark: isDark),
                  )
                : forSize.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No plans are published for this meal size yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          if (regular.isNotEmpty) ...[
                            _sectionTitle('Regular plans', isDark),
                            const SizedBox(height: 10),
                            ...regular.map((p) => _planCard(context, p, isDark)),
                            const SizedBox(height: 20),
                          ],
                          if (trial.isNotEmpty) ...[
                            _sectionTitle('Trial plans', isDark),
                            const SizedBox(height: 10),
                            ...trial.map((p) => _planCard(context, p, isDark, isTrial: true)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: isDark ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, SubscriptionModel plan, bool isDark, {bool isTrial = false}) {
    final variants = <_VariantSpec>[];
    if (plan.saturdayOptionEnabled) {
      variants.add(_VariantSpec(
        includeSaturday: true,
        label: 'Including Sat',
        hint: 'Includes Saturday deliveries',
      ));
      variants.add(_VariantSpec(
        includeSaturday: false,
        label: 'Excluding Sat',
        hint: 'Saturday meals excluded',
      ));
    } else {
      variants.add(_VariantSpec(
        includeSaturday: true,
        label: plan.planName,
        hint: '',
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  plan.planName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
              if (isTrial)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TRIAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          ...variants.map((v) => _variantRow(context, plan, v, isDark)),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            PlanFeaturesRow(features: plan.features, isDark: isDark),
          ],
        ],
      ),
    );
  }

  Widget _variantRow(
    BuildContext context,
    SubscriptionModel plan,
    _VariantSpec variant,
    bool isDark,
  ) {
    final includeSaturday = variant.includeSaturday;
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final days = _durationDays(plan, includeSaturday);
    final double extra = _getExtraAmount();
    final double baseVal = MoneyFormat.parseAmount(price);
    final inCart = context.watch<CartProvider>().hasExactCartItem(
          entityType: widget.entityType,
          entityId: widget.entityId,
          subscriptionId: plan.id,
          includeSaturday: includeSaturday,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252528) : const Color(0xFFFBFBFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart
                ? const Color(0xFF22C55E)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08)),
            width: inCart ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _adding || inCart ? null : () => _addPlan(plan, includeSaturday),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label — full width so "Without Saturday" is never clipped
                      Text(
                        variant.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      const SizedBox(height: 6),
                      // Days badge + hint on the same line beneath the label
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (days > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$days days',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          Text(
                            variant.hint,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${MoneyFormat.display(baseVal.toStringAsFixed(2))}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: inCart ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (extra != 0.0) ...[
                      const SizedBox(height: 2),
                      Text(
                        extra > 0
                            ? '+₹${MoneyFormat.display(extra.toStringAsFixed(2))} Adjustment'
                            : '-₹${MoneyFormat.display(extra.abs().toStringAsFixed(2))} Adjustment',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: extra > 0 ? AppTheme.primaryColor : const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: inCart
                            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            inCart ? CupertinoIcons.checkmark_alt : CupertinoIcons.cart_badge_plus,
                            size: 12,
                            color: inCart ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            inCart ? 'In Cart' : 'Select',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: inCart ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantSpec {
  final bool includeSaturday;
  final String label;
  final String hint;

  const _VariantSpec({
    required this.includeSaturday,
    required this.label,
    required this.hint,
  });
}
