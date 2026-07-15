import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/subscription/ui/widgets/plan_picker_bottom_sheet.dart';

/// Opens a bottom sheet to pick regular/trial plans for the profile meal size.
class EntityAddToCartButton extends StatelessWidget {
  final String entityType;
  final String entityId;
  final String entityName;
  final int? mealSizeId;
  final bool compact;

  const EntityAddToCartButton({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.mealSizeId,
    this.compact = false,
  });

  void _open(BuildContext context) {
    if (entityId.isEmpty) {
      ErrorHandler.showError(context, 'Profile is not ready yet. Save the profile and try again.');
      return;
    }
    if (mealSizeId == null || mealSizeId! <= 0) {
      ErrorHandler.showError(context, 'Select a meal size on the profile before choosing a plan.');
      return;
    }
    PlanPickerBottomSheet.show(
      context,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      mealSizeId: mealSizeId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(CupertinoIcons.cart_badge_plus, size: 18),
          label: const Text('Choose Plan'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(CupertinoIcons.cart_badge_plus, size: 20),
        label: const Text('Choose Plan'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
