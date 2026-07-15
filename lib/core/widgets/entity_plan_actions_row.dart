import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/widgets/entity_add_to_cart_button.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_size_upgrade_screen.dart';

/// Resize pack (left) + add to cart (right) when subscribed and multiple meal sizes exist.
class EntityPlanActionsRow extends StatelessWidget {
  final String entityType;
  final String entityId;
  final String entityName;
  final int? mealSizeId;

  const EntityPlanActionsRow({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.mealSizeId,
  });

  bool _hasSubscribedPlan(BuildContext context) {
    final state = SubscriptionStatusNormalizer.entityPlanState(
      context.watch<MealProvider>().subscriptionStatusData,
      entityType,
      entityId,
    );
    return state == 'active' || state == 'upcoming';
  }

  int? _resolvedMealSizeId(BuildContext context) {
    final fromStatus = SubscriptionStatusNormalizer.profileMealSizeIdForEntity(
      context.read<MealProvider>().subscriptionStatusData,
      entityType,
      entityId,
    );
    if (fromStatus != null && fromStatus > 0) return fromStatus;
    if (mealSizeId != null && mealSizeId! > 0) return mealSizeId;
    return null;
  }

  bool _canResizeMealPack(BuildContext context) {
    final currentId = _resolvedMealSizeId(context);
    if (currentId == null || currentId <= 0) return false;

    final sizes = context.read<LookupProvider>().mealSizes;
    if (sizes.isEmpty) return false;
    if (sizes.length <= 1) return false;

    final sorts = sizes.map((s) => s.sortOrder).toSet();
    return sorts.length > 1 || sizes.length > 1;
  }

  void _openResizeScreen(BuildContext context, {required bool subscribed}) {
    if (!subscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Subscribe and complete payment for this profile first, then you can resize the meal pack.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MealSizeUpgradeScreen(
          initialEntityType: entityType,
          initialEntityId: entityId,
          initialEntityName: entityName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = _hasSubscribedPlan(context);
    final showResize = subscribed && _canResizeMealPack(context);
    final resolvedSizeId = _resolvedMealSizeId(context) ?? mealSizeId;

    if (!showResize) {
      return EntityAddToCartButton(
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        mealSizeId: resolvedSizeId,
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openResizeScreen(context, subscribed: subscribed),
            icon: const Icon(CupertinoIcons.arrow_up_down_circle, size: 18),
            label: const Text('Resize pack'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: EntityAddToCartButton(
            entityType: entityType,
            entityId: entityId,
            entityName: entityName,
            mealSizeId: resolvedSizeId,
            compact: true,
          ),
        ),
      ],
    );
  }
}
