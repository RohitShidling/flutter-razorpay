import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_size_upgrade_screen.dart';

/// Persistent banner when meal size cannot be changed directly while subscribed.
/// Includes a direct 'Resize Meal Pack' button to open the upgrade/downgrade menu for that recipient.
class MealSizeBlockedBanner extends StatelessWidget {
  const MealSizeBlockedBanner({
    super.key,
    required this.message,
    this.entityType,
    this.entityId,
    this.entityName,
  });

  final String message;
  final String? entityType;
  final String? entityId;
  final String? entityName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF382315) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF6E4327) : const Color(0xFFFFEDD5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.info_circle_fill,
                color: isDark ? Colors.orange.shade300 : const Color(0xFFC2410C),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.orange.shade200 : const Color(0xFF7C2D12),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (entityType != null && entityType!.isNotEmpty && entityId != null && entityId!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                label: Text(
                  'Resize Meal Pack for ${entityName?.isNotEmpty == true ? entityName! : 'Profile'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
